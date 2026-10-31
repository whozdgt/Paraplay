package io.github.whozdgt.paraplay;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ServiceInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;

/**
 * Keeps the music playing when the app is not on screen, and gives the phone a media notification and lock-screen
 * controls. The sound itself is still played by the app (Qt); this service only keeps the process alive, shows the
 * controls, and forwards button presses back to the app through nativeCommand().
 *
 * Commands sent to the app: 0 play, 1 pause, 2 next, 3 previous, 4 seek to (arg = milliseconds), 5 stop.
 */
public class MediaService extends Service {
    static final String CHANNEL = "playback";
    static final int NOTIFICATION_ID = 7;
    static final String PKG = "io.github.whozdgt.paraplay";
    static final String ACT_PLAY = PKG + ".PLAY";
    static final String ACT_PAUSE = PKG + ".PAUSE";
    static final String ACT_NEXT = PKG + ".NEXT";
    static final String ACT_PREV = PKG + ".PREV";
    static final String ACT_STOP = PKG + ".STOP";

    /** What the app last told us about the current song. */
    static final class State {
        String title = "", artist = "", album = "";
        long durationMs, positionMs;
        boolean playing, streaming;
        Bitmap cover;
    }

    static volatile MediaService instance;
    private static State pending;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    // Registered by the app's C++ code at start-up (QJniEnvironment::registerNativeMethods).
    static native void nativeCommand(int cmd, long arg);

    static void send(int cmd, long arg) {
        try { nativeCommand(cmd, arg); } catch (Throwable t) { /* the app side isn't running */ }
    }

    // ---- called from the app (any thread) ----

    public static void update(Context ctx, String title, String artist, String album, long durationMs, long positionMs,
                              boolean playing, boolean streaming, byte[] cover) {
        final Context app = ctx.getApplicationContext();
        final State s = new State();
        s.title = title == null ? "" : title;
        s.artist = artist == null ? "" : artist;
        s.album = album == null ? "" : album;
        s.durationMs = durationMs;
        s.positionMs = positionMs;
        s.playing = playing;
        s.streaming = streaming;
        if (cover != null && cover.length > 0) {
            try { s.cover = BitmapFactory.decodeByteArray(cover, 0, cover.length); } catch (Throwable t) { s.cover = null; }
        }
        MAIN.post(new Runnable() {
            @Override public void run() {
                MediaService svc = instance;
                if (svc != null) { svc.apply(s); return; }
                if (!s.playing) return;              // nothing to show until something plays
                pending = s;
                try {
                    Intent i = new Intent(app, MediaService.class);
                    if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(i); else app.startService(i);
                } catch (Throwable t) {
                    pending = null;                  // Android refused to start it (app not in the foreground)
                }
            }
        });
    }

    public static void stop(Context ctx) {
        final Context app = ctx.getApplicationContext();
        MAIN.post(new Runnable() {
            @Override public void run() {
                pending = null;
                MediaService svc = instance;
                if (svc != null) svc.shutDown();
            }
        });
    }

    // ---- the service ----

    private MediaSession session;
    private NotificationManager notes;
    private State state;
    private boolean foreground;
    private PowerManager.WakeLock wake;
    private WifiManager.WifiLock wifi;
    private AudioManager audio;
    private AudioFocusRequest focusRequest;
    private boolean hasFocus, resumeOnGain;

    private final BroadcastReceiver noisy = new BroadcastReceiver() {
        @Override public void onReceive(Context c, Intent i) { send(1, 0); }      // headphones unplugged
    };

    private final AudioManager.OnAudioFocusChangeListener focusListener = new AudioManager.OnAudioFocusChangeListener() {
        @Override public void onAudioFocusChange(int change) {
            switch (change) {
                case AudioManager.AUDIOFOCUS_LOSS:
                    hasFocus = false; resumeOnGain = false; send(1, 0); break;
                case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
                    resumeOnGain = state != null && state.playing; send(1, 0); break;
                case AudioManager.AUDIOFOCUS_GAIN:
                    hasFocus = true;
                    if (resumeOnGain) { resumeOnGain = false; send(0, 0); }
                    break;
                default: break;                       // ducking: keep playing at full volume
            }
        }
    };

