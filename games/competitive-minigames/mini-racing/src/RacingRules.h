// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <array>
#include <QVector>
namespace arcade {
class RacingRules final:public Rules {
public:
    struct Car {int lane=0,distance=0,direction=-1,repeat=0,crash=0,crashes=0,hitGate=-1,boost=0,lives=3;bool requested=false,passable=false;};
    int tick=0,winner=-1;
    std::array<Car,2> cars;
    QVector<int> course;
    void reset(quint32 seed) override;
    void input(int p,int d) override;
    void action(int p,int a) override;
    void step() override;
    int bot(int p) const override;
    int botAction(int p) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
    bool drafting(int p) const;
};
}
