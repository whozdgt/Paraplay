#include "library.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QtConcurrent/QtConcurrentRun>
#include <algorithm>
#include <cstdlib>

#include <taglib/audioproperties.h>
#include <taglib/fileref.h>
#include <taglib/flacproperties.h>
#include <taglib/mp4properties.h>
#include <taglib/tag.h>
#include <taglib/wavproperties.h>

#include "cover.h"
#include "fuzzy.h"

namespace {

QString codecFor(const QString &ext, bool alac, bool &lossless)
{
    lossless = true;
    if (ext == "flac") return "FLAC";
    if (ext == "wav") return "WAV";
    if (ext == "aif" || ext == "aiff") return "AIFF";
    if (ext == "wv") return "WavPack";
    if (ext == "ape") return "APE";
    if (ext == "m4a" || ext == "mp4") { if (alac) return "ALAC"; lossless = false; return "AAC"; }
    lossless = false;
    if (ext == "mp3") return "MP3";
    if (ext == "ogg" || ext == "oga") return "OGG";
    if (ext == "opus") return "OPUS";
    if (ext == "aac") return "AAC";
    if (ext == "wma") return "WMA";
    return ext.toUpper();
}

bool readTags(const QString &path, const QFileInfo &fi, Track &t)
{
#ifdef Q_OS_WIN
    TagLib::FileRef f(reinterpret_cast<const wchar_t *>(path.utf16()), true, TagLib::AudioProperties::Fast);
#else
    const QByteArray enc = QFile::encodeName(path);
    TagLib::FileRef f(enc.constData(), true, TagLib::AudioProperties::Fast);
#endif
    if (f.isNull()) return false;
    const auto q = [](const TagLib::String &s) { return QString::fromStdWString(s.toWString()); };
    if (TagLib::Tag *tag = f.tag()) {
        t.title = q(tag->title());
        t.artist = q(tag->artist());
        t.album = q(tag->album());
        t.trackNo = int(tag->track());
    }
    bool alac = false;
    if (TagLib::AudioProperties *ap = f.audioProperties()) {
        t.lengthMs = ap->lengthInMilliseconds();
        t.sampleRate = ap->sampleRate();
        t.bitrate = ap->bitrate();
        if (auto *fp = dynamic_cast<TagLib::FLAC::Properties *>(ap)) t.bits = fp->bitsPerSample();
        else if (auto *mp = dynamic_cast<TagLib::MP4::Properties *>(ap)) {
            t.bits = mp->bitsPerSample();
            alac = mp->codec() == TagLib::MP4::Properties::ALAC;
        } else if (auto *wp = dynamic_cast<TagLib::RIFF::WAV::Properties *>(ap)) t.bits = wp->bitsPerSample();
    }
    if (t.title.isEmpty()) t.title = fi.completeBaseName();
    if (t.artist.isEmpty()) t.artist = QStringLiteral("Unknown artist");
    if (t.album.isEmpty()) t.album = QStringLiteral("Unknown album");
    t.codec = codecFor(fi.suffix().toLower(), alac, t.lossless);
    t.path = path;
    t.mtime = fi.lastModified().toSecsSinceEpoch();
    t.size = fi.size();
    return true;
}

QVector<Track> scanDir(const QString &dir, std::shared_ptr<const QVector<Track>> old)
{
    static const QSet<QString> exts{"flac", "mp3", "m4a", "mp4", "ogg", "oga", "opus", "wav", "aif", "aiff",
                                    "ape", "wv", "aac", "wma"};
    QHash<QString, const Track *> cache;
    if (old) for (const Track &t : *old) cache.insert(t.path, &t);

    QVector<Track> out;
    QDirIterator it(dir, QDir::Files | QDir::Readable, QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);
    while (it.hasNext()) {
        const QString p = it.next();
        const QFileInfo fi = it.fileInfo();
        if (!exts.contains(fi.suffix().toLower())) continue;
        const Track *c = cache.value(p, nullptr);
        if (c && c->mtime == fi.lastModified().toSecsSinceEpoch() && c->size == fi.size()) { out.push_back(*c); continue; }
        Track t;
        if (readTags(p, fi, t)) out.push_back(std::move(t));
    }
    const auto cmp = [](const QString &a, const QString &b) { return a.compare(b, Qt::CaseInsensitive); };
    std::sort(out.begin(), out.end(), [&](const Track &a, const Track &b) {
        if (int c = cmp(a.artist, b.artist)) return c < 0;
        if (int c = cmp(a.album, b.album)) return c < 0;
        if (a.trackNo != b.trackNo) return a.trackNo < b.trackNo;
        return cmp(a.title, b.title) < 0;
    });
    return out;
}

QString cachePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    return dir + "/library-v2.bin";
}

