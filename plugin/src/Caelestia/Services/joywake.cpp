#include "joywake.hpp"

#include <qbytearray.h>
#include <qfileinfo.h>
#include <qhash.h>
#include <qloggingcategory.h>
#include <qsocketnotifier.h>
#include <qtimer.h>
#include <qtypes.h>

#include <libudev.h>
#include <linux/input.h>
#include <sys/ioctl.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <memory>
#include <unistd.h>
#include <vector>

namespace {

Q_LOGGING_CATEGORY(lcJoyWake, "caelestia.services.joywake", QtInfoMsg)

constexpr qsizetype kEventsPerRead = 64;
constexpr int kHoldTimeoutMin = 1;
constexpr int kHoldTimeoutMax = 3600;

constexpr std::array<int, 8> kCachedAxes = { ABS_X, ABS_Y, ABS_RX, ABS_RY, ABS_Z, ABS_RZ, ABS_THROTTLE, ABS_RUDDER };

} // namespace

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;

class JoyWake::Private {
public:
    struct Device {
        QString path;
        int fd = -1;
        QSocketNotifier* notifier = nullptr;
        QHash<int, input_absinfo> absInfo;
    };

    explicit Private(JoyWake* owner)
        : q(owner) {}

    JoyWake* q = nullptr;
    udev* context = nullptr;
    udev_monitor* monitor = nullptr;
    QSocketNotifier* monitorNotifier = nullptr;
    QTimer* holdTimer = nullptr;
    std::vector<std::unique_ptr<Device>> devices;
    QString lastError;
    bool running = false;
    bool active = false;
    int holdTimeout = 30;

    void start() {
        if (running)
            return;

        context = udev_new();
        if (!context) {
            setLastError(u"Failed to create udev context"_s);
            qCWarning(lcJoyWake) << "Failed to create udev context";
            return;
        }

        refreshDevices();

        monitor = udev_monitor_new_from_netlink(context, "udev");
        if (!monitor) {
            setLastError(u"Failed to create udev monitor"_s);
            qCWarning(lcJoyWake) << "Failed to create udev monitor";
            stop();
            return;
        }

        udev_monitor_filter_add_match_subsystem_devtype(monitor, "input", nullptr);

        if (udev_monitor_enable_receiving(monitor) < 0) {
            setLastError(u"Failed to start udev monitor"_s);
            qCWarning(lcJoyWake) << "Failed to start udev monitor";
            stop();
            return;
        }

        const int fd = udev_monitor_get_fd(monitor);
        if (fd < 0) {
            setLastError(u"Failed to get udev monitor fd"_s);
            qCWarning(lcJoyWake) << "Failed to get udev monitor fd";
            stop();
            return;
        }

        monitorNotifier = new QSocketNotifier(fd, QSocketNotifier::Read, q);
        QObject::connect(monitorNotifier, &QSocketNotifier::activated, q, [this] { handleMonitor(); });

        running = true;
        emit q->runningChanged();
        qCInfo(lcJoyWake) << "Watching for joystick activity";
    }

    void stop() {
        const bool wasRunning = running;
        running = false;

        if (monitorNotifier) {
            monitorNotifier->setEnabled(false);
            delete monitorNotifier;
            monitorNotifier = nullptr;
        }

        for (auto& device : devices) {
            if (device->notifier) {
                device->notifier->setEnabled(false);
                delete device->notifier;
                device->notifier = nullptr;
            }
            if (device->fd >= 0) {
                ::close(device->fd);
                device->fd = -1;
            }
        }

        if (!devices.empty()) {
            devices.clear();
            emit q->devicesChanged();
        }

        if (monitor) {
            udev_monitor_unref(monitor);
            monitor = nullptr;
        }

        if (context) {
            udev_unref(context);
            context = nullptr;
        }

        if (active) {
            active = false;
            holdTimer->stop();
            emit q->activeChanged();
        }

        if (wasRunning)
            emit q->runningChanged();
    }

