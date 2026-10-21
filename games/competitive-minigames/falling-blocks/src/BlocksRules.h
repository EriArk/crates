// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "PuzzleRules.h"
#include <QPoint>
namespace arcade {
class BlocksRules final:public PuzzleRules {
public:
    struct Player {QVector<int> cells=QVector<int>(160);int type=0,rotation=0,x=3,y=0,next=0,fall=0;quint32 rng=1;};
    std::array<Player,2> players;
    void reset(quint32 seed) override;
    int bot(int p) const override;
    int botAction(int p) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
    static QVector<QPoint> shape(int type,int rotation);
    bool fits(const Player& p,int x,int y,int rotation) const;
private:
    void move(int p,int d) override;
    void act(int p,int a) override;
    void advance() override;
    int target() const override{return 12;}
    void spawn(int p);
    void lock(int p);
    std::pair<int,int> plan(int p) const;
};
}
