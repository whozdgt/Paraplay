#include "playlists.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUuid>
#include <algorithm>

#include "cover.h"
#include "fuzzy.h"
#include "library.h"

namespace { qint64 now() { return QDateTime::currentMSecsSinceEpoch(); } }

Playlists::Playlists(Library *lib, QObject *parent) : QObject(parent), m_lib(lib) { load(); }

QString Playlists::filePath(const QString &profile) const
{
    const QString d = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(d);
    return d + (profile.isEmpty() ? QStringLiteral("/playlists.json") : QStringLiteral("/playlists-%1.json").arg(profile));
}

Playlists::Pl *Playlists::find(const QString &id)
{
    for (Pl &p : m_pls) if (p.id == id) return &p;
    return nullptr;
}

void Playlists::load()
{
    m_pls.clear();
    m_deleted.clear();
    QFile f(filePath(m_profile));
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    const QJsonArray arr = doc.isArray() ? doc.array() : doc.object().value(QLatin1String("playlists")).toArray();
    for (const QJsonValue &v : arr) {
        const QJsonObject o = v.toObject();
        Pl p;
        p.id = o.value(QLatin1String("id")).toString();
        p.name = o.value(QLatin1String("name")).toString();
        p.updated = qint64(o.value(QLatin1String("updated")).toDouble());
        p.shared = o.value(QLatin1String("shared")).toBool();
        for (const QJsonValue &tv : o.value(QLatin1String("tracks")).toArray()) {
            const QJsonObject t = tv.toObject();
            p.items.push_back({t.value(QLatin1String("path")).toString(), t.value(QLatin1String("title")).toString(),
                               t.value(QLatin1String("artist")).toString(), t.value(QLatin1String("album")).toString()});
        }
        if (!p.id.isEmpty()) m_pls.push_back(p);
    }
    for (const QJsonValue &d : doc.object().value(QLatin1String("deleted")).toArray()) m_deleted << d.toString();
}

void Playlists::save()
{
    QJsonArray arr;
    for (const Pl &p : m_pls) {
        QJsonArray tracks;
        for (const Item &i : p.items)
            tracks.push_back(QJsonObject{{"path", i.path}, {"title", i.title}, {"artist", i.artist}, {"album", i.album}});
        arr.push_back(QJsonObject{{"id", p.id}, {"name", p.name}, {"updated", double(p.updated)}, {"shared", p.shared}, {"tracks", tracks}});
    }
    QJsonArray del;
    for (const QString &d : m_deleted) del.push_back(d);
    QFile f(filePath(m_profile));
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(QJsonObject{{"playlists", arr}, {"deleted", del}}).toJson(QJsonDocument::Compact));
}

void Playlists::useProfile(const QString &id)
{
    if (id == m_profile) return;
    save();
    m_profile = id;
    // first sign-in on this computer: start from the guest playlists
    if (!id.isEmpty() && !QFile::exists(filePath(id)) && QFile::exists(filePath(QString())))
        QFile::copy(filePath(QString()), filePath(id));
    load();
    ++m_rev;
    emit revisionChanged();
}

QVariantList Playlists::list() const
{
    QVariantList out;
    for (const Pl &p : m_pls) {
        QVariantMap m;
        m["key"] = p.id;
        m["name"] = p.name;
        m["shared"] = p.shared;
        m["sub"] = p.items.size() == 1 ? QStringLiteral("1 song") : QStringLiteral("%1 songs").arg(p.items.size());
        QString art;
        for (const Item &i : p.items) {
            if (i.path.isEmpty()) continue;
            if (i.path.startsWith(QLatin1String("srv://"))) { Track t; if (m_lib->find(i.path, t)) art = coverUrl(t); }
            else art = coverUrl(i.path);
            if (!art.isEmpty()) break;
        }
        m["art"] = art;
        out.push_back(m);
    }
    return out;
}

QString Playlists::create(const QString &name)
{
    Pl p;
    p.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    p.name = name.trimmed().isEmpty() ? QStringLiteral("New playlist") : name.trimmed().left(60);
    p.updated = now();
    m_pls.push_back(p);
    changed();
    return p.id;
}