    void refreshDevices() {
        udev_enumerate* enumerate = udev_enumerate_new(context);
        if (!enumerate) {
            setLastError(u"Failed to create udev enumerator"_s);
            qCWarning(lcJoyWake) << "Failed to create udev enumerator";
            return;
        }

        udev_enumerate_add_match_subsystem(enumerate, "input");
        udev_enumerate_add_match_property(enumerate, "ID_INPUT_JOYSTICK", "1");
        udev_enumerate_scan_devices(enumerate);

        udev_list_entry* entries = udev_enumerate_get_list_entry(enumerate);
        udev_list_entry* entry = nullptr;
        udev_list_entry_foreach(entry, entries) {
            const char* syspath = udev_list_entry_get_name(entry);
            udev_device* device = udev_device_new_from_syspath(context, syspath);
            if (!device)
                continue;

            const char* node = udev_device_get_devnode(device);
            if (node)
                addDevice(QString::fromUtf8(node));

            udev_device_unref(device);
        }

        udev_enumerate_unref(enumerate);
    }

    void addDevice(const QString& path) {
        if (!QFileInfo(path).fileName().startsWith(u"event"_s))
            return;

        for (const auto& device : devices) {
            if (device->path == path)
                return;
        }

        const QByteArray nativePath = path.toUtf8();
        const int fd = ::open(nativePath.constData(), O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) {
            setLastError(u"%1: %2"_s.arg(path, QString::fromUtf8(std::strerror(errno))));
            qCWarning(lcJoyWake) << "Failed to open" << path << ":" << std::strerror(errno);
            return;
        }

        auto device = std::make_unique<Device>();
        device->path = path;
        device->fd = fd;

        for (const int code : kCachedAxes) {
            input_absinfo info{};
            if (::ioctl(fd, static_cast<unsigned long>(EVIOCGABS(static_cast<unsigned int>(code))), &info) == 0)
                device->absInfo.insert(code, info);
        }

        auto* raw = device.get();
        raw->notifier = new QSocketNotifier(fd, QSocketNotifier::Read, q);
        QObject::connect(raw->notifier, &QSocketNotifier::activated, q, [this, raw] { readDevice(raw); });

        devices.push_back(std::move(device));

        if (!lastError.isEmpty()) {
            lastError.clear();
            emit q->lastErrorChanged();
        }

        qCInfo(lcJoyWake) << "Watching joystick" << path;
        emit q->devicesChanged();
    }

    void removeDevice(const QString& path) {
        for (auto it = devices.begin(); it != devices.end(); ++it) {
            if ((*it)->path != path)
                continue;

            if ((*it)->notifier) {
                (*it)->notifier->setEnabled(false);
                QObject::disconnect((*it)->notifier, nullptr, q, nullptr);
                (*it)->notifier->deleteLater();
                (*it)->notifier = nullptr;
            }

            if ((*it)->fd >= 0) {
                ::close((*it)->fd);
                (*it)->fd = -1;
            }

            devices.erase(it);
            qCInfo(lcJoyWake) << "Stopped watching joystick" << path;
            emit q->devicesChanged();
            return;
        }
    }

