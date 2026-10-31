#pragma once
#include <QNetworkAccessManager>
#include <QObject>
#include <QPair>
#include <QQueue>
#include <QSet>

// Artist pictures: your own photo wins, then a cached online picture (Deezer's public search),
// otherwise nothing (the UI shows a blank-user glyph).
class ArtistImages : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
public:
    explicit ArtistImages(QObject *parent = nullptr);
    int revision() const { return m_rev; }
    void setOnline(bool on) { m_online = on; }

    Q_INVOKABLE QString url(const QString &name);
    Q_INVOKABLE void setCustom(const QString &name, const QString &source);
    Q_INVOKABLE void clearCustom(const QString &name);

signals:
    void revisionChanged();

private:
    QString keyFor(const QString &name) const;
    void pump();
    void markNone(const QString &k);
    void finishJob();

    QNetworkAccessManager m_net;
    QQueue<QPair<QString, QString>> m_queue;
    QSet<QString> m_queued;
    QString m_customDir, m_cacheDir;
    bool m_online = true, m_busy = false;
    int m_rev = 0;
};
