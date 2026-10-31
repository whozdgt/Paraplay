#pragma once
#include <QImage>
#include <QQuickImageProvider>

#include "types.h"

// Embedded art first, then cover/folder/front/album image next to the file. Null image if none.
QImage loadCover(const QString &path, const QSize &target);
// "image://cover/<base64url(path)>"
QString coverUrl(const QString &path);
// Same, but also understands songs on a media server ("image://remote/<server>/<base64url(cover id)>").
QString coverUrl(const Track &t);

class CoverProvider : public QQuickImageProvider {
public:
    CoverProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