// Same album = same title in the same folder (a CD1/CD2 subfolder counts as its parent).
QString albumKey(const Track &t)
{
    if (t.isRemote())   // a server tells us which songs belong together
        return t.album.toLower() + QChar(0x1f) + QStringLiteral("srv:") + t.serverId() + QChar(0x1f)
            + (t.albumId.isEmpty() ? t.artist.toLower() : t.albumId);
    static const QRegularExpression disc(QStringLiteral(R"(^(?:cd|disc|disk)\s*\d+$)"), QRegularExpression::CaseInsensitiveOption);
    QString dir = QFileInfo(t.path).absolutePath();
    if (disc.match(QFileInfo(dir).fileName()).hasMatch()) dir = QFileInfo(dir).absolutePath();
    return t.album.toLower() + QChar(0x1f) + dir;
}

QString mmss(int secs)
{
    return QStringLiteral("%1:%2").arg(secs / 60).arg(secs % 60, 2, 10, QLatin1Char('0'));
}

} // namespace

Library::Library(QObject *parent) : QAbstractListModel(parent), m_all(std::make_shared<QVector<Track>>())
{
    connect(&m_watcher, &QFutureWatcherBase::finished, this, &Library::onScanDone);
    loadCache();
}

int Library::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : int(m_view.size()); }

QHash<int, QByteArray> Library::roleNames() const
{
    return {{PathRole, "path"}, {TitleRole, "title"}, {ArtistRole, "artist"}, {AlbumRole, "album"},
            {DurationRole, "duration"}, {BadgeRole, "badge"}, {HiresRole, "hires"}, {TrackNoRole, "trackNo"},
            {RemoteRole, "remote"}};
}

QVariant Library::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_view.size()) return {};
    const Track &t = (*m_all)[m_view[index.row()]];
    switch (role) {
    case PathRole: return t.path;
    case TitleRole: return t.title;
    case ArtistRole: return t.artist;
    case AlbumRole: return t.album;
    case DurationRole: return mmss(t.lengthMs / 1000);
    case BadgeRole: return t.badge();
    case HiresRole: return t.hires();
    case TrackNoRole: return t.trackNo;
    case RemoteRole: return t.isRemote();
    }
    return {};
}

void Library::scan(const QString &dir)
{
    if (dir.isEmpty()) return;
    if (m_scanning) { m_pendingDir = dir; return; }
    m_scanning = true;
    emit scanningChanged();
    auto old = m_all;
    m_watcher.setFuture(QtConcurrent::run([dir, old]() { return scanDir(dir, old); }));
}

void Library::onScanDone()
{
    auto fresh = std::make_shared<QVector<Track>>(m_watcher.result());
    for (const Track &t : *m_all) if (t.isRemote()) fresh->push_back(t);      // keep the songs from servers
    beginResetModel();
    m_all = fresh;
    rebuildView();
    endResetModel();
    ++m_revision;
    emit revisionChanged();
    saveCache();
    m_scanning = false;
    emit scanningChanged();
    if (!m_pendingDir.isEmpty()) { const QString d = m_pendingDir; m_pendingDir.clear(); scan(d); }
}

