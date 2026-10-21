// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <array>
namespace arcade {
class CyclesRules final : public Rules {
public:
    static constexpr int W=28,H=18;
    int tick=0,winner=-1;
    std::array<int,W*H> cells{};
    std::array<int,2> head{},direction{1,3},pending{1,3};
    void reset(quint32 value) override;
    void input(int player,int dir) override;
    void step() override;
    int bot(int player) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
    int next(int cell,int dir) const;
};
}
