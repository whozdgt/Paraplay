#pragma once
#include <QAbstractNativeEventFilter>

class Player;

// Windows only. A graphical program has no console of its own: when it is started from a terminal, hook onto the
// terminal so --version and --help can print there.
void attachParentConsole();

// The keyboard's play/pause, next, previous and stop keys, even while another program has the focus.
class WinMedia : public QAbstractNativeEventFilter {
public:
    explicit WinMedia(Player *player);
    ~WinMedia() override;
    bool nativeEventFilter(const QByteArray &type, void *message, qintptr *result) override;

private:
    Player *m_player;
};
