// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "PuzzleRules.h"
namespace arcade {
class ChainRules final:public PuzzleRules {
public:
    struct Player {QVector<int> cells=QVector<int>(72),flash;int cursor=57,delay=0,chain=0,raise=0,incoming=0,grace=0;quint32 rng=1;};
    std::array<Player,2> players;
    void reset(quint32 seed) override;
    int bot(int p) const override;
    int botAction(int p) const override;
    QJsonObject view() const override;
    bool validView(const QJsonObject&) const override;
    static QVector<int> matches(const QVector<int>& cells);
private:
    void move(int p,int d) override;
    void act(int p,int a) override;
    void advance() override;
    int target() const override{return 600;}
    void row(int p,bool garbage);
    static void gravity(QVector<int>& cells);
    std::pair<int,int> choice(int p) const;
};
}
