#pragma once
#include <QString>
#include <algorithm>
#include <utility>
#include <vector>

namespace Fuzzy {

inline int distance(const QString &a, const QString &b)
{
    std::vector<int> prev(b.size() + 1), cur(b.size() + 1);
    for (int j = 0; j <= b.size(); ++j) prev[j] = j;
    for (int i = 1; i <= a.size(); ++i) {
        cur[0] = i;
        for (int j = 1; j <= b.size(); ++j)
            cur[j] = std::min({prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)});
        std::swap(prev, cur);
    }
    return prev[b.size()];
}

// 0 = no match, higher = better. Handles substrings, missing letters ("rbl" finds "rebel") and typos ("rebl", "reble").
inline int score(const QString &query, const QString &text)
{
    const QString a = query.trimmed().toLower(), b = text.toLower();
    if (a.isEmpty()) return 1;
    if (b == a) return 1000;
    if (b.startsWith(a)) return 900 - std::min(90, int(b.size() - a.size()));
    if (b.contains(a)) return 800 - std::min(90, int(b.size() - a.size()));
    int pos = 0, hits = 0;
    for (const QChar c : a) { pos = int(b.indexOf(c, pos)); if (pos < 0) break; ++pos; ++hits; }
    if (hits == a.size() && a.size() >= 2) return 600 - std::min(150, int(b.size() - a.size()));
    const int allow = a.size() <= 3 ? 0 : (a.size() <= 6 ? 1 : 2);
    if (allow > 0) {
        int best = distance(a, b.left(a.size()));
        for (const QString &w : b.split(' ', Qt::SkipEmptyParts)) {
            best = std::min(best, distance(a, w));
            best = std::min(best, distance(a, w.left(a.size())));
        }
        if (best <= allow) return 400 - best * 60;
    }
    return 0;
}

} // namespace Fuzzy
