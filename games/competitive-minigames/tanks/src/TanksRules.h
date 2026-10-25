// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <QPoint>
#include <QVector>
namespace arcade {
class TanksRules final:public Rules {
public:
    static constexpr int Width=61,Height=45,MaxPlayers=16;
    enum Tile {Ground,Brick,Steel,Water,Bush};
    struct Tank {QPoint pos;int face=1,direction=-1,cooldown=0,shield=30;bool fire=false;};
    struct Bullet {QPoint pos;int direction,owner,life=64;};
    int tick=0,winner=-1;
    QVector<Tank> tanks;
    QVector<int> scores;
    QVector<int> cells;
    QVector<Bullet> bullets;
    void reset(quint32 seed) override;
    void reset(quint32 seed,int players);
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
    QVector<QPoint> spawns_;
    mutable QVector<int> botTick_,botDirection_;
    void respawn(int p);
};
}
