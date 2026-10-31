#include "playstats.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QStandardPaths>
#include <algorithm>

#include "library.h"
#include "player.h"

PlayStats::PlayStats(Player *player, Library *library, QObject *parent)
    : QObject(parent), m_player(player), m_lib(library)
{
    load();
    connect(m_player, &Player::trackChanged, this, &PlayStats::onTrack);
    connect(m_player, &Player::positionChanged, this, &PlayStats::onPosition);
}

QString PlayStats::filePath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/plays.log");
}

void PlayStats::load()
{
    QFile f(filePath());
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    while (!f.atEnd()) {
        const QString line = QString::fromUtf8(f.readLine()).trimmed();
        const int tab = int(line.indexOf(QLatin1Char('\t')));
        if (tab <= 0) continue;
        bool ok = false;
        const qint64 t = line.left(tab).toLongLong(&ok);
        const QString artist = line.mid(tab + 1).trimmed();
        if (ok && !artist.isEmpty()) m_plays.push_back({t, artist});
    }
}

void PlayStats::reset(const QString &path)
{
    m_path = path;
    m_lastPos = -1;
    m_listened = 0;
    m_counted = false;
}

void PlayStats::onTrack()
{
    // The player also announces a change when a streamed song's cover arrives: only a different song starts a new count.
    if (m_player->path() != m_path) reset(m_player->path());
}

void PlayStats::onPosition()
{
    if (!m_player->hasTrack()) return;
    if (m_player->path() != m_path) reset(m_player->path());
    const double pos = m_player->position();
    if (m_lastPos > 5 && pos < 1.0) reset(m_path);      // the same song started again from the top
    if (m_counted) { m_lastPos = pos; return; }
    // Only normal progress adds to the time listened. A seek (forwards or back) or a pause adds nothing.
    if (m_lastPos >= 0 && pos > m_lastPos && pos - m_lastPos < 2.5 && m_player->playing())
        m_listened += pos - m_lastPos;
    m_lastPos = pos;
    const double dur = m_player->duration();
    const double need = dur > 0 ? std::min(30.0, std::max(4.0, dur * 0.5)) : 30.0;
    if (m_listened >= need) record();
}

void PlayStats::record()
{
    m_counted = true;
    QStringList artists;
    Track t;
    if (m_lib->find(m_path, t)) artists = m_lib->artistsOf(t);
    if (artists.isEmpty() && !m_player->artist().trimmed().isEmpty()) artists << m_player->artist().trimmed();
    if (artists.isEmpty()) return;

    const qint64 now = QDateTime::currentSecsSinceEpoch();
    QFile f(filePath());
    const bool open = f.open(QIODevice::Append | QIODevice::Text);
    for (QString a : artists) {
        a.replace(QLatin1Char('\t'), QLatin1Char(' ')).replace(QLatin1Char('\n'), QLatin1Char(' '));
        a = a.trimmed();
        if (a.isEmpty()) continue;
        m_plays.push_back({now, a});
        if (open) f.write(QByteArray::number(now) + '\t' + a.toUtf8() + '\n');
    }
    ++m_rev;
    emit changed();
}

QVariantList PlayStats::topArtists(int days, int limit) const
{
    struct Row { QString name; int n = 0; };
    QHash<QString, Row> by;
    const qint64 since = days > 0 ? QDateTime::currentSecsSinceEpoch() - qint64(days) * 86400 : 0;
    for (const Play &p : m_plays) {
        if (p.when < since) continue;
        Row &r = by[p.artist.toLower()];
        if (r.n++ == 0) r.name = p.artist;
    }
    QList<Row> rows = by.values();
    std::sort(rows.begin(), rows.end(), [](const Row &a, const Row &b) {
        return a.n != b.n ? a.n > b.n : a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });
    QVariantList out;
    for (const Row &r : rows) {
        if (out.size() >= limit) break;
        out.push_back(QVariantMap{{"name", r.name}, {"plays", r.n}});
    }
    return out;
}

void PlayStats::clear()
{
    m_plays.clear();
    QFile::remove(filePath());
    ++m_rev;
    emit changed();
}
