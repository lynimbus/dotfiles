#include "translator.h"

#include <nlohmann/json.hpp>

#include <cassert>
#include <string>

int main() {
    using namespace hymt;

    assert(containsChinese("今天天气真好"));
    assert(containsChinese("hello世界"));
    assert(!containsChinese("hello world 123!"));
    assert(!containsChinese(""));

    std::string buf = "今天a好";
    popLastUtf8Char(buf);
    assert(buf == "今天a");
    popLastUtf8Char(buf);
    assert(buf == "今天");
    popLastUtf8Char(buf);
    assert(buf == "今");
    popLastUtf8Char(buf);
    assert(buf.empty());
    popLastUtf8Char(buf);
    assert(buf.empty());

    assert(buildEnglishPrompt("你好") ==
           "Translate the following text into English. Note that you should "
           "only output the translated result without any additional "
           "explanation: 你好");

    RequestConfig cfg;
    const auto reqJson = nlohmann::json::parse(buildChatRequestJson(cfg, "你好"));
    assert(reqJson["model"] == "hy-mt2-1.8b");
    assert(reqJson["stream"] == false);
    assert(reqJson["top_k"] == 20);
    assert(reqJson["messages"].size() == 1);
    assert(reqJson["messages"][0]["role"] == "user");

    const auto okRes = parseChatResponseJson(
        R"({"choices":[{"message":{"content":"  Hello there!\n"}}]})");
    assert(okRes.ok);
    assert(okRes.text == "Hello there!");

    const auto badRes = parseChatResponseJson(R"({"choices":[]})");
    assert(!badRes.ok);

    assert(formatAuxWithPreview("", "Hello") == "EN: Hello");
    assert(formatAuxWithPreview("EN: Old", "New") == "EN: New");
    assert(formatAuxWithPreview("Page 1", "Hello") == "Page 1\nEN: Hello");
    assert(formatAuxWithPreview("Page 1\nEN: Old", "") == "Page 1");

    assert(formatAuxUpWithBuffer("", "今天天气") == "[ZH] 今天天气");
    assert(formatAuxUpWithBuffer("[ZH] 今天", "今天天气") ==
           "[ZH] 今天天气");
    assert(formatAuxUpWithBuffer("jin tian", "今天") == "[ZH] 今天\njin tian");
    assert(formatAuxUpWithBuffer("[ZH] 今天\njin tian", "") == "jin tian");

    TranslationCache cache(2);
    cache.put("a", "A");
    cache.put("b", "B");
    assert(cache.get("a") == "A");
    cache.put("c", "C");
    assert(!cache.get("b").has_value());
    assert(cache.get("a") == "A");
    assert(cache.get("c") == "C");

    return 0;
}
