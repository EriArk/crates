// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <array>
namespace arcade {
class PongRules final : public Rules {
public:
    int tick=0,winner=-1,x=480,y=270,vx=7,vy=3,serve=30;
    std::array<int,2> paddles{270,270},directions{-1,-1},scores{0,0};
    quint32 seed=1;
    void reset(quint32 value) override;
    void input(int player,int direction) override;
    void step() override;
    int bot(int player) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
};
}
