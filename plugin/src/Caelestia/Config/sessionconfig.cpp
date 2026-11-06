#include "sessionconfig.hpp"

#include <qjsonarray.h>
#include <qjsonobject.h>

namespace caelestia::shell::config {

namespace {

const QSet<QString>& knownSessionKeys() {
    static const QSet<QString> keys = {
        u"logout"_s,
        u"shutdown"_s,
        u"hibernate"_s,
        u"reboot"_s,
    };
    return keys;
}

void appendUnique(QStringList& list, const QString& key) {
    if (!list.contains(key))
        list.append(key);
}

} // namespace

// --- SessionIcons ---

bool SessionIcons::syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) {
    if (json.isObject()) {
        // Capture custom (unknown) keys, then hand the known subset to the base sync so
        // they do not produce UnknownOption diagnostics.
        const auto obj = json.toObject();
        QJsonObject filtered;
        for (auto it = obj.begin(); it != obj.end(); ++it) {
            if (!knownSessionKeys().contains(it.key())) {
                appendUnique(m_customIconKeys, it.key());
                m_customIcons.insert(it.key(), it.value().toString());
            } else {
                filtered.insert(it.key(), it.value());
            }
        }
        const bool ok = ObjectNode::syncJson(filtered, diagnostics);
        emit customIconsChanged();
        return ok;
    }
    return ObjectNode::syncJson(json, diagnostics);
}

QJsonValue SessionIcons::toJson(bool sparse) const {
    QJsonObject obj;
    const auto base = ObjectNode::toJson(sparse);
    if (base.isObject())
        obj = base.toObject();

    for (auto it = m_customIcons.constBegin(); it != m_customIcons.constEnd(); ++it)
        obj.insert(it.key(), it.value());

    if (obj.isEmpty())
        return QJsonValue::Undefined;
    return obj;
}

void SessionIcons::setCustomIcon(const QString& key, const QString& icon) {
    appendUnique(m_customIconKeys, key);
    m_customIcons.insert(key, icon);
    emit customIconsChanged();
}

void SessionIcons::removeCustomIcon(const QString& key) {
    m_customIcons.remove(key);
    m_customIconKeys.removeAll(key);
    emit customIconsChanged();
}

// --- SessionCommands ---

bool SessionCommands::syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) {
    if (json.isObject()) {
        const auto obj = json.toObject();
        QJsonObject filtered;
        for (auto it = obj.begin(); it != obj.end(); ++it) {
            if (!knownSessionKeys().contains(it.key())) {
                QStringList cmdList;
                const auto val = it.value();
                if (val.isArray()) {
                    const auto arr = val.toArray();
                    for (const auto& v : arr)
                        cmdList.append(v.toString());
                } else if (val.isString()) {
                    cmdList.append(val.toString());
                }
                appendUnique(m_customCommandKeys, it.key());
                m_customCommands.insert(it.key(), cmdList);
            } else {
                filtered.insert(it.key(), it.value());
            }
        }
        const bool ok = ObjectNode::syncJson(filtered, diagnostics);
        emit customCommandsChanged();
        return ok;
    }
    return ObjectNode::syncJson(json, diagnostics);
}

QJsonValue SessionCommands::toJson(bool sparse) const {
    QJsonObject obj;
    const auto base = ObjectNode::toJson(sparse);
    if (base.isObject())
        obj = base.toObject();

    for (auto it = m_customCommands.constBegin(); it != m_customCommands.constEnd(); ++it) {
        QJsonArray arr;
        for (const auto& s : it.value())
            arr.append(s);
        obj.insert(it.key(), arr);
    }

    if (obj.isEmpty())
        return QJsonValue::Undefined;
    return obj;
}

void SessionCommands::setCustomCommand(const QString& key, const QStringList& command) {
    appendUnique(m_customCommandKeys, key);
    m_customCommands.insert(key, command);
    emit customCommandsChanged();
}

void SessionCommands::removeCustomCommand(const QString& key) {
    m_customCommands.remove(key);
    m_customCommandKeys.removeAll(key);
    emit customCommandsChanged();
}

// --- SessionConfig ---

void SessionConfig::refreshButtons() {
    emit buttonsChanged();
    emit customButtonsChanged();
}

QVariantList SessionConfig::buttons() const {
    QVariantList result;

    const auto* iconsNode = icons();
    const auto* commandsNode = commands();
    if (!iconsNode || !commandsNode)
        return result;

    static const QStringList defaultKeys = {
        u"logout"_s,
        u"shutdown"_s,
        u"hibernate"_s,
        u"reboot"_s,
    };

    QStringList orderedKeys;
    QSet<QString> seen;

    // Custom keys first (in captured order), then the standard four.
    for (const auto& key : iconsNode->customIconKeys()) {
        if (!seen.contains(key)) {
            seen.insert(key);
            orderedKeys.append(key);
        }
    }
    for (const auto& key : commandsNode->customCommandKeys()) {
        if (!seen.contains(key)) {
            seen.insert(key);
            orderedKeys.append(key);
        }
    }
    for (const auto& key : defaultKeys) {
        if (!seen.contains(key)) {
            seen.insert(key);
            orderedKeys.append(key);
        }
    }

    for (const auto& key : orderedKeys) {
        QVariantMap btn;
        btn.insert(u"key"_s, key);

        QString icon = key;
        if (iconsNode->customIcons().contains(key)) {
            icon = iconsNode->customIcons().value(key);
        } else {
            const QVariant iconProp = iconsNode->value(key);
            if (iconProp.isValid() && iconProp.userType() == QMetaType::QString)
                icon = iconProp.toString();
        }
        btn.insert(u"icon"_s, icon);

        QStringList command;
        if (commandsNode->customCommands().contains(key)) {
            command = commandsNode->customCommands().value(key);
        } else {
            const QVariant cmdProp = commandsNode->value(key);
            if (cmdProp.isValid() && cmdProp.userType() == QMetaType::QStringList)
                command = cmdProp.toStringList();
            else
                command = QStringList { key };
        }
        btn.insert(u"command"_s, QVariant::fromValue(command));

        result.append(btn);
    }

    return result;
}

QVariantList SessionConfig::customButtons() const {
    QVariantList result;

    const auto* iconsNode = icons();
    const auto* commandsNode = commands();
    if (!iconsNode || !commandsNode)
        return result;

    QStringList orderedKeys;
    QSet<QString> seen;

    for (const auto& key : iconsNode->customIconKeys()) {
        if (!knownSessionKeys().contains(key) && !seen.contains(key)) {
            seen.insert(key);
            orderedKeys.append(key);
        }
    }
    for (const auto& key : commandsNode->customCommandKeys()) {
        if (!knownSessionKeys().contains(key) && !seen.contains(key)) {
            seen.insert(key);
            orderedKeys.append(key);
        }
    }

    for (const auto& key : orderedKeys) {
        QVariantMap btn;
        btn.insert(u"key"_s, key);

        QString icon = key;
        if (iconsNode->customIcons().contains(key))
            icon = iconsNode->customIcons().value(key);
        btn.insert(u"icon"_s, icon);

        QStringList command;
        if (commandsNode->customCommands().contains(key)) {
            command = commandsNode->customCommands().value(key);
        } else {
            command = QStringList { key };
        }
        btn.insert(u"command"_s, QVariant::fromValue(command));

        result.append(btn);
    }

    return result;
}

} // namespace caelestia::shell::config
