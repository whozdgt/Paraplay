#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>

// Lets the app browse folders itself (the "Choose folder" box). A phone has no file dialog that hands back a plain
// folder path, and a path is what the library scan needs.
class FolderBrowser : public QObject {
    Q_OBJECT
public:
    explicit FolderBrowser(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE QVariantList roots() const;                  // places to start from: [{name, path}]
    Q_INVOKABLE QVariantList list(const QString &dir) const; // folders inside dir: [{name, path}]
    Q_INVOKABLE QString parent(const QString &dir) const;    // "" when dir is one of the starting places
    Q_INVOKABLE bool isDir(const QString &dir) const;
    Q_INVOKABLE int audioCount(const QString &dir) const;    // songs directly inside dir
};
