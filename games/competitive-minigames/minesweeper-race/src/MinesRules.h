// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "PuzzleRules.h"
namespace arcade {
class MinesRules final:public PuzzleRules {
public:
    QVector<int> mines=QVector<int>(81),numbers=QVector<int>(81);
    std::array<QVector<int>,2> visible;
    std::array<int,2> cursor{40,40};
    void reset(quint32 seed) override;
    int bot(int p) const override;
    int botAction(int p) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
    static QVector<int> neighbors(int cell);
private:
    void move(int p,int d) override;
    void act(int p,int a) override;
    void advance() override{}
    int target() const override{return 69;}
    void reveal(int p,int cell);
    std::pair<int,int> choice(int p) const;
};
}
