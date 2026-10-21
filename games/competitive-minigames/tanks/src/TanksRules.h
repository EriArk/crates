// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <array>
#include <QPoint>
#include <QVector>
namespace arcade {
class TanksRules final:public Rules {
public:
    struct Tank {QPoint pos;int face=1,direction=-1,cooldown=0,shield=30;bool fire=false;};
    struct Bullet {QPoint pos;int direction,owner,life=64;};
    int tick=0,winner=-1;
    std::array<Tank,2> tanks;
    std::array<int,2> scores{};
    QVector<int> cells;
    QVector<Bullet> bullets;
    void reset(quint32 seed) override;
    void input(int p,int d) override;
    void action(int p,int a) override;
    void step() override;
    int bot(int p) const override;
    int botAction(int p) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
    bool clear(QPoint pos) const;
    static QPoint delta(int d);
private:
    void respawn(int p);
};
}