void Library::rebuildView()
{
    m_view.clear();
    const QVector<Track> &all = *m_all;
    if (m_filterKind == "playlist") {
        QHash<QString, int> idx;
        for (int i = 0; i < all.size(); ++i) idx.insert(all[i].path, i);
        for (const QString &p : m_filterPaths) {
            const int i = idx.value(p, -1);
            if (i >= 0) m_view.push_back(i);
        }
    } else {
        for (int i = 0; i < all.size(); ++i) {
            const Track &t = all[i];
            if (!inSource(t)) continue;
            bool ok = m_filterKind.isEmpty();
            if (!ok && m_filterKind == "album") ok = albumKey(t) == m_filterKey;
            else if (!ok && m_filterKind == "artist") ok = artistsOf(t).contains(m_filterKey, Qt::CaseInsensitive);
            if (ok) m_view.push_back(i);
        }
    }
    if (!m_search.isEmpty()) {            // best match first
        QVector<std::pair<int, int>> scored;
        for (int i : m_view) {
            const Track &t = all[i];
            const int s = std::max({Fuzzy::score(m_search, t.title), Fuzzy::score(m_search, t.artist),
                                    Fuzzy::score(m_search, t.album) / 2});
            if (s > 0) scored.push_back({s, i});
        }
        std::stable_sort(scored.begin(), scored.end(), [](const auto &a, const auto &b) { return a.first > b.first; });
        m_view.clear();
        for (const auto &p : scored) m_view.push_back(p.second);
        return;
    }
    if (m_filterKind == "playlist") return;      // keep the playlist's own order
    const auto byTitle = [&](int a, int b) { return all[a].title.compare(all[b].title, Qt::CaseInsensitive) < 0; };
    if (m_filterKind == "album") {
        std::sort(m_view.begin(), m_view.end(), [&](int a, int b) {
            if (all[a].trackNo != all[b].trackNo) return all[a].trackNo < all[b].trackNo;
            return byTitle(a, b);
        });
    } else if (m_sortMode == "newest" || m_sortMode == "oldest") {
        const bool newest = m_sortMode == "newest";
        std::sort(m_view.begin(), m_view.end(), [&](int a, int b) {
            if (all[a].mtime != all[b].mtime) return newest ? all[a].mtime > all[b].mtime : all[a].mtime < all[b].mtime;
            return byTitle(a, b);
        });
    } else {
        std::sort(m_view.begin(), m_view.end(), byTitle);
    }
}

void Library::setSearch(const QString &s)
{
    if (s == m_search) return;
    beginResetModel();
    m_search = s;
    rebuildView();
    endResetModel();
    emit searchChanged();
}

bool Library::inSource(const Track &t) const
{
    if (m_source.isEmpty()) return true;
    if (m_source == QLatin1String("local")) return !t.isRemote();
    return t.fromServer(m_source);
}

void Library::setSource(const QString &s)
{
    if (s == m_source) return;
    beginResetModel();
    m_source = s;
    rebuildView();
    endResetModel();
    ++m_revision;                 // albums and artists are built from the same list
    emit revisionChanged();
    emit sourceChanged();
}

void Library::setRemoteTracks(const QString &serverId, QVector<Track> tracks)
{
    auto fresh = std::make_shared<QVector<Track>>();
    fresh->reserve(m_all->size() + tracks.size());
    for (const Track &t : *m_all) if (!t.fromServer(serverId)) fresh->push_back(t);
    for (Track &t : tracks) fresh->push_back(std::move(t));
    beginResetModel();
    m_all = fresh;
    rebuildView();
    endResetModel();
    ++m_revision;
    emit revisionChanged();
}

void Library::setPlaylistFilter(const QString &id, const QString &name, const QStringList &paths)
{
    beginResetModel();
    m_filterKind = QStringLiteral("playlist");
    m_filterKey = id;
    m_filterName = name;
    m_filterPaths = paths;
    rebuildView();
    endResetModel();
    emit filterChanged();
}

bool Library::find(const QString &path, Track &out) const
{
    for (const Track &t : *m_all) if (t.path == path) { out = t; return true; }
    return false;
}

bool Library::findByMeta(const QString &title, const QString &artist, const QString &album, Track &out) const
{
    for (const Track &t : *m_all)
        if (!t.title.compare(title, Qt::CaseInsensitive) && !t.artist.compare(artist, Qt::CaseInsensitive)
            && (album.isEmpty() || !t.album.compare(album, Qt::CaseInsensitive))) { out = t; return true; }
    return false;
}

