#pragma once
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVector>

class Library;

// Playlists, saved as JSON per profile (guest = playlists.json, signed in = playlists-<id>.json).
class Playlists : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
public:
    explicit Playlists(Library *lib, QObject *parent = nullptr);
    int revision() const { return m_rev; }

    Q_INVOKABLE QVariantList list() const;
    Q_INVOKABLE QString create(const QString &name);
    Q_INVOKABLE QString createWith(const QString &name, const QStringList &paths);   // new playlist holding these songs
    Q_INVOKABLE void rename(const QString &id, const QString &name);
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void addTrack(const QString &id, const QString &path);
    Q_INVOKABLE void removeTrack(const QString &id, const QString &path);
    Q_INVOKABLE bool isShared(const QString &id) const;
    Q_INVOKABLE void setShared(const QString &id, bool shared);      // shown on your public profile
    Q_INVOKABLE QStringList paths(const QString &id) const;
    Q_INVOKABLE QVariantList suggest(const QString &query, int limit) const;

    // used by sign-in / sync
    QVariantList snapshot() const;
    void applyRemote(const QString &id, const QString &name, qint64 updatedMs, const QVariantList &tracks, bool shared = false);
    QStringList takeDeleted();
    void useProfile(const QString &id);

signals:
    void revisionChanged();

private:
    void reresolve();      // find local songs for playlist entries that arrived before the music was scanned
    struct Item { QString path, title, artist, album; };
    struct Pl { QString id, name; qint64 updated = 0; QVector<Item> items; bool shared = false; };
    Pl *find(const QString &id);
    QString filePath(const QString &profile) const;
    void load();
    void save();
    void changed() { save(); ++m_rev; emit revisionChanged(); }

    Library *m_lib;
    QVector<Pl> m_pls;
    QStringList m_deleted;
    QString m_profile;
    int m_rev = 0;
};
