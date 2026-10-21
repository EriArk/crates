// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <memory>

namespace arcade {
enum class Kind { Pong, Snake, Cycles, Blocks, Mines, Chain };
struct Identity { QString id, title, subtitle, instructions; Kind kind; QString primary, secondary; };
Identity identity(Kind kind);
// Directions: -1 neutral, 0 up, 1 right, 2 down, 3 left.
class Rules {
public:
    virtual ~Rules() = default;
    virtual void reset(quint32 seed) = 0;
    virtual void input(int player, int direction) = 0;
    virtual void step() = 0;
    virtual int bot(int player) const = 0;
    virtual void action(int, int) {}
    virtual int botAction(int) const { return -1; }
    virtual QJsonObject view() const = 0;
    virtual bool validView(const QJsonObject& state) const = 0;
};
std::unique_ptr<Rules> makeRules(Kind kind);
inline bool integer(const QJsonValue& v, int low, int high) {
    return v.isDouble() && v.toDouble() == v.toInt(low-1) && v.toInt() >= low && v.toInt() <= high;
}
inline bool baseView(const QJsonObject& s) {
    return integer(s["tick"],0,1000000) && integer(s["winner"],-1,2);
}
inline quint32 random(quint32& seed) {
    if(!seed) seed=1;
    seed ^= seed<<13; seed ^= seed>>17; seed ^= seed<<5; return seed;
}
}
