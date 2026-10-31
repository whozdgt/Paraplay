#include "lyrics.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStringDecoder>
#include <QUrl>
#include <QUrlQuery>
#include <algorithm>
#include <cmath>
#include <optional>

#include <taglib/fileref.h>
#include <taglib/tfile.h>
#include <taglib/tpropertymap.h>
#include <taglib/tstringlist.h>

#ifndef APP_VERSION
#define APP_VERSION "0"
#endif

namespace {

QString decode(const QByteArray &bytes)
{
    QStringDecoder dec(QStringDecoder::Utf8, QStringDecoder::Flag::Stateless);
    QString s = dec(bytes);
    if (dec.hasError()) s = QString::fromLocal8Bit(bytes);      // an old file saved in the system's code page
    if (s.startsWith(QChar(0xFEFF))) s.remove(0, 1);
    return s;
}

// Lyrics with no timestamps: one row per line, one blank row between verses.
LyricData plain(const QString &text)
{
    LyricData d;
    const QStringList rows = text.split(QLatin1Char('\n'));
    bool lastBlank = true;
    for (const QString &raw : rows) {
        const QString row = raw.trimmed();
        if (row.isEmpty()) {
            if (!lastBlank) d.lines << QString();
            lastBlank = true;
        } else {
            d.lines << row;
            lastBlank = false;
        }
    }
    while (!d.lines.isEmpty() && d.lines.last().isEmpty()) d.lines.removeLast();
    return d;
}

QString norm(const QString &s)
{
    static const QRegularExpression re(QStringLiteral("[^\\p{L}\\p{N}]"));
    QString r = s.toLower();
    r.remove(re);
    return r;
}

// "A, B", "A & B", "A feat. B" -> "A"
QString primaryArtist(const QString &a)
{
    static const QRegularExpression re(QStringLiteral(R"(\s*(?:,|;|/|&|\bfeat\.?|\bft\.?|\bfeaturing\b)\s*)"),
                                       QRegularExpression::CaseInsensitiveOption);
    const QString first = a.section(re, 0, 0).trimmed();
    return first.isEmpty() ? a.trimmed() : first;
}

// "Song (feat. X) - 2011 Remaster" -> "Song"
QString cleanTitle(const QString &t)
{
    static const QRegularExpression brackets(QStringLiteral(R"(\s*[\(\[][^\)\]]*[\)\]])"));
    static const QRegularExpression dash(QStringLiteral(R"(\s+-\s+.*(?:remaster|version|edit|mix|live|mono|stereo|deluxe|bonus|single).*$)"),
                                         QRegularExpression::CaseInsensitiveOption);
    QString r = t;
    r.remove(brackets);
    r.remove(dash);
    r = r.trimmed();
    return r.isEmpty() ? t.trimmed() : r;
}

}

