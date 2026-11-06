#pragma once

#include <qjsonvalue.h>
#include <qmap.h>
#include <qset.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;

// Custom (user-defined) session buttons are stored as extra keys in the
// `icons` / `commands` objects in the config file. Unknown keys are captured
// during syncJson and re-emitted in toJson.
class SessionIcons : public settings::ObjectNode {
    CONFIG_NODE(SessionIcons, settings::ObjectNode)

    CONFIG_PROPERTY(QString, logout, u"logout"_s)
    CONFIG_PROPERTY(QString, shutdown, u"power_settings_new"_s)
    CONFIG_PROPERTY(QString, hibernate, u"downloading"_s)
    CONFIG_PROPERTY(QString, reboot, u"cached"_s)

public:
    [[nodiscard]] const QMap<QString, QString>& customIcons() const { return m_customIcons; }
    [[nodiscard]] const QStringList& customIconKeys() const { return m_customIconKeys; }

    void setCustomIcon(const QString& key, const QString& icon);
    void removeCustomIcon(const QString& key);

    [[nodiscard]] QJsonValue toJson(bool sparse = true) const override;
    bool syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) override;

signals:
    void customIconsChanged();

private:
    QMap<QString, QString> m_customIcons;
    QStringList m_customIconKeys;
};

class SessionCommands : public settings::ObjectNode {
    CONFIG_NODE(SessionCommands, settings::ObjectNode)

    CONFIG_PROPERTY(QStringList, logout, { u"logout"_s })
    CONFIG_PROPERTY(QStringList, shutdown, { u"poweroff"_s })
    CONFIG_PROPERTY(QStringList, hibernate, { u"hibernate"_s })
    CONFIG_PROPERTY(QStringList, reboot, { u"reboot"_s })

public:
    [[nodiscard]] const QMap<QString, QStringList>& customCommands() const { return m_customCommands; }
    [[nodiscard]] const QStringList& customCommandKeys() const { return m_customCommandKeys; }

    void setCustomCommand(const QString& key, const QStringList& command);
    void removeCustomCommand(const QString& key);

    [[nodiscard]] QJsonValue toJson(bool sparse = true) const override;
    bool syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) override;

signals:
    void customCommandsChanged();

private:
    QMap<QString, QStringList> m_customCommands;
    QStringList m_customCommandKeys;
};

class SessionConfig : public settings::ObjectNode {
    CONFIG_NODE(SessionConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, dragThreshold, 30)
    CONFIG_PROPERTY(bool, vimKeybinds, false)
    CONFIG_SUBOBJECT(SessionIcons, icons)
    CONFIG_SUBOBJECT(SessionCommands, commands)

    Q_PROPERTY(QVariantList buttons READ buttons NOTIFY buttonsChanged)
    Q_PROPERTY(QVariantList customButtons READ customButtons NOTIFY customButtonsChanged)

public:
    [[nodiscard]] QVariantList buttons() const;
    [[nodiscard]] QVariantList customButtons() const;

signals:
    void buttonsChanged();
    void customButtonsChanged();

private:
    void refreshButtons();
};

} // namespace caelestia::shell::config