    void readDevice(Device* device) {
        input_event events[kEventsPerRead];

        while (true) {
            const ssize_t bytes = ::read(device->fd, events, sizeof(events));
            if (bytes < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK)
                    return;

                qCWarning(lcJoyWake) << "Failed to read" << device->path << ":" << std::strerror(errno);
                removeDevice(device->path);
                return;
            }

            if (bytes == 0) {
                removeDevice(device->path);
                return;
            }

            const auto count = static_cast<qsizetype>(bytes) / static_cast<qsizetype>(sizeof(input_event));
            for (qsizetype i = 0; i < count; ++i) {
                if (isActivity(*device, events[i]))
                    markActivity();
            }
        }
    }

    bool isActivity(const Device& device, const input_event& event) const {
        switch (event.type) {
        case EV_KEY:
        case EV_REL:
            return true;
        case EV_ABS:
            return isSignificantAxis(device, static_cast<int>(event.code), static_cast<qint32>(event.value));
        default:
            return false;
        }
    }

    bool isSignificantAxis(const Device& device, int code, qint32 value) const {
        switch (code) {
        case ABS_Z:
        case ABS_RZ:
        case ABS_GAS:
        case ABS_BRAKE:
        case ABS_HAT0X:
        case ABS_HAT0Y:
        case ABS_HAT1X:
        case ABS_HAT1Y:
        case ABS_HAT2X:
        case ABS_HAT2Y:
        case ABS_HAT3X:
        case ABS_HAT3Y:
        case ABS_THROTTLE:
        case ABS_RUDDER:
        case ABS_WHEEL:
            return true;
        case ABS_X:
        case ABS_Y:
        case ABS_RX:
        case ABS_RY: {
            const auto it = device.absInfo.constFind(code);
            if (it == device.absInfo.constEnd())
                return true;

            const input_absinfo& info = it.value();
            const qint64 range = static_cast<qint64>(info.maximum) - static_cast<qint64>(info.minimum);
            if (range <= 0)
                return true;

            const qint64 center = (static_cast<qint64>(info.minimum) + static_cast<qint64>(info.maximum)) / 2;
            const qint64 deadzone = std::max<qint64>(range / 8, static_cast<qint64>(info.flat));
            const qint64 delta = static_cast<qint64>(value) - center;
            return (delta < 0 ? -delta : delta) > deadzone;
        }
        default:
            return false;
        }
    }

    void markActivity() {
        if (!active) {
            active = true;
            qCDebug(lcJoyWake) << "Joystick activity started";
            emit q->activeChanged();
        }

        holdTimer->start(holdTimeout * 1000);
    }

    void handleMonitor() {
        udev_device* device = udev_monitor_receive_device(monitor);
        if (!device)
            return;

        const char* action = udev_device_get_action(device);
        const char* node = udev_device_get_devnode(device);
        const QString path = node ? QString::fromUtf8(node) : QString();

        if (!path.isEmpty()) {
            if (action && qstrcmp(action, "remove") == 0) {
                removeDevice(path);
            } else {
                const char* joystick = udev_device_get_property_value(device, "ID_INPUT_JOYSTICK");
                if (joystick && qstrcmp(joystick, "1") == 0)
                    addDevice(path);
            }
        }

        udev_device_unref(device);
    }

    void setLastError(const QString& error) {
        if (lastError == error)
            return;

        lastError = error;
        emit q->lastErrorChanged();
    }
};

JoyWake::JoyWake(QObject* parent)
    : QObject(parent)
    , d(std::make_unique<Private>(this)) {
    d->holdTimer = new QTimer(this);
    d->holdTimer->setSingleShot(true);
    connect(d->holdTimer, &QTimer::timeout, this, [this] {
        if (!d->active)
            return;

        d->active = false;
        qCDebug(lcJoyWake) << "Joystick idle hold expired";
        emit activeChanged();
    });
}

JoyWake::~JoyWake() {
    blockSignals(true);
    d->stop();
}

bool JoyWake::active() const {
    return d->active;
}

bool JoyWake::running() const {
    return d->running;
}

void JoyWake::setRunning(bool running) {
    if (running == d->running)
        return;

    if (running)
        d->start();
    else
        d->stop();
}

int JoyWake::holdTimeout() const {
    return d->holdTimeout;
}

void JoyWake::setHoldTimeout(int seconds) {
    const int clamped = std::clamp(seconds, kHoldTimeoutMin, kHoldTimeoutMax);
    if (clamped == d->holdTimeout)
        return;

    d->holdTimeout = clamped;

    if (d->active)
        d->holdTimer->start(d->holdTimeout * 1000);

    emit holdTimeoutChanged();
}

QStringList JoyWake::devices() const {
    QStringList paths;
    paths.reserve(static_cast<qsizetype>(d->devices.size()));

    for (const auto& device : d->devices)
        paths.append(device->path);

    return paths;
}

QString JoyWake::lastError() const {
    return d->lastError;
}

} // namespace caelestia::shell::services