QString Playlists::createWith(const QString &name, const QStringList &paths)
{
    Pl p;
    p.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    p.name = name.trimmed().isEmpty() ? QStringLiteral("New playlist") : name.trimmed().left(60);
    p.updated = now();
    for (const QString &path : paths) {
        Track t;
        Item it{path, {}, {}, {}};
        if (m_lib->find(path, t)) it = {path, t.title, t.artist, t.album};
        p.items.push_back(it);
    }
    m_pls.push_back(p);
    changed();
    return p.id;
}

void Playlists::rename(const QString &id, const QString &name)
{
    if (Pl *p = find(id); p && !name.trimmed().isEmpty()) { p->name = name.trimmed().left(60); p->updated = now(); changed(); }
}

void Playlists::remove(const QString &id)
{
    for (int i = 0; i < m_pls.size(); ++i)
        if (m_pls[i].id == id) { m_pls.remove(i); m_deleted << id; changed(); return; }
}

void Playlists::addTrack(const QString &id, const QString &path)
{
    Pl *p = find(id);
    if (!p) return;
    for (const Item &i : std::as_const(p->items)) if (i.path == path) return;
    Track t;
    Item it{path, {}, {}, {}};
    if (m_lib->find(path, t)) it = {path, t.title, t.artist, t.album};
    p->items.push_back(it);
    p->updated = now();
    changed();
}

void Playlists::removeTrack(const QString &id, const QString &path)
{
    Pl *p = find(id);
    if (!p) return;
    for (int i = 0; i < p->items.size(); ++i)
        if (p->items[i].path == path) { p->items.remove(i); p->updated = now(); changed(); return; }
}

bool Playlists::isShared(const QString &id) const
{
    for (const Pl &p : m_pls) if (p.id == id) return p.shared;
    return false;
}

void Playlists::setShared(const QString &id, bool shared)
{
    Pl *p = find(id);
    if (!p || p->shared == shared) return;
    p->shared = shared;
    p->updated = now();
    changed();
}

QStringList Playlists::paths(const QString &id) const
{
    QStringList out;
    for (const Pl &p : m_pls) if (p.id == id) for (const Item &i : p.items) if (!i.path.isEmpty()) out << i.path;
    return out;
}

QVariantList Playlists::suggest(const QString &query, int limit) const
{
    QVector<std::pair<int, QVariantMap>> hits;
    for (const QVariant &v : list()) {
        const QVariantMap m = v.toMap();
        const int s = Fuzzy::score(query, m.value("name").toString());
        if (s > 0) hits.push_back({s, m});
    }
    std::stable_sort(hits.begin(), hits.end(), [](const auto &a, const auto &b) { return a.first > b.first; });
    QVariantList out;
    for (int i = 0; i < hits.size() && i < limit; ++i) out.push_back(hits[i].second);
    return out;
}

QVariantList Playlists::snapshot() const
{
    QVariantList out;
    for (const Pl &p : m_pls) {
        QVariantList tracks;
        for (const Item &i : p.items) {
            if (i.title.isEmpty()) continue;
            Track t;
            QVariantMap m;
            m["title"] = i.title; m["artist"] = i.artist; m["album"] = i.album;
            m["duration"] = (!i.path.isEmpty() && m_lib->find(i.path, t)) ? t.lengthMs : 0;
            tracks.push_back(m);
        }
        out.push_back(QVariantMap{{"id", p.id}, {"name", p.name}, {"updated", p.updated}, {"shared", p.shared}, {"tracks", tracks}});
    }
    return out;
}

void Playlists::applyRemote(const QString &id, const QString &name, qint64 updatedMs, const QVariantList &tracks, bool shared)
{
    Pl *p = find(id);
    if (!p) { m_pls.push_back(Pl{id, name, updatedMs, {}}); p = &m_pls.last(); }
    p->name = name;
    p->updated = updatedMs;
    p->shared = shared;
    p->items.clear();
    for (const QVariant &v : tracks) {
        const QVariantMap m = v.toMap();
        Item it{{}, m.value("title").toString(), m.value("artist").toString(), m.value("album").toString()};
        Track t;
        if (m_lib->findByMeta(it.title, it.artist, it.album, t)) it.path = t.path;   // empty = song not on this computer
        p->items.push_back(it);
    }
    save();
    ++m_rev;
    emit revisionChanged();
}

QStringList Playlists::takeDeleted()
{
    const QStringList d = m_deleted;
    m_deleted.clear();
    save();
    return d;
}
