#pragma once
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QPointer>
#include <QStringList>
#include <QTimer>
#include <QVector>
#include <functional>

// The words of one song. `times` (milliseconds) has one entry per line when the lyrics are synced.
struct LyricData {
    QStringList lines;
    QVector<int> times;
    bool synced = false;
    bool instrumental = false;
    bool isEmpty() const { return lines.isEmpty() && !instrumental; }
};

namespace lyrics {
// Reads LRC text ("[01:23.45] words", with the usual [offset:] header) or, when there are no
// timestamps, plain lyrics one line per row.
LyricData parse(const QString &text);
// A .lrc file with the same name next to the song.
LyricData fromSidecar(const QString &audioPath);
// Lyrics saved inside the audio file itself (ID3 USLT, Vorbis LYRICS, MP4 ©lyr).
LyricData fromTags(const QString &audioPath);
}

// Looks a song up on lrclib.net (a free, open lyrics database; no account). Answers are kept on
// this device, so each song is asked for once. Only used when the user leaves the setting on.
class OnlineLyrics : public QObject {
    Q_OBJECT
public:
    enum class Result { Found, Missing, Failed };
    using Callback = std::function<void(Result, const LyricData &)>;

    explicit OnlineLyrics(QObject *parent = nullptr);
    // One lookup at a time: asking again drops the earlier one (its callback is not called).
    void request(const QString &artist, const QString &title, const QString &album, int seconds, Callback done);
    void cancel();

private:
    void step();
    void finish(Result r, const LyricData &d);
    void fetch(const QString &endpoint, const QList<std::pair<QString, QString>> &query,
               std::function<void(int status, const QByteArray &body)> then);
    QString cachePath(const QString &ext) const;

    QNetworkAccessManager m_net;
    QPointer<QNetworkReply> m_reply;
    QTimer m_delay;                 // waits a moment so skipping through songs doesn't ask for each one
    Callback m_done;
    QString m_artist, m_title, m_album, m_key;
    int m_secs = 0;
    int m_stage = 0;
    bool m_sawError = false;
    quint64 m_gen = 0;
};