LyricData lyrics::parse(const QString &textIn)
{
    static const QRegularExpression stamp(QStringLiteral(R"(\[(\d+):(\d+)(?:[.:](\d+))?\])"));
    static const QRegularExpression wordTag(QStringLiteral(R"(<\d+:\d+(?:[.:]\d+)?>)"));
    static const QRegularExpression offsetTag(QStringLiteral(R"(^\[offset:\s*([+-]?\d+)\s*\]$)"),
                                              QRegularExpression::CaseInsensitiveOption);
    QString text = textIn;
    text.remove(QLatin1Char('\r'));
    if (text.startsWith(QChar(0xFEFF))) text.remove(0, 1);

    QVector<std::pair<int, QString>> items;
    int offset = 0;
    for (const QString &raw : text.split(QLatin1Char('\n'))) {
        const QString line = raw.trimmed();
        if (const auto om = offsetTag.match(line); om.hasMatch()) { offset = om.captured(1).toInt(); continue; }
        QVector<int> times;
        qsizetype last = 0;
        auto it = stamp.globalMatch(line);
        while (it.hasNext()) {
            const auto m = it.next();
            if (m.capturedStart() != last) break;               // timestamps only count at the start of the row
            int ms = m.captured(1).toInt() * 60000 + m.captured(2).toInt() * 1000;
            const QString frac = m.captured(3);
            if (!frac.isEmpty()) ms += frac.leftJustified(3, QLatin1Char('0')).left(3).toInt();
            times.push_back(ms);
            last = m.capturedEnd();
        }
        if (times.isEmpty()) continue;
        QString words = line.mid(last);
        words.remove(wordTag);
        words = words.trimmed();
        for (int ms : times) items.push_back({std::max(0, ms - offset), words});
    }
    if (items.isEmpty()) return plain(text);

    std::stable_sort(items.begin(), items.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
    LyricData d;
    d.synced = true;
    for (const auto &p : items) { d.times.push_back(p.first); d.lines << p.second; }
    return d;
}

LyricData lyrics::fromSidecar(const QString &audioPath)
{
    const QFileInfo fi(audioPath);
    QFile f(fi.path() + QLatin1Char('/') + fi.completeBaseName() + QStringLiteral(".lrc"));
    if (!f.open(QIODevice::ReadOnly)) return {};
    return parse(decode(f.readAll()));
}

LyricData lyrics::fromTags(const QString &audioPath)
{
#ifdef Q_OS_WIN
    TagLib::FileRef f(reinterpret_cast<const wchar_t *>(audioPath.utf16()), false);
#else
    const QByteArray enc = QFile::encodeName(audioPath);
    TagLib::FileRef f(enc.constData(), false);
#endif
    if (f.isNull() || !f.file()) return {};
    const TagLib::PropertyMap props = f.file()->properties();
    QString best;
    for (const auto &kv : props) {
        const QString key = QString::fromStdWString(kv.first.toWString()).toUpper();
        if (!key.startsWith(QStringLiteral("LYRICS")) && !key.startsWith(QStringLiteral("UNSYNCED")) && !key.startsWith(QStringLiteral("SYNCEDLYRICS")))
            continue;
        for (const auto &v : kv.second) {
            const QString s = QString::fromStdWString(v.toWString());
            if (s.trimmed().size() > best.trimmed().size()) best = s;     // several copies: keep the fullest
        }
    }
    if (best.trimmed().isEmpty()) return {};
    return lyrics::parse(best);
}

// ---------------------------------------------------------------------------------------------

OnlineLyrics::OnlineLyrics(QObject *parent) : QObject(parent)
{
    QDir().mkpath(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/lyrics"));
    m_delay.setSingleShot(true);
    m_delay.setInterval(700);
    connect(&m_delay, &QTimer::timeout, this, &OnlineLyrics::step);
}

QString OnlineLyrics::cachePath(const QString &ext) const
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/lyrics/") + m_key + ext;
}

void OnlineLyrics::cancel()
{
    ++m_gen;
    m_delay.stop();
    m_done = nullptr;
    if (m_reply) m_reply->abort();
}

void OnlineLyrics::finish(Result r, const LyricData &d)
{
    Callback cb = std::move(m_done);
    m_done = nullptr;
    if (cb) cb(r, d);
}

void OnlineLyrics::request(const QString &artist, const QString &title, const QString &album, int seconds, Callback done)
{
    cancel();
    m_done = std::move(done);
    m_artist = artist.trimmed(); m_title = title.trimmed(); m_album = album.trimmed();
    m_secs = seconds;
    m_stage = 0;
    m_sawError = false;
    const quint64 gen = m_gen;
    m_key = QString::fromLatin1(QCryptographicHash::hash((norm(m_artist) + QLatin1Char('|') + norm(m_title) + QLatin1Char('|')
                                                          + QString::number(seconds)).toUtf8(), QCryptographicHash::Sha1).toHex().left(20));

    // Saved from an earlier time? Then no network at all.
    LyricData cached;
    bool have = false;
    if (QFile f(cachePath(QStringLiteral(".lrc"))); f.open(QIODevice::ReadOnly)) { cached = lyrics::parse(decode(f.readAll())); have = !cached.isEmpty(); }
    else if (QFile g(cachePath(QStringLiteral(".txt"))); g.open(QIODevice::ReadOnly)) { cached = plain(decode(g.readAll())); have = !cached.isEmpty(); }
    else if (QFileInfo::exists(cachePath(QStringLiteral(".inst")))) { cached.instrumental = true; have = true; }
    if (have) {
        QTimer::singleShot(0, this, [this, gen, cached] { if (gen == m_gen) finish(Result::Found, cached); });
        return;
    }
    const QFileInfo none(cachePath(QStringLiteral(".none")));
    if (none.exists() && none.lastModified().daysTo(QDateTime::currentDateTime()) < 7) {
        QTimer::singleShot(0, this, [this, gen] { if (gen == m_gen) finish(Result::Missing, {}); });
        return;
    }
    m_delay.start();
}

void OnlineLyrics::fetch(const QString &endpoint, const QList<std::pair<QString, QString>> &query,
                         std::function<void(int, const QByteArray &)> then)
{
    QUrl url(QStringLiteral("https://lrclib.net/api/") + endpoint);
    QUrlQuery q;
    for (const auto &kv : query) q.addQueryItem(kv.first, kv.second);
    url.setQuery(q);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Paraplay/" APP_VERSION " (https://github.com/whozdgt/Paraplay)"));
    req.setRawHeader("Accept", "application/json");
    req.setTransferTimeout(10000);
    QNetworkReply *r = m_net.get(req);
    m_reply = r;
    const quint64 gen = m_gen;
    connect(r, &QNetworkReply::finished, this, [this, r, gen, then = std::move(then)] {
        r->deleteLater();
        if (gen != m_gen) return;
        then(r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), r->readAll());
    });
}

void OnlineLyrics::step()
{
    const QString cleaned = cleanTitle(m_title);
    const QString primary = primaryArtist(m_artist);
    const int secs = (m_secs >= 1 && m_secs <= 3600) ? m_secs : 0;
    const quint64 gen = m_gen;

    // What a good answer looks like -> LyricData (and a copy kept on this device).
    const auto accept = [this](const QJsonObject &o, LyricData &out) -> bool {
        if (o.value(QStringLiteral("instrumental")).toBool()) {
            out = {};
            out.instrumental = true;
            QFile f(cachePath(QStringLiteral(".inst")));
            if (f.open(QIODevice::WriteOnly)) f.close();
            return true;
        }
        const QString synced = o.value(QStringLiteral("syncedLyrics")).toString();
        if (!synced.trimmed().isEmpty()) {
            out = lyrics::parse(synced);
            if (out.synced) {
                QFile f(cachePath(QStringLiteral(".lrc")));
                if (f.open(QIODevice::WriteOnly)) f.write(synced.toUtf8());
                return true;
            }
        }
        const QString pl = o.value(QStringLiteral("plainLyrics")).toString();
        if (!pl.trimmed().isEmpty()) {
            out = plain(pl);
            QFile f(cachePath(QStringLiteral(".txt")));
            if (f.open(QIODevice::WriteOnly)) f.write(pl.toUtf8());
            return !out.isEmpty();
        }
        return false;
    };
    const auto giveUp = [this] {
        if (m_sawError) { finish(Result::Failed, {}); return; }
        QFile f(cachePath(QStringLiteral(".none")));      // remember that there was nothing, for a week
        if (f.open(QIODevice::WriteOnly)) f.close();
        finish(Result::Missing, {});
    };
    const auto next = [this] { ++m_stage; step(); };

    if (m_stage == 0 || m_stage == 1) {
        QList<std::pair<QString, QString>> q;
        const bool exact = m_stage == 0;
        q.push_back({QStringLiteral("track_name"), exact ? m_title : cleaned});
        q.push_back({QStringLiteral("artist_name"), exact ? m_artist : primary});
        if (exact && !m_album.isEmpty()) q.push_back({QStringLiteral("album_name"), m_album});
        if (secs) q.push_back({QStringLiteral("duration"), QString::number(secs)});
        // Round two only differs when the title, artist or album would be sent differently.
        if (!exact && cleaned == m_title && primary == m_artist && m_album.isEmpty()) { next(); return; }
        fetch(QStringLiteral("get"), q, [=, this](int status, const QByteArray &body) {
            if (gen != m_gen) return;
            if (status == 200) {
                LyricData d;
                if (accept(QJsonDocument::fromJson(body).object(), d)) { finish(Result::Found, d); return; }
                next();
            } else if (status == 404 || status == 400) {
                next();
            } else {
                m_sawError = true;                          // offline, busy or told to slow down: try again another time
                giveUp();
            }
        });
        return;
    }

    if (m_stage == 2) {
        fetch(QStringLiteral("search"), {{QStringLiteral("track_name"), cleaned}, {QStringLiteral("artist_name"), primary}},
              [=, this](int status, const QByteArray &body) {
            if (gen != m_gen) return;
            if (status != 200) {
                if (status != 404) m_sawError = true;
                giveUp();
                return;
            }
            const QJsonArray arr = QJsonDocument::fromJson(body).array();
            const QString want = norm(primary);
            std::optional<QJsonObject> bestSynced, bestPlain;
            for (const auto &v : arr) {
                const QJsonObject o = v.toObject();
                const QString who = norm(o.value(QStringLiteral("artistName")).toString());
                if (who.isEmpty() || want.isEmpty() || (!who.contains(want) && !want.contains(who))) continue;
                if (secs && std::abs(o.value(QStringLiteral("duration")).toDouble() - secs) > 3) continue;
                if (!bestSynced && !o.value(QStringLiteral("syncedLyrics")).toString().trimmed().isEmpty()) bestSynced = o;
                if (!bestPlain && !o.value(QStringLiteral("plainLyrics")).toString().trimmed().isEmpty()) bestPlain = o;
            }
            LyricData d;
            bool ok = false;
            if (bestSynced) ok = accept(*bestSynced, d);
            if (!ok && bestPlain) ok = accept(*bestPlain, d);
            if (ok) finish(Result::Found, d);
            else giveUp();
        });
        return;
    }
    giveUp();
}