namespace {
// Lower-case letters and digits only, with anything in (...) or [...] left out.
QString simplified(const QString &s)
{
    QString out, all;
    int depth = 0;
    for (const QChar c : s) {
        if (!c.isLetterOrNumber()) {
            if (c == QLatin1Char('(') || c == QLatin1Char('[')) ++depth;
            else if ((c == QLatin1Char(')') || c == QLatin1Char(']')) && depth > 0) --depth;
            continue;
        }
        const QChar f = c.toCaseFolded();
        all += f;
        if (depth == 0) out += f;
    }
    return out.isEmpty() ? all : out;     // a title that is only a bracket keeps its letters
}

bool sameArtist(const QString &a, const QString &b)
{
    if (a == b || a.isEmpty() || b.isEmpty()) return true;
    const QString &shorter = a.size() < b.size() ? a : b;
    const QString &longer = a.size() < b.size() ? b : a;
    return shorter.size() >= 3 && longer.contains(shorter);      // "Jon Hopkins" and "Jon Hopkins feat. X"
}
}

bool Library::matchLoose(const QString &title, const QString &artist, const QString &album, int durationMs, Track &out) const
{
    if (m_matchBase != m_all) {
        m_matchIndex.clear();
        for (int i = 0; i < m_all->size(); ++i) m_matchIndex[simplified((*m_all)[i].title)].push_back(i);
        m_matchBase = m_all;
    }
    const QString nt = simplified(title);
    if (nt.isEmpty()) return false;
    const auto it = m_matchIndex.constFind(nt);
    if (it == m_matchIndex.cend()) return false;
    const QString na = simplified(artist), nb = simplified(album);
    int best = -1, bestScore = -1;
    for (const int i : it.value()) {
        const Track &t = (*m_all)[i];
        if (!sameArtist(na, simplified(t.artist))) continue;
        if (durationMs > 0 && t.lengthMs > 0 && std::abs(durationMs - t.lengthMs) > 3000) continue;
        int score = 0;
        if (!nb.isEmpty() && nb == simplified(t.album)) score += 4;
        if (!t.isRemote()) score += 2;
        if (t.lossless) score += 1;
        if (score > bestScore) { bestScore = score; best = i; }
    }
    if (best < 0) return false;
    out = (*m_all)[best];
    return true;
}

QVariantList Library::suggest(const QString &kind, const QString &query, int limit) const
{
    QVector<std::pair<int, QVariantMap>> hits;
    for (const QVariant &v : groups(kind)) {
        const QVariantMap m = v.toMap();
        const int s = std::max(Fuzzy::score(query, m.value("name").toString()), Fuzzy::score(query, m.value("sub").toString()) / 3);
        if (s > 0) hits.push_back({s, m});
    }
    std::stable_sort(hits.begin(), hits.end(), [](const auto &a, const auto &b) { return a.first > b.first; });
    QVariantList out;
    for (int i = 0; i < hits.size() && i < limit; ++i) out.push_back(hits[i].second);
    return out;
}

void Library::setFilter(const QString &kind, const QString &key, const QString &label)
{
    beginResetModel();
    m_filterKind = kind;
    m_filterKey = key;
    m_filterPaths.clear();
    m_filterName = label.isEmpty() ? key : label;
    rebuildView();
    endResetModel();
    emit filterChanged();
}

void Library::clearFilter() { if (!m_filterKind.isEmpty()) setFilter(QString(), QString()); }

void Library::setSortMode(const QString &m)
{
    if (m == m_sortMode) return;
    beginResetModel();
    m_sortMode = m;
    rebuildView();
    endResetModel();
    emit sortModeChanged();
}

void Library::setSplitOptions(bool commaAmp, const QString &exceptions)
{
    m_splitCommaAmp = commaAmp;
    m_exceptions.clear();
    for (const QString &l : exceptions.split('\n', Qt::SkipEmptyParts)) {
        const QString e = l.trimmed();
        if (!e.isEmpty()) m_exceptions << e;
    }
    beginResetModel();
    rebuildView();
    endResetModel();
    ++m_revision;
    emit revisionChanged();
}

