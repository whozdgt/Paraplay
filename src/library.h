#pragma once
#include <QAbstractListModel>
#include <QFutureWatcher>
#include <QHash>
#include <QVariantList>
#include <QVector>
#include <memory>

#include "types.h"

class Library : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QString filterKind READ filterKind NOTIFY filterChanged)
    Q_PROPERTY(QString filterName READ filterName NOTIFY filterChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY searchChanged)
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)   // "" = all, "local", or a server id
public:
    enum Roles { PathRole = Qt::UserRole + 1, TitleRole, ArtistRole, AlbumRole, DurationRole, BadgeRole, HiresRole, TrackNoRole, RemoteRole };

    struct Snapshot {
        std::shared_ptr<const QVector<Track>> tracks;
        QVector<int> order;   // indices into tracks, in the order currently shown
    };

    explicit Library(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int revision() const { return m_revision; }
    bool scanning() const { return m_scanning; }
    QString filterKind() const { return m_filterKind; }
    QString filterName() const { return m_filterName; }
    QString sortMode() const { return m_sortMode; }
    void setSortMode(const QString &m);
    QString search() const { return m_search; }
    void setSearch(const QString &s);
    QString source() const { return m_source; }
    void setSource(const QString &s);
    // Songs from a media server replace whatever that server had before. Empty list = forget the server.
    void setRemoteTracks(const QString &serverId, QVector<Track> tracks);
    bool find(const QString &path, Track &out) const;
    bool findByMeta(const QString &title, const QString &artist, const QString &album, Track &out) const;
    // Finds your own copy of a song someone else described (title, artist, album, length). Ignores case,
    // punctuation and "(Remastered)"-style brackets, and prefers local files, then lossless ones.
    bool matchLoose(const QString &title, const QString &artist, const QString &album, int durationMs, Track &out) const;
    QStringList artistsOf(const Track &t) const;
    Snapshot snapshot() const { return {m_all, m_view}; }

    Q_INVOKABLE void scan(const QString &dir);
    Q_INVOKABLE void setFilter(const QString &kind, const QString &key, const QString &label = QString());
    Q_INVOKABLE void setSplitOptions(bool commaAmp, const QString &exceptions);
    Q_INVOKABLE void setPlaylistFilter(const QString &id, const QString &name, const QStringList &paths);
    Q_INVOKABLE QVariantList suggest(const QString &kind, const QString &query, int limit) const;
    Q_INVOKABLE void clearFilter();
    Q_INVOKABLE QVariantList groups(const QString &kind) const;

signals:
    void revisionChanged();
    void scanningChanged();
    void filterChanged();
    void sortModeChanged();
    void searchChanged();
    void sourceChanged();

private:
    void onScanDone();
    void rebuildView();
    void loadCache();
    void saveCache() const;
    bool inSource(const Track &t) const;

    std::shared_ptr<const QVector<Track>> m_all;
    mutable std::shared_ptr<const QVector<Track>> m_matchBase;   // the list m_matchIndex was built from
    mutable QHash<QString, QVector<int>> m_matchIndex;           // simplified title -> rows in m_all
    QVector<int> m_view;
    QString m_filterKind, m_filterKey, m_filterName, m_pendingDir, m_sortMode = QStringLiteral("az");
    QStringList m_exceptions, m_filterPaths;
    QString m_search, m_source;
    bool m_splitCommaAmp = true;
    int m_revision = 0;
    bool m_scanning = false;
    QFutureWatcher<QVector<Track>> m_watcher;
};
