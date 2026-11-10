#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qstring.h>
#include <qstringlist.h>

#include <memory>

namespace caelestia::shell::services {

class JoyWake : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(int holdTimeout READ holdTimeout WRITE setHoldTimeout NOTIFY holdTimeoutChanged)
    Q_PROPERTY(QStringList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit JoyWake(QObject* parent = nullptr);
    ~JoyWake() override;

    [[nodiscard]] bool active() const;
    [[nodiscard]] bool running() const;
    void setRunning(bool running);
    [[nodiscard]] int holdTimeout() const;
    void setHoldTimeout(int seconds);
    [[nodiscard]] QStringList devices() const;
    [[nodiscard]] QString lastError() const;

signals:
    void activeChanged();
    void runningChanged();
    void holdTimeoutChanged();
    void devicesChanged();
    void lastErrorChanged();

private:
    class Private;

    std::unique_ptr<Private> d;
};

} // namespace caelestia::shell::services
