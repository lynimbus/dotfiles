#include "translator.h"

#include <curl/curl.h>
#include <nlohmann/json.hpp>

#include <mutex>
#include <utility>

namespace hymt {
namespace {

constexpr std::string_view kPromptPrefix =
    "Translate the following text into English. Note that you should only "
    "output the translated result without any additional explanation: ";

constexpr std::string_view kAuxPrefix = "EN: ";
constexpr std::string_view kBufferPrefix = "[ZH] ";

size_t writeCurlCallback(char *ptr, size_t size, size_t nmemb, void *userdata) {
    const size_t total = size * nmemb;
    auto *out = static_cast<std::string *>(userdata);
    out->append(ptr, total);
    return total;
}

void ensureCurlGlobalInit() {
    static std::once_flag flag;
    std::call_once(flag, []() { curl_global_init(CURL_GLOBAL_DEFAULT); });
}

bool isCjkIdeograph(uint32_t cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) ||   // CJK Unified Ideographs
           (cp >= 0x3400 && cp <= 0x4DBF) ||   // Extension A
           (cp >= 0xF900 && cp <= 0xFAFF) ||   // Compatibility Ideographs
           (cp >= 0x20000 && cp <= 0x2EBEF);   // Extensions B-F
}

bool decodeNextUtf8(std::string_view s, size_t &i, uint32_t &cp) {
    if (i >= s.size()) {
        return false;
    }
    const auto b0 = static_cast<uint8_t>(s[i]);
    if (b0 < 0x80) {
        cp = b0;
        ++i;
        return true;
    }
    size_t len = 0;
    uint32_t val = 0;
    if ((b0 & 0xE0) == 0xC0) {
        len = 2;
        val = b0 & 0x1F;
    } else if ((b0 & 0xF0) == 0xE0) {
        len = 3;
        val = b0 & 0x0F;
    } else if ((b0 & 0xF8) == 0xF0) {
        len = 4;
        val = b0 & 0x07;
    } else {
        cp = 0xFFFD;
        ++i;
        return true;
    }

    if (i + len > s.size()) {
        cp = 0xFFFD;
        i = s.size();
        return true;
    }
    for (size_t k = 1; k < len; ++k) {
        const auto bk = static_cast<uint8_t>(s[i + k]);
        if ((bk & 0xC0) != 0x80) {
            cp = 0xFFFD;
            ++i;
            return true;
        }
        val = (val << 6) | (bk & 0x3F);
    }
    cp = val;
    i += len;
    return true;
}

} // namespace

bool containsChinese(std::string_view text) {
    size_t i = 0;
    uint32_t cp = 0;
    while (decodeNextUtf8(text, i, cp)) {
        if (isCjkIdeograph(cp)) {
            return true;
        }
    }
    return false;
}

bool shouldBufferCommit(std::string_view currentBuffer,
                        std::string_view committed) {
    if (committed.empty()) {
        return false;
    }
    if (currentBuffer.empty() && trimWhitespace(committed).empty()) {
        return false;
    }
    return true;
}

void popLastUtf8Char(std::string &text) {
    if (text.empty()) {
        return;
    }
    size_t pos = text.size() - 1;
    while (pos > 0 && (static_cast<uint8_t>(text[pos]) & 0xC0) == 0x80) {
        --pos;
    }
    text.resize(pos);
}

std::string buildEnglishPrompt(std::string_view sourceText) {
    std::string prompt;
    prompt.reserve(kPromptPrefix.size() + sourceText.size());
    prompt.append(kPromptPrefix);
    prompt.append(sourceText);
    return prompt;
}

std::string buildChatRequestJson(const RequestConfig &cfg,
                                 std::string_view sourceText) {
    nlohmann::json body = {
        {"model", cfg.model},
        {"messages",
         nlohmann::json::array({{
             {"role", "user"},
             {"content", buildEnglishPrompt(sourceText)},
         }})},
        {"temperature", 0.7},
        {"top_p", 0.6},
        {"top_k", 20},
        {"repetition_penalty", 1.05},
        {"max_tokens", 256},
        {"stream", false},
    };
    return body.dump();
}

std::string trimWhitespace(std::string_view text) {
    const auto isWs = [](char ch) {
        return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n';
    };
    size_t start = 0;
    while (start < text.size() && isWs(text[start])) {
        ++start;
    }
    size_t end = text.size();
    while (end > start && isWs(text[end - 1])) {
        --end;
    }
    return std::string(text.substr(start, end - start));
}

TranslationResult parseChatResponseJson(std::string_view responseBody) {
    TranslationResult res;
    nlohmann::json parsed;
    try {
        parsed = nlohmann::json::parse(responseBody);
    } catch (const std::exception &e) {
        res.error = std::string("JSON parse error: ") + e.what();
        return res;
    }

    if (!parsed.is_object() || !parsed.contains("choices") ||
        !parsed["choices"].is_array() || parsed["choices"].empty()) {
        res.error = "Missing choices in response";
        return res;
    }

    const auto &first = parsed["choices"][0];
    if (!first.is_object() || !first.contains("message") ||
        !first["message"].is_object() ||
        !first["message"].contains("content") ||
        !first["message"]["content"].is_string()) {
        res.error = "Missing message.content in response";
        return res;
    }

    res.text = trimWhitespace(first["message"]["content"].get<std::string>());
    if (res.text.empty()) {
        res.error = "Empty translation text";
        return res;
    }

    res.ok = true;
    return res;
}

