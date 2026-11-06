#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

#include <qstring.h>
#include <qstringlist.h>

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;

class AiConfig : public settings::ObjectNode {
    CONFIG_NODE(AiConfig, settings::ObjectNode)

    CONFIG_PROPERTY(QString, ollamaUrl, u"http://localhost:11434"_s)
    CONFIG_PROPERTY(QString, ollamaModel, u"llama3"_s)
    
    CONFIG_PROPERTY(bool, saveChatHistory, true)
    CONFIG_PROPERTY(QString, ollamaHistoryJson, u"[]"_s)

    CONFIG_PROPERTY(bool, snapToDefaultOllama, true)
    CONFIG_PROPERTY(QString, defaultOllamaModel, u"llama3"_s)

    CONFIG_PROPERTY(QString, defaultProvider, u"ollama"_s)
    CONFIG_PROPERTY(bool, enableOllama, true)
    CONFIG_PROPERTY(bool, enableCelestialMode, false)
    CONFIG_PROPERTY(QString, orionModel, u"qwen3.5:9b"_s)

    CONFIG_PROPERTY(QString, activeProvider, u"ollama"_s)
    CONFIG_PROPERTY(QString, activeOllamaModel, u"llama3"_s)

    // OpenRouter (cloud, OpenAI-compatible)
    CONFIG_PROPERTY(bool, enableOpenRouter, false)
    CONFIG_PROPERTY(QString, openRouterUrl, u"https://openrouter.ai/api/v1"_s)
    CONFIG_PROPERTY(QString, openRouterApiKey, u""_s)
    CONFIG_PROPERTY(QString, openRouterModel, u"openrouter/auto"_s)

    // OpenClaw (self-hosted gateway, OpenAI-compatible surface)
    CONFIG_PROPERTY(bool, enableOpenClaw, false)
    CONFIG_PROPERTY(QString, openClawUrl, u"http://127.0.0.1:18789"_s)
    CONFIG_PROPERTY(QString, openClawToken, u""_s)
    CONFIG_PROPERTY(QString, openClawModel, u"openclaw/default"_s)

    // Model selector recents, stored as "provider|model" entries, newest first
    CONFIG_PROPERTY(QStringList, recentModels, {})
};

} // namespace caelestia::shell::config