    @Override public IBinder onBind(Intent intent) { return null; }

    @Override public void onCreate() {
        super.onCreate();
        instance = this;
        notes = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        audio = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel ch = new NotificationChannel(CHANNEL, "Playback", NotificationManager.IMPORTANCE_LOW);
            ch.setDescription("Controls for the music that is playing");
            ch.setShowBadge(false);
            notes.createNotificationChannel(ch);
        }
        session = new MediaSession(this, "Paraplay");
        session.setCallback(new MediaSession.Callback() {
            @Override public void onPlay() { send(0, 0); }
            @Override public void onPause() { send(1, 0); }
            @Override public void onSkipToNext() { send(2, 0); }
            @Override public void onSkipToPrevious() { send(3, 0); }
            @Override public void onSeekTo(long pos) { send(4, pos); }
            @Override public void onStop() { send(5, 0); }
        }, MAIN);
        PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "paraplay:playback");
        wake.setReferenceCounted(false);
        WifiManager wm = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wm != null) {
            wifi = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "paraplay:stream");
            wifi.setReferenceCounted(false);
        }
        registerReceiver(noisy, new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY));
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        String act = intent == null ? null : intent.getAction();
        if (act != null) {
            if (ACT_PLAY.equals(act)) send(0, 0);
            else if (ACT_PAUSE.equals(act)) send(1, 0);
            else if (ACT_NEXT.equals(act)) send(2, 0);
            else if (ACT_PREV.equals(act)) send(3, 0);
            else if (ACT_STOP.equals(act)) { shutDown(); return START_NOT_STICKY; }
        }
        State s = pending;
        pending = null;
        if (s != null) apply(s);
        if (act == null && !foreground && (state == null || !state.playing)) {
            // started with startForegroundService, so Android insists on a notification right away
            try { startForegroundCompat(buildNotification()); } catch (Throwable t) { /* ignore */ }
            if (state == null) { shutDown(); }
        }
        return START_NOT_STICKY;
    }

    @Override public void onTaskRemoved(Intent rootIntent) {
        // the app was swiped away: the player inside it is gone, so there is nothing left to control
        shutDown();
        super.onTaskRemoved(rootIntent);
    }

    @Override public void onDestroy() {
        instance = null;
        try { unregisterReceiver(noisy); } catch (Throwable t) { /* ignore */ }
        releaseLocks();
        abandonFocus();
        if (session != null) { session.setActive(false); session.release(); session = null; }
        super.onDestroy();
    }

    private void shutDown() {
        releaseLocks();
        abandonFocus();
        try { stopForeground(true); } catch (Throwable t) { /* ignore */ }
        foreground = false;
        if (notes != null) notes.cancel(NOTIFICATION_ID);
        state = null;
        stopSelf();
    }

    private void apply(State s) {
        state = s;
        if (session == null) return;
        MediaMetadata.Builder md = new MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, s.title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, s.artist)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, s.album)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, s.durationMs);
        if (s.cover != null) md.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, s.cover);
        session.setMetadata(md.build());
        long actions = PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE | PlaybackState.ACTION_PLAY_PAUSE
                | PlaybackState.ACTION_SKIP_TO_NEXT | PlaybackState.ACTION_SKIP_TO_PREVIOUS
                | PlaybackState.ACTION_SEEK_TO | PlaybackState.ACTION_STOP;
        session.setPlaybackState(new PlaybackState.Builder()
                .setActions(actions)
                .setState(s.playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED, s.positionMs, s.playing ? 1.0f : 0.0f)
                .build());
        session.setActive(true);

        Notification n = buildNotification();
        if (s.playing) {
            requestFocus();
            acquireLocks(s.streaming);
            try { startForegroundCompat(n); } catch (Throwable t) { notes.notify(NOTIFICATION_ID, n); }
        } else {
            releaseLocks();
            if (foreground) {
                try { stopForeground(Service.STOP_FOREGROUND_DETACH); } catch (Throwable t) { /* ignore */ }
                foreground = false;
            }
            notes.notify(NOTIFICATION_ID, n);       // stays in the shade, no longer pinned, so it can be swiped away
        }
    }

    private void startForegroundCompat(Notification n) {
        if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        else startForeground(NOTIFICATION_ID, n);
        foreground = true;
    }

    private PendingIntent action(String act, int code) {
        Intent i = new Intent(this, MediaService.class).setAction(act);
        return PendingIntent.getService(this, code, i, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }

    private Notification.Action button(int icon, String label, String act, int code) {
        return new Notification.Action.Builder(Icon.createWithResource(this, icon), label, action(act, code)).build();
    }

    private Notification buildNotification() {
        State s = state;
        boolean playing = s != null && s.playing;
        Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, CHANNEL) : new Notification.Builder(this);
        int small = getResources().getIdentifier("ic_launcher_monochrome", "mipmap", getPackageName());
        if (small == 0) small = android.R.drawable.ic_media_play;
        b.setSmallIcon(small)
         .setContentTitle(s == null || s.title.isEmpty() ? "Paraplay" : s.title)
         .setContentText(s == null ? "" : s.artist)
         .setSubText(s == null ? null : s.album)
         .setShowWhen(false)
         .setOngoing(playing)
         .setOnlyAlertOnce(true)
         .setVisibility(Notification.VISIBILITY_PUBLIC)
         .setDeleteIntent(action(ACT_STOP, 5));
        if (s != null && s.cover != null) b.setLargeIcon(s.cover);
        Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (open != null) {
            open.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            b.setContentIntent(PendingIntent.getActivity(this, 0, open, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT));
        }
        b.addAction(button(android.R.drawable.ic_media_previous, "Previous", ACT_PREV, 1));
        if (playing) b.addAction(button(android.R.drawable.ic_media_pause, "Pause", ACT_PAUSE, 2));
        else b.addAction(button(android.R.drawable.ic_media_play, "Play", ACT_PLAY, 3));
        b.addAction(button(android.R.drawable.ic_media_next, "Next", ACT_NEXT, 4));
        Notification.MediaStyle style = new Notification.MediaStyle().setShowActionsInCompactView(0, 1, 2);
        if (session != null) style.setMediaSession(session.getSessionToken());
        b.setStyle(style);
        return b.build();
    }

    // ---- keeping the music going with the screen off ----

    private void acquireLocks(boolean streaming) {
        if (wake != null && !wake.isHeld()) wake.acquire();
        if (wifi != null) {
            if (streaming && !wifi.isHeld()) wifi.acquire();
            else if (!streaming && wifi.isHeld()) wifi.release();
        }
    }

    private void releaseLocks() {
        try { if (wake != null && wake.isHeld()) wake.release(); } catch (Throwable t) { /* ignore */ }
        try { if (wifi != null && wifi.isHeld()) wifi.release(); } catch (Throwable t) { /* ignore */ }
    }

    private void requestFocus() {
        if (hasFocus || audio == null) return;
        if (Build.VERSION.SDK_INT >= 26) {
            if (focusRequest == null) {
                focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                        .setAudioAttributes(new AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_MEDIA)
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                        .setOnAudioFocusChangeListener(focusListener, MAIN)
                        .build();
            }
            hasFocus = audio.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
        }
    }

    private void abandonFocus() {
        if (audio != null && focusRequest != null && Build.VERSION.SDK_INT >= 26) audio.abandonAudioFocusRequest(focusRequest);
        hasFocus = false;
    }
}
