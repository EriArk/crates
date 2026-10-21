// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <QPoint>
#include <QVector>
#include <array>
namespace arcade {
class SnakeRules final : public Rules {
public:
    static constexpr int W=24,H=16;
    int tick=0,winner=-1,food=0;
    quint32 seed=1;
    std::array<QVector<int>,2> body;
    std::array<int,2> direction{1,3},pending{1,3};
    void reset(quint32 value) override;
    void input(int player,int dir) override;
    void step() override;
    int bot(int player) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
    int next(int cell,int dir) const;
private:
    void spawnFood();
};
}
