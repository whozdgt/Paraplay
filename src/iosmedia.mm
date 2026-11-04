#include "iosmedia.h"

#include <QImage>

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>

#include "cover.h"
#include "player.h"

// Built with ARC (see CMakeLists.txt): Objective-C objects kept in the C++ members are held with __bridge_retained
// and let go with __bridge_transfer.

namespace {
UIImage *toUIImage(const QImage &src)
{
    if (src.isNull()) return nil;
    QImage img = src.convertToFormat(QImage::Format_RGBA8888);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CFDataRef data = CFDataCreate(nullptr, img.constBits(), img.sizeInBytes());
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGImageRef cg = CGImageCreate(img.width(), img.height(), 8, 32, img.bytesPerLine(), cs,
                                  CGBitmapInfo(kCGBitmapByteOrderDefault) | CGBitmapInfo(kCGImageAlphaLast), provider, nullptr, false,
                                  kCGRenderingIntentDefault);
    UIImage *out = cg ? [UIImage imageWithCGImage:cg] : nil;
    if (cg) CGImageRelease(cg);
    CGDataProviderRelease(provider);
    CFRelease(data);
    CGColorSpaceRelease(cs);
    return out;
}
} // namespace

IosMedia::IosMedia(Player *player, QObject *parent) : QObject(parent), m_p(player)
{
    // "Playback": keeps playing with the screen locked and the silent switch on, like any music app.
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:&err];
    [session setActive:YES error:&err];

    // A phone call or an alarm interrupts the music: pause, so it doesn't jump back in by surprise afterwards.
    Player *p = m_p;
    id obs = [[NSNotificationCenter defaultCenter]
        addObserverForName:AVAudioSessionInterruptionNotification object:session queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *n) {
                    const NSUInteger type = [n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
                    if (type == AVAudioSessionInterruptionTypeBegan && p->playing()) p->toggle();
                }];
    m_observer = (__bridge_retained void *)obs;

    MPRemoteCommandCenter *cc = [MPRemoteCommandCenter sharedCommandCenter];
    const auto add = [this](MPRemoteCommand *cmd, MPRemoteCommandHandlerStatus (^handler)(MPRemoteCommandEvent *)) {
        cmd.enabled = YES;
        id target = [cmd addTargetWithHandler:handler];
        m_targets.append((__bridge_retained void *)target);
    };
    add(cc.playCommand, ^(MPRemoteCommandEvent *) {
        if (!p->hasTrack()) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
        if (!p->playing()) p->toggle();
        return MPRemoteCommandHandlerStatusSuccess;
    });
    add(cc.pauseCommand, ^(MPRemoteCommandEvent *) {
        if (p->playing()) p->toggle();
        return MPRemoteCommandHandlerStatusSuccess;
    });
    add(cc.togglePlayPauseCommand, ^(MPRemoteCommandEvent *) {
        if (!p->hasTrack()) return MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
        p->toggle();
        return MPRemoteCommandHandlerStatusSuccess;
    });
    add(cc.nextTrackCommand, ^(MPRemoteCommandEvent *) {
        p->next();
        return MPRemoteCommandHandlerStatusSuccess;
    });
    add(cc.previousTrackCommand, ^(MPRemoteCommandEvent *) {
        p->prev();
        return MPRemoteCommandHandlerStatusSuccess;
    });
    add(cc.changePlaybackPositionCommand, ^(MPRemoteCommandEvent *e) {
        p->seek(((MPChangePlaybackPositionCommandEvent *)e).positionTime);
        return MPRemoteCommandHandlerStatusSuccess;
    });

    m_delay.setSingleShot(true);
    m_delay.setInterval(150);          // a song change fires several signals in a row; send one update
    connect(&m_delay, &QTimer::timeout, this, &IosMedia::push);
    connect(m_p, &Player::trackChanged, this, &IosMedia::schedule);
    connect(m_p, &Player::playingChanged, this, &IosMedia::schedule);
    connect(m_p, &Player::positionChanged, this, [this]() {
        // a seek: the position jumps away from where the lock screen expects it to be
        if (!m_p->playing() || !m_clock.isValid()) return;
        const double expected = m_sentPos + m_clock.elapsed() / 1000.0;
        if (qAbs(m_p->position() - expected) > 1.5) schedule();
    });
}

IosMedia::~IosMedia()
{
    MPRemoteCommandCenter *cc = [MPRemoteCommandCenter sharedCommandCenter];
    for (void *t : m_targets) {
        id target = (__bridge_transfer id)t;
        for (MPRemoteCommand *cmd in @[cc.playCommand, cc.pauseCommand, cc.togglePlayPauseCommand, cc.nextTrackCommand,
                                        cc.previousTrackCommand, cc.changePlaybackPositionCommand])
            [cmd removeTarget:target];
    }
    m_targets.clear();
    if (m_observer) [[NSNotificationCenter defaultCenter] removeObserver:(__bridge_transfer id)m_observer];
    if (m_artwork) { id a = (__bridge_transfer id)m_artwork; (void)a; }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
}

void IosMedia::schedule() { m_delay.start(); }

void IosMedia::push()
{
    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
    if (!m_p->hasTrack()) {
        center.nowPlayingInfo = nil;
        return;
    }
    const QString path = m_p->path();
    if (path != m_coverPath) {
        if (m_artwork) { id old = (__bridge_transfer id)m_artwork; (void)old; m_artwork = nullptr; }
        const bool streaming = path.startsWith(QLatin1String("srv://"));
        QImage img = streaming ? m_p->coverImage() : loadCover(path, QSize(600, 600));
        if (UIImage *ui = toUIImage(img)) {
            MPMediaItemArtwork *art = [[MPMediaItemArtwork alloc] initWithBoundsSize:ui.size
                                                                      requestHandler:^UIImage *(CGSize) { return ui; }];
            m_artwork = (__bridge_retained void *)art;
        }
        // a streamed song's cover can arrive a moment later: try again next time
        m_coverPath = (streaming && img.isNull()) ? QString() : path;
    }
    m_sentPos = m_p->position();
    m_clock.start();

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = m_p->title().toNSString();
    info[MPMediaItemPropertyArtist] = m_p->artist().toNSString();
    info[MPMediaItemPropertyAlbumTitle] = m_p->album().toNSString();
    info[MPMediaItemPropertyPlaybackDuration] = @(m_p->duration());
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(m_sentPos);
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(m_p->playing() ? 1.0 : 0.0);
    info[MPNowPlayingInfoPropertyMediaType] = @(MPNowPlayingInfoMediaTypeAudio);
    if (m_artwork) info[MPMediaItemPropertyArtwork] = (__bridge id)m_artwork;
    center.nowPlayingInfo = info;
    center.playbackState = m_p->playing() ? MPNowPlayingPlaybackStatePlaying : MPNowPlayingPlaybackStatePaused;
}
