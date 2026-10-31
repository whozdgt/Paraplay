#include "winmedia.h"

#include <QCoreApplication>
#include <cstdio>

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include "player.h"

void attachParentConsole()
{
    // Only when nothing was redirected: a pipe or a file given by the caller keeps working as it is.
    const HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
    if ((!out || out == INVALID_HANDLE_VALUE) && AttachConsole(ATTACH_PARENT_PROCESS)) {
        FILE *f = nullptr;
        freopen_s(&f, "CONOUT$", "w", stdout);
        freopen_s(&f, "CONOUT$", "w", stderr);
    }
}

namespace {
constexpr int kPlay = 1, kNext = 2, kPrev = 3, kStop = 4;
}

WinMedia::WinMedia(Player *player) : m_player(player)
{
    // Another program may already own a key; then that key simply doesn't reach us.
    RegisterHotKey(nullptr, kPlay, 0, VK_MEDIA_PLAY_PAUSE);
    RegisterHotKey(nullptr, kNext, 0, VK_MEDIA_NEXT_TRACK);
    RegisterHotKey(nullptr, kPrev, 0, VK_MEDIA_PREV_TRACK);
    RegisterHotKey(nullptr, kStop, 0, VK_MEDIA_STOP);
    QCoreApplication::instance()->installNativeEventFilter(this);
}

WinMedia::~WinMedia()
{
    if (QCoreApplication::instance()) QCoreApplication::instance()->removeNativeEventFilter(this);
    for (int id : {kPlay, kNext, kPrev, kStop}) UnregisterHotKey(nullptr, id);
}

bool WinMedia::nativeEventFilter(const QByteArray &type, void *message, qintptr *)
{
    if (type != "windows_generic_MSG") return false;
    const MSG *msg = static_cast<const MSG *>(message);
    if (msg->message != WM_HOTKEY) return false;
    switch (int(msg->wParam)) {
    case kPlay: m_player->toggle(); return true;
    case kNext: m_player->next(); return true;
    case kPrev: m_player->prev(); return true;
    case kStop: m_player->stop(); return true;
    }
    return false;
}