// "A feat. B", "A; B", "A / B" always split. ", " and " & " split too unless the name is in the keep-together list.
QStringList Library::artistsOf(const Track &t) const
{
    QString s = t.artist;
    for (int i = 0; i < m_exceptions.size(); ++i) {
        const int at = s.indexOf(m_exceptions[i], 0, Qt::CaseInsensitive);
        if (at >= 0) s.replace(at, m_exceptions[i].size(), QStringLiteral("\x01%1\x02").arg(i));
    }
    static const QRegularExpression strong(QStringLiteral(R"(\s+(?:feat\.?|ft\.?|featuring)\s+|\s*[;/]\s*)"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression weak(QStringLiteral(R"(\s*,\s*|\s+&\s+)"));
    QStringList parts = s.split(strong, Qt::SkipEmptyParts);
    if (m_splitCommaAmp) {
        QStringList out;
        for (const QString &p : parts) out += p.split(weak, Qt::SkipEmptyParts);
        parts = out;
    }
    QStringList res;
    for (QString p : parts) {
        p = p.trimmed();
        for (int i = 0; i < m_exceptions.size(); ++i) p.replace(QStringLiteral("\x01%1\x02").arg(i), m_exceptions[i]);
        if (!p.isEmpty() && !res.contains(p, Qt::CaseInsensitive)) res << p;
    }
    return res.isEmpty() ? QStringList{t.artist} : res;
}

QVariantList Library::groups(const QString &kind) const
{
    QVariantList out;
    if (kind == "album") {
        struct G { QString name, key, art; int n = 0; bool remote = false; QHash<QString, int> lead; };
        QHash<QString, G> map;
        for (const Track &t : *m_all) {
            if (!inSource(t)) continue;
            const QString key = albumKey(t);
            G &g = map[key];
            if (g.n++ == 0) { g.name = t.album; g.key = key; g.art = coverUrl(t); g.remote = t.isRemote(); }
            ++g.lead[artistsOf(t).value(0)];
        }
        QList<G> list = map.values();
        std::sort(list.begin(), list.end(), [](const G &a, const G &b) { return a.name.compare(b.name, Qt::CaseInsensitive) < 0; });
        for (const G &g : list) {
            QString top; int best = 0;
            for (auto it = g.lead.cbegin(); it != g.lead.cend(); ++it)
                if (it.value() > best) { best = it.value(); top = it.key(); }
            QVariantMap m;
            m["name"] = g.name;
            m["key"] = g.key;
            m["sub"] = (g.lead.size() > 1 && best * 2 < g.n) ? QStringLiteral("Various artists") : top;
            m["art"] = g.art;
            m["remote"] = g.remote;
            out.push_back(m);
        }
        return out;
    }
    struct A { QString name; int n = 0; };
    QHash<QString, A> map;
    for (const Track &t : *m_all) {
        if (!inSource(t)) continue;
        for (const QString &n : artistsOf(t)) {
            A &a = map[n.toLower()];
            if (a.n++ == 0) a.name = n;
        }
    }
    QList<A> list = map.values();
    std::sort(list.begin(), list.end(), [](const A &a, const A &b) { return a.name.compare(b.name, Qt::CaseInsensitive) < 0; });
    for (const A &a : list) {
        QVariantMap m;
        m["name"] = a.name;
        m["key"] = a.name;
        m["sub"] = QStringLiteral("%1 tracks").arg(a.n);
        out.push_back(m);
    }
    return out;
}

void Library::loadCache()
{
    QFile f(cachePath());
    if (!f.open(QIODevice::ReadOnly)) return;
    QDataStream s(&f);
    s.setVersion(QDataStream::Qt_6_0);
    quint32 magic = 0;
    qint32 n = 0;
    s >> magic >> n;
    if (magic != 0x4D555332 || n < 0) return;
    auto v = std::make_shared<QVector<Track>>();
    v->reserve(n);
    for (qint32 i = 0; i < n && s.status() == QDataStream::Ok; ++i) { Track t; s >> t; v->push_back(std::move(t)); }
    if (s.status() != QDataStream::Ok) return;
    m_all = v;
    rebuildView();
}

void Library::saveCache() const
{
    QFile f(cachePath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    QDataStream s(&f);
    s.setVersion(QDataStream::Qt_6_0);
    qint32 n = 0;
    for (const Track &t : *m_all) if (!t.isRemote()) ++n;
    s << quint32(0x4D555332) << n;
    for (const Track &t : *m_all) if (!t.isRemote()) s << t;
}
