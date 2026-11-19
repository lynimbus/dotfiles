#pragma once

#include "translator.h"

#include <fcitx-config/configuration.h>
#include <fcitx-config/option.h>
#include <fcitx-utils/eventloopinterface.h>
#include <fcitx-utils/handlertable.h>
#include <fcitx-utils/key.h>
#include <fcitx-utils/signals.h>
#include <fcitx-utils/trackableobject.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/inputcontextproperty.h>
#include <fcitx/instance.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

namespace fcitx {

FCITX_CONFIGURATION(
    HyMtTranslateConfig,
    Option<std::string> endpoint{
        this, "Endpoint", "llama-server chat completions URL",
        "http://127.0.0.1:11435/v1/chat/completions"};
    Option<std::string> model{this, "Model", "Model name or alias",
                              "hy-mt2-1.8b"};
    Option<bool> autoTranslate{
        this, "AutoTranslate",
        "Enable Chinese phrase-buffer auto-translation mode", false};
    Option<KeyList> toggleKey{this,
                              "ToggleKey",
                              "Toggle phrase-buffer English translation mode",
                              {Key("Control+Alt+T")}};
    Option<KeyList> translateKey{
        this,
        "TranslateKey",
        "Translate current buffer/candidate and commit English",
        {Key("Control+T")}};
    Option<int, IntConstrain> debounceMs{
        this, "DebounceMs", "Live preview debounce delay (ms)", 220,
        IntConstrain(0, 2000)};
    Option<int, IntConstrain> timeoutMs{
        this, "TimeoutMs", "HTTP request timeout (ms)", 5000,
        IntConstrain(500, 30000)};
    Option<bool> appendSpace{
        this, "AppendSpace",
        "Append a trailing space after committed English text", false};);

class HyMtContextState : public InputContextProperty {
public:
    std::string sentenceBuffer;
    std::string activePreviewSource;
    std::string pendingCommitSource;
    std::unique_ptr<EventSourceTime> debounceTimer;

    void cancelPreview() {
        activePreviewSource.clear();
        if (debounceTimer) {
            debounceTimer->setEnabled(false);
        }
    }

    void cancelPending() {
        cancelPreview();
        pendingCommitSource.clear();
    }

    void clearAll() {
        sentenceBuffer.clear();
        cancelPending();
    }
};

class HyMtTranslateEngine final : public AddonInstance {
public:
    explicit HyMtTranslateEngine(Instance *instance);
    ~HyMtTranslateEngine() override;

    void reloadConfig() override;
    const Configuration *getConfig() const override { return &config_; }
    void setConfig(const RawConfig &config) override;

private:
    struct PendingTask {
        uint64_t generation = 0;
        TrackableObjectReference<InputContext> icRef;
        std::string source;
        hymt::RequestConfig reqCfg;
        bool commitOnDone = false;
    };

    void workerLoop();
    void enqueueTranslation(InputContext *ic, const std::string &source,
                            bool commitOnDone);
    void handleTranslationDone(uint64_t generation,
                               TrackableObjectReference<InputContext> icRef,
                               const std::string &source,
                               hymt::TranslationResult result,
                               bool commitOnDone);

    void onKeyEvent(KeyEvent &event);
    void onUpdateUI(InputContextUpdateUIEvent &event);
    void onCommitFilter(InputContext *ic, std::string &orig);

    hymt::RequestConfig currentRequestConfig() const;
    static std::optional<std::string> currentCandidateText(InputContext *ic);
    static bool isImComposing(InputContext *ic);
    static std::string combinedSource(const HyMtContextState *state,
                                      InputContext *ic);

    void updatePanelDisplay(InputContext *ic, std::string_view buffer,
                            std::string_view preview, bool flushUi);
    void refreshBufferPanel(InputContext *ic, HyMtContextState *state,
                            bool flushUi);
    void commitTextBypass(InputContext *ic, const std::string &text,
                          bool isEnglish);
    void triggerCommitTranslation(InputContext *ic, HyMtContextState *state,
                                  const std::string &source);
    void scheduleDebounce(InputContext *ic, HyMtContextState *state,
                          const std::string &source);

    Instance *instance_;
    HyMtTranslateConfig config_;
    FactoryFor<HyMtContextState> stateFactory_;
    hymt::TranslationCache cache_;

    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>> eventWatchers_;
    ScopedConnection commitFilterConn_;

    std::shared_ptr<std::atomic<bool>> alive_;
    std::atomic<uint64_t> latestGeneration_{0};
    bool updatingPanel_ = false;
    bool bypassCommitFilter_ = false;

    std::mutex taskMutex_;
    std::condition_variable taskCv_;
    std::optional<PendingTask> pendingTask_;
    bool stopping_ = false;
    std::thread workerThread_;
};

class HyMtTranslateFactory final : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new HyMtTranslateEngine(manager->instance());
    }
};

} // namespace fcitx
