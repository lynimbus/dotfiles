#pragma once

#include <cstddef>
#include <cstdint>
#include <list>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>

namespace hymt {

struct RequestConfig {
    std::string endpoint = "http://127.0.0.1:11435/v1/chat/completions";
    std::string model = "hy-mt2-1.8b";
    long connectTimeoutMs = 300;
    long timeoutMs = 5000;
};

struct TranslationResult {
    bool ok = false;
    std::string text;
    std::string error;
};

/// Return true if UTF-8 input contains at least one CJK ideograph.
bool containsChinese(std::string_view text);

/// Remove the last UTF-8 codepoint from a string in place.
void popLastUtf8Char(std::string &text);

/// Build the official Hy-MT2 English translation user prompt.
std::string buildEnglishPrompt(std::string_view sourceText);

/// Build the OpenAI-compatible JSON payload for llama-server.
std::string buildChatRequestJson(const RequestConfig &cfg,
                                 std::string_view sourceText);

/// Parse an OpenAI-compatible chat completion response and trim whitespace.
TranslationResult parseChatResponseJson(std::string_view responseBody);

/// Trim leading and trailing ASCII whitespace.
std::string trimWhitespace(std::string_view text);

/// Strip any previously appended "EN: ..." preview from auxDown text.
std::string stripAuxPreview(std::string_view existingAux);

/// Format auxDown text combining any existing Rime text with the EN preview.
std::string formatAuxWithPreview(std::string_view existingAux,
                                 std::string_view preview);

/// Strip any previously prepended "[ZH] ..." buffer line from auxUp text.
std::string stripAuxBuffer(std::string_view existingAux);

/// Format auxUp text combining the buffered Chinese sentence and existing auxUp.
std::string formatAuxUpWithBuffer(std::string_view existingAux,
                                  std::string_view buffer);

/// Simple bounded LRU cache for translated sentences.
class TranslationCache {
public:
    explicit TranslationCache(std::size_t maxEntries = 256);

    std::optional<std::string> get(const std::string &key);
    void put(const std::string &key, std::string value);
    void clear();

private:
    std::size_t maxEntries_;
    using Entry = std::pair<std::string, std::string>;
    std::list<Entry> lru_;
    std::unordered_map<std::string, std::list<Entry>::iterator> index_;
};

/// Persistent single-thread HTTP client backed by libcurl.
class HttpTranslator {
public:
    HttpTranslator();
    ~HttpTranslator();

    HttpTranslator(const HttpTranslator &) = delete;
    HttpTranslator &operator=(const HttpTranslator &) = delete;

    TranslationResult translate(const RequestConfig &cfg,
                                std::string_view sourceText);

private:
    void *curl_ = nullptr;
};

} // namespace hymt