std::string stripAuxPreview(std::string_view existingAux) {
    if (existingAux.starts_with(kAuxPrefix)) {
        return {};
    }
    const std::string needle = "\nEN: ";
    const size_t pos = existingAux.rfind(needle);
    if (pos != std::string_view::npos) {
        return std::string(existingAux.substr(0, pos));
    }
    return std::string(existingAux);
}

std::string formatAuxWithPreview(std::string_view existingAux,
                                 std::string_view preview) {
    std::string base = stripAuxPreview(existingAux);
    if (preview.empty()) {
        return base;
    }
    if (base.empty()) {
        return std::string(kAuxPrefix) + std::string(preview);
    }
    return base + "\n" + std::string(kAuxPrefix) + std::string(preview);
}

std::string stripAuxBuffer(std::string_view existingAux) {
    if (!existingAux.starts_with(kBufferPrefix)) {
        return std::string(existingAux);
    }
    const size_t nl = existingAux.find('\n');
    if (nl == std::string_view::npos) {
        return {};
    }
    return std::string(existingAux.substr(nl + 1));
}

std::string formatAuxUpWithBuffer(std::string_view existingAux,
                                  std::string_view buffer) {
    std::string rest = stripAuxBuffer(existingAux);
    if (buffer.empty()) {
        return rest;
    }
    std::string out = std::string(kBufferPrefix) + std::string(buffer);
    if (!rest.empty()) {
        out.push_back('\n');
        out.append(rest);
    }
    return out;
}

TranslationCache::TranslationCache(std::size_t maxEntries)
    : maxEntries_(maxEntries == 0 ? 1 : maxEntries) {}

std::optional<std::string> TranslationCache::get(const std::string &key) {
    auto it = index_.find(key);
    if (it == index_.end()) {
        return std::nullopt;
    }
    lru_.splice(lru_.begin(), lru_, it->second);
    return it->second->second;
}

void TranslationCache::put(const std::string &key, std::string value) {
    auto it = index_.find(key);
    if (it != index_.end()) {
        it->second->second = std::move(value);
        lru_.splice(lru_.begin(), lru_, it->second);
        return;
    }

    if (lru_.size() >= maxEntries_) {
        const auto &oldest = lru_.back();
        index_.erase(oldest.first);
        lru_.pop_back();
    }
    lru_.emplace_front(key, std::move(value));
    index_[key] = lru_.begin();
}

void TranslationCache::clear() {
    lru_.clear();
    index_.clear();
}

HttpTranslator::HttpTranslator() {
    ensureCurlGlobalInit();
    curl_ = curl_easy_init();
}

HttpTranslator::~HttpTranslator() {
    if (curl_) {
        curl_easy_cleanup(static_cast<CURL *>(curl_));
        curl_ = nullptr;
    }
}

TranslationResult HttpTranslator::translate(const RequestConfig &cfg,
                                            std::string_view sourceText) {
    TranslationResult out;
    if (!curl_) {
        out.error = "curl handle not initialized";
        return out;
    }

    CURL *handle = static_cast<CURL *>(curl_);
    curl_easy_reset(handle);

    const std::string payload = buildChatRequestJson(cfg, sourceText);
    std::string responseBody;

    struct curl_slist *headers = nullptr;
    headers = curl_slist_append(headers, "Content-Type: application/json");

    curl_easy_setopt(handle, CURLOPT_URL, cfg.endpoint.c_str());
    curl_easy_setopt(handle, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(handle, CURLOPT_POST, 1L);
    curl_easy_setopt(handle, CURLOPT_POSTFIELDS, payload.c_str());
    curl_easy_setopt(handle, CURLOPT_POSTFIELDSIZE,
                     static_cast<long>(payload.size()));
    curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, writeCurlCallback);
    curl_easy_setopt(handle, CURLOPT_WRITEDATA, &responseBody);
    curl_easy_setopt(handle, CURLOPT_CONNECTTIMEOUT_MS, cfg.connectTimeoutMs);
    curl_easy_setopt(handle, CURLOPT_TIMEOUT_MS, cfg.timeoutMs);
    curl_easy_setopt(handle, CURLOPT_NOSIGNAL, 1L);

    const CURLcode rc = curl_easy_perform(handle);
    long httpStatus = 0;
    if (rc == CURLE_OK) {
        curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &httpStatus);
    }
    curl_slist_free_all(headers);

    if (rc != CURLE_OK) {
        out.error = curl_easy_strerror(rc);
        return out;
    }
    if (httpStatus < 200 || httpStatus >= 300) {
        out.error = "HTTP status " + std::to_string(httpStatus);
        return out;
    }

    return parseChatResponseJson(responseBody);
}

} // namespace hymt
