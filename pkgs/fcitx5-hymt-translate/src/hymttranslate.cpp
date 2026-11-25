#include "hymttranslate.h"

#include <fcitx-config/iniparser.h>
#include <fcitx-utils/event.h>
#include <fcitx-utils/eventdispatcher.h>
#include <fcitx-utils/log.h>
#include <fcitx-utils/standardpaths.h>
#include <fcitx/candidatelist.h>
#include <fcitx/event.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputcontextmanager.h>
#include <fcitx/inputpanel.h>
#include <fcitx/text.h>
#include <fcitx/userinterface.h>

#include <ctime>
#include <utility>

namespace fcitx {
namespace {

constexpr char kConfigFile[] = "hymttranslate.conf";

bool matchesKeyList(const KeyEvent &event, const KeyList &keys) {
    const Key normKey = event.key().normalize();
    const Key normOrig = event.origKey().normalize();
    for (const auto &target : keys) {
        const Key normTarget = target.normalize();
        if (normKey.check(normTarget) || normOrig.check(normTarget)) {
            return true;
        }
    }
    return false;
}

} // namespace

HyMtTranslateEngine::HyMtTranslateEngine(Instance *instance)
    : instance_(instance),
      stateFactory_([](InputContext &) { return new HyMtContextState(); }),
      cache_(256),
      alive_(std::make_shared<std::atomic<bool>>(true)) {
    instance_->inputContextManager().registerProperty("hymtTranslateState",
                                                      &stateFactory_);
    reloadConfig();

    eventWatchers_.push_back(instance_->watchEvent(
        EventType::InputContextKeyEvent, EventWatcherPhase::PreInputMethod,
        [this](Event &event) {
            onKeyEvent(static_cast<KeyEvent &>(event));
        }));

    eventWatchers_.push_back(instance_->watchEvent(
        EventType::InputContextUpdateUI, EventWatcherPhase::PreInputMethod,
        [this](Event &event) {
            onUpdateUI(static_cast<InputContextUpdateUIEvent &>(event));
        }));

    eventWatchers_.push_back(instance_->watchEvent(
        EventType::InputContextReset, EventWatcherPhase::PostInputMethod,
        [this](Event &event) {
            auto &resetEvent = static_cast<ResetEvent &>(event);
            if (auto *ic = resetEvent.inputContext()) {
                if (auto *state = ic->propertyFor(&stateFactory_)) {
                    state->cancelPreview();
                }
            }
        }));

    eventWatchers_.push_back(instance_->watchEvent(
        EventType::InputContextFocusOut, EventWatcherPhase::PostInputMethod,
        [this](Event &event) {
            auto &focusEvent = static_cast<FocusOutEvent &>(event);
            if (auto *ic = focusEvent.inputContext()) {
                if (auto *state = ic->propertyFor(&stateFactory_)) {
                    state->cancelPending();
                }
            }
        }));

    commitFilterConn_ = instance_->connect<Instance::CommitFilter>(
        [this](InputContext *ic, std::string &orig) {
            onCommitFilter(ic, orig);
        });

    workerThread_ = std::thread(&HyMtTranslateEngine::workerLoop, this);
}

HyMtTranslateEngine::~HyMtTranslateEngine() {
    alive_->store(false, std::memory_order_release);
    {
        std::lock_guard<std::mutex> lock(taskMutex_);
        stopping_ = true;
        pendingTask_.reset();
    }
    taskCv_.notify_all();
    if (workerThread_.joinable()) {
        workerThread_.join();
    }
}

void HyMtTranslateEngine::reloadConfig() {
    readAsIni(config_, StandardPathsType::PkgConfig, kConfigFile);
}

void HyMtTranslateEngine::setConfig(const RawConfig &config) {
    config_.load(config, true);
    safeSaveAsIni(config_, StandardPathsType::PkgConfig, kConfigFile);
    reloadConfig();
}

hymt::RequestConfig HyMtTranslateEngine::currentRequestConfig() const {
    hymt::RequestConfig req;
    req.endpoint = config_.endpoint.value();
    req.model = config_.model.value();
    req.timeoutMs = static_cast<long>(config_.timeoutMs.value());
    return req;
}

std::optional<std::string>
HyMtTranslateEngine::currentCandidateText(InputContext *ic) {
    if (!ic) {
        return std::nullopt;
    }
    auto candList = ic->inputPanel().candidateList();
    if (!candList || candList->empty()) {
        return std::nullopt;
    }
    int idx = candList->cursorIndex();
    if (idx < 0 || idx >= candList->size()) {
        idx = 0;
    }
    std::string text = candList->candidate(idx).text().toString();
    if (text.empty()) {
        return std::nullopt;
    }
    return text;
}

bool HyMtTranslateEngine::isImComposing(InputContext *ic) {
    if (!ic) {
        return false;
    }
    const auto &panel = ic->inputPanel();
    const bool hasCands = panel.candidateList() && !panel.candidateList()->empty();
    return hasCands || !panel.preedit().empty() || !panel.clientPreedit().empty();
}

std::string HyMtTranslateEngine::combinedSource(const HyMtContextState *state,
                                                InputContext *ic) {
    std::string source = state ? state->sentenceBuffer : std::string();
    if (auto cand = currentCandidateText(ic)) {
        source.append(*cand);
    }
    return source;
}

void HyMtTranslateEngine::updatePanelDisplay(InputContext *ic,
                                               std::string_view buffer,
                                               std::string_view preview,
                                               bool flushUi) {
    if (!ic) {
        return;
    }
    const std::string curUp = ic->inputPanel().auxUp().toString();
    const std::string nextUp = hymt::formatAuxUpWithBuffer(curUp, buffer);
    if (nextUp != curUp) {
        ic->inputPanel().setAuxUp(Text(nextUp));
    }

    const std::string curDown = ic->inputPanel().auxDown().toString();
    const std::string nextDown = hymt::formatAuxWithPreview(curDown, preview);
    if (nextDown != curDown) {
        ic->inputPanel().setAuxDown(Text(nextDown));
    }

    if (flushUi) {
        updatingPanel_ = true;
        ic->updateUserInterface(UserInterfaceComponent::InputPanel, true);
        updatingPanel_ = false;
    }
}

void HyMtTranslateEngine::refreshBufferPanel(InputContext *ic,
                                               HyMtContextState *state,
                                               bool flushUi) {
    if (!ic || !state) {
        return;
    }
    const std::string source = combinedSource(state, ic);
    if (source.empty() || !hymt::containsChinese(source)) {
        state->cancelPreview();
        updatePanelDisplay(ic, state->sentenceBuffer, "", flushUi);
        return;
    }

    if (auto cached = cache_.get(source)) {
        state->activePreviewSource = source;
        if (state->debounceTimer) {
            state->debounceTimer->setEnabled(false);
        }
        updatePanelDisplay(ic, state->sentenceBuffer, *cached, flushUi);
        return;
    }

    if (state->activePreviewSource != source) {
        state->activePreviewSource = source;
        updatePanelDisplay(ic, state->sentenceBuffer, "...", flushUi);
        scheduleDebounce(ic, state, source);
    } else if (flushUi) {
        updatePanelDisplay(ic, state->sentenceBuffer, "...", true);
    }
}

void HyMtTranslateEngine::commitTextBypass(InputContext *ic,
                                           const std::string &text,
                                           bool isEnglish) {
    if (!ic) {
        return;
    }
    std::string out = text;
    if (isEnglish && config_.appendSpace.value() && !out.empty() &&
        out.back() != ' ') {
        out.push_back(' ');
    }
    if (auto *state = ic->propertyFor(&stateFactory_)) {
        state->clearAll();
    }
    ic->reset();
    updatePanelDisplay(ic, "", "", true);
    bypassCommitFilter_ = true;
    ic->commitString(out);
    bypassCommitFilter_ = false;
}

void HyMtTranslateEngine::triggerCommitTranslation(InputContext *ic,
                                                   HyMtContextState *state,
                                                   const std::string &source) {
    if (auto cached = cache_.get(source)) {
        commitTextBypass(ic, *cached, true);
        return;
    }

    if (state) {
        state->pendingCommitSource = source;
    }
    updatePanelDisplay(ic, state ? state->sentenceBuffer : std::string_view(),
                       "translating...", true);
    enqueueTranslation(ic, source, true);
}

void HyMtTranslateEngine::workerLoop() {
    hymt::HttpTranslator http;
    while (true) {
        PendingTask task;
        {
            std::unique_lock<std::mutex> lock(taskMutex_);
            taskCv_.wait(lock, [this]() {
                return stopping_ || pendingTask_.has_value();
            });
            if (stopping_) {
                return;
            }
            task = std::move(*pendingTask_);
            pendingTask_.reset();
        }

        if (!task.commitOnDone &&
            task.generation !=
                latestGeneration_.load(std::memory_order_acquire)) {
            continue;
        }

        auto result = http.translate(task.reqCfg, task.source);

        if (!task.commitOnDone &&
            task.generation !=
                latestGeneration_.load(std::memory_order_acquire)) {
            continue;
        }

        auto aliveFlag = alive_;
        instance_->eventDispatcher().scheduleWithContext(
            task.icRef,
            [this, aliveFlag = std::move(aliveFlag), gen = task.generation,
             icRef = task.icRef, source = std::move(task.source),
             result = std::move(result),
             commitOnDone = task.commitOnDone]() mutable {
                if (!aliveFlag->load(std::memory_order_acquire)) {
                    return;
                }
                handleTranslationDone(gen, std::move(icRef), source,
                                      std::move(result), commitOnDone);
            });
    }
}

void HyMtTranslateEngine::enqueueTranslation(InputContext *ic,
                                             const std::string &source,
                                             bool commitOnDone) {
    if (!ic || source.empty()) {
        return;
    }
    const uint64_t gen =
        latestGeneration_.fetch_add(1, std::memory_order_acq_rel) + 1;

    PendingTask task;
    task.generation = gen;
    task.icRef = ic->watch();
    task.source = source;
    task.reqCfg = currentRequestConfig();
    task.commitOnDone = commitOnDone;

    {
        std::lock_guard<std::mutex> lock(taskMutex_);
        pendingTask_ = std::move(task);
    }
    taskCv_.notify_one();
}

void HyMtTranslateEngine::handleTranslationDone(
    uint64_t generation, TrackableObjectReference<InputContext> icRef,
    const std::string &source, hymt::TranslationResult result,
    bool commitOnDone) {
    InputContext *ic = icRef.get();
    if (!ic) {
        return;
    }

    if (result.ok) {
        cache_.put(source, result.text);
    } else {
        FCITX_WARN() << "Hy-MT2 translation failed: " << result.error;
    }

    if (!ic->hasFocus()) {
        return;
    }

    auto *state = ic->propertyFor(&stateFactory_);
    if (commitOnDone) {
        if (!state || state->pendingCommitSource != source) {
            return;
        }
        state->pendingCommitSource.clear();
        if (result.ok) {
            commitTextBypass(ic, result.text, true);
        } else {
            updatePanelDisplay(ic, state->sentenceBuffer, "(translation failed)",
                               true);
        }
        return;
    }

    if (generation != latestGeneration_.load(std::memory_order_acquire)) {
        return;
    }
    if (!config_.autoTranslate.value()) {
        return;
    }
    if (combinedSource(state, ic) != source) {
        return;
    }

    updatePanelDisplay(ic, state ? state->sentenceBuffer : std::string_view(),
                       result.ok ? result.text : "(offline)", true);
}

void HyMtTranslateEngine::scheduleDebounce(InputContext *ic,
                                           HyMtContextState *state,
                                           const std::string &source) {
    const int delayMs = config_.debounceMs.value();
    if (delayMs <= 0) {
        enqueueTranslation(ic, source, false);
        return;
    }

    const uint64_t targetTime =
        now(CLOCK_MONOTONIC) + static_cast<uint64_t>(delayMs) * 1000ULL;
    auto icRef = ic->watch();
    auto aliveFlag = alive_;

    if (!state->debounceTimer) {
        state->debounceTimer = instance_->eventLoop().addTimeEvent(
            CLOCK_MONOTONIC, targetTime, 0,
            [this, aliveFlag = std::move(aliveFlag), icRef](
                EventSourceTime *, uint64_t) {
                if (!aliveFlag->load(std::memory_order_acquire)) {
                    return false;
                }
                InputContext *targetIc = icRef.get();
                if (!targetIc || !targetIc->hasFocus() ||
                    !config_.autoTranslate.value()) {
                    return false;
                }
                auto *ctxState = targetIc->propertyFor(&stateFactory_);
                if (!ctxState || ctxState->activePreviewSource.empty()) {
                    return false;
                }
                const std::string cur = combinedSource(ctxState, targetIc);
                if (cur == ctxState->activePreviewSource &&
                    !cache_.get(cur).has_value()) {
                    enqueueTranslation(targetIc, cur, false);
                }
                return false;
            });
        state->debounceTimer->setOneShot();
    } else {
        state->debounceTimer->setTime(targetTime);
        state->debounceTimer->setOneShot();
        state->debounceTimer->setEnabled(true);
    }
}

void HyMtTranslateEngine::onKeyEvent(KeyEvent &event) {
    if (event.isRelease()) {
        return;
    }
    InputContext *ic = event.inputContext();
    if (!ic) {
        return;
    }
    auto *state = ic->propertyFor(&stateFactory_);
    if (!state) {
        return;
    }

    if (matchesKeyList(event, config_.toggleKey.value())) {
        const bool next = !config_.autoTranslate.value();
        config_.autoTranslate.setValue(next);
        safeSaveAsIni(config_, StandardPathsType::PkgConfig, kConfigFile);
        instance_->showCustomInputMethodInformation(
            ic, next ? "Hy-MT2 EN: ON" : "Hy-MT2 EN: OFF");

        if (!next) {
            if (!state->sentenceBuffer.empty()) {
                // Flush buffered Chinese as-is when turning the mode off.
                commitTextBypass(ic, state->sentenceBuffer, false);
            } else {
                state->cancelPreview();
                updatePanelDisplay(ic, "", "", isImComposing(ic));
            }
        } else {
            refreshBufferPanel(ic, state, isImComposing(ic));
        }
        event.filterAndAccept();
        return;
    }

    if (matchesKeyList(event, config_.translateKey.value())) {
        const std::string source = combinedSource(state, ic);
        if (source.empty() || !hymt::containsChinese(source)) {
            return;
        }
        event.filterAndAccept();
        triggerCommitTranslation(ic, state, source);
        return;
    }

    if (!event.key().isModifier() && !state->pendingCommitSource.empty()) {
        state->pendingCommitSource.clear();
    }

    // When AutoTranslate is ON and a Chinese phrase buffer is already held
    // (between words, after Rime committed a word), let Return/Backspace/Escape
    // drive the buffer without interfering with Rime while it is composing.
    if (config_.autoTranslate.value() && !state->sentenceBuffer.empty() &&
        !isImComposing(ic)) {
        const Key norm = event.key().normalize();
        if (norm.check(Key(FcitxKey_Return)) ||
            norm.check(Key(FcitxKey_KP_Enter))) {
            event.filterAndAccept();
            if (hymt::containsChinese(state->sentenceBuffer)) {
                triggerCommitTranslation(ic, state, state->sentenceBuffer);
            } else {
                commitTextBypass(ic, state->sentenceBuffer, false);
            }
            return;
        }
        if (norm.check(Key(FcitxKey_Return, KeyState::Shift)) ||
            norm.check(Key(FcitxKey_KP_Enter, KeyState::Shift))) {
            event.filterAndAccept();
            commitTextBypass(ic, state->sentenceBuffer, false);
            return;
        }
        if (norm.check(Key(FcitxKey_BackSpace))) {
            event.filterAndAccept();
            hymt::popLastUtf8Char(state->sentenceBuffer);
            state->pendingCommitSource.clear();
            refreshBufferPanel(ic, state, true);
            return;
        }
        if (norm.check(Key(FcitxKey_Escape))) {
            event.filterAndAccept();
            state->clearAll();
            updatePanelDisplay(ic, "", "", true);
            return;
        }
        if (norm.check(Key(FcitxKey_space))) {
            event.filterAndAccept();
            state->sentenceBuffer.push_back(' ');
            refreshBufferPanel(ic, state, true);
            return;
        }
    }
}

void HyMtTranslateEngine::onUpdateUI(InputContextUpdateUIEvent &event) {
    if (updatingPanel_ ||
        event.component() != UserInterfaceComponent::InputPanel) {
        return;
    }

    InputContext *ic = event.inputContext();
    if (!ic) {
        return;
    }
    auto *state = ic->propertyFor(&stateFactory_);
    if (!state) {
        return;
    }

    if (!config_.autoTranslate.value()) {
        state->cancelPreview();
        return;
    }

    refreshBufferPanel(ic, state, false);
}

void HyMtTranslateEngine::onCommitFilter(InputContext *ic, std::string &orig) {
    if (bypassCommitFilter_ || !config_.autoTranslate.value() || !ic) {
        return;
    }
    auto *state = ic->propertyFor(&stateFactory_);
    if (!state) {
        return;
    }

    // Hold committed text (including leading English letters/words and
    // punctuation) inside the per-IC buffer so phrase-by-phrase typing
    // assembles one coherent sentence before translating.
    if (!hymt::shouldBufferCommit(state->sentenceBuffer, orig)) {
        return;
    }

    state->sentenceBuffer.append(orig);
    orig.clear();

    auto icRef = ic->watch();
    auto aliveFlag = alive_;
    instance_->eventDispatcher().scheduleWithContext(
        icRef, [this, aliveFlag = std::move(aliveFlag), icRef]() {
            if (!aliveFlag->load(std::memory_order_acquire)) {
                return;
            }
            InputContext *targetIc = icRef.get();
            if (!targetIc || !config_.autoTranslate.value()) {
                return;
            }
            if (auto *ctxState = targetIc->propertyFor(&stateFactory_)) {
                refreshBufferPanel(targetIc, ctxState, true);
            }
        });
}

} // namespace fcitx

FCITX_ADDON_FACTORY(fcitx::HyMtTranslateFactory)
