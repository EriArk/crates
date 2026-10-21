// SPDX-License-Identifier: GPL-3.0-or-later
#include "Rules.h"
#include "../pong/src/PongRules.h"
#include "../snake-arena/src/SnakeRules.h"
#include "../light-cycles/src/CyclesRules.h"
#include "../falling-blocks/src/BlocksRules.h"
#include "../minesweeper-race/src/MinesRules.h"
#include "../chain-reaction/src/ChainRules.h"
#include "../mini-racing/src/RacingRules.h"
#include "../tanks/src/TanksRules.h"
namespace arcade {
Identity identity(Kind kind) {
    switch(kind){
    case Kind::Pong:return {"pong","Pong","A small court. A good rivalry.","Move up / down. First to 5 points wins.\nAfter 3 minutes, the higher score wins.",kind};
    case Kind::Snake:return {"snake-arena","Snake Arena","A snack. A turn. A narrow escape.","Turn in four directions. Eat fruit to grow.\nAvoid walls and snakes. After 2 minutes, longest wins.",kind};
    case Kind::Cycles:return {"light-cycles","Light Cycles","Make a turn. Leave a wall.","Turn in four directions. Your trail stays behind.\nAvoid every wall and outlast your rival.",kind};
    case Kind::Blocks:return {"falling-blocks","Falling Blocks","Clear a line. Find your rhythm.","Left / right to move, down to fall faster. Rotate and Drop place pieces.\nFirst to 12 lines wins. A full stack loses; 3 minutes breaks ties by lines.",kind,"Rotate","Drop"};
    case Kind::Mines:return {"minesweeper-race","Minesweeper Race","Two fields. The same mystery.","Move the cursor. Open a square or place a Flag. A mine ends your round.\nIdentical fields, safe centre. Clear 69 safe squares first; 3 minutes breaks ties by squares.",kind,"Open","Flag"};
    case Kind::Chain:return {"chain-reaction","Chain Reaction","Find a match. Start a cascade.","Move a two-square cursor and Swap colours. Match 3 in a row.\nRaise adds a row. Cascades send grey blocks; adjacent matches clear them.\nFirst to 600 points wins; a full stack loses. Three-minute limit.",kind,"Swap","Raise"};
    case Kind::Racing:return {"mini-racing","Brick Racing","One road. Two rivals.","Left / right: change lane. Up: accelerate. Down: brake.\nBoost recharges faster behind your rival. Pass them on the shared road!\nCrashes cost time. First to 2000 wins; two-minute limit.",kind,"Boost",{}};
    case Kind::Tanks:return {"tanks","Brick Tanks","Break cover. Find an opening.","Move and aim in four directions. Fire to break bricks or hit your rival.\nSteel stops shots. Respawn shields end when you fire.\nFirst to 3 hits wins; after two minutes, most hits wins.",kind,"Fire",{}};
    }return {};
}
std::unique_ptr<Rules> makeRules(Kind kind) {
    if(kind==Kind::Pong)return std::make_unique<PongRules>();
    if(kind==Kind::Snake)return std::make_unique<SnakeRules>();
    if(kind==Kind::Cycles)return std::make_unique<CyclesRules>();
    if(kind==Kind::Blocks)return std::make_unique<BlocksRules>();
    if(kind==Kind::Mines)return std::make_unique<MinesRules>();
    if(kind==Kind::Chain)return std::make_unique<ChainRules>();
    if(kind==Kind::Racing)return std::make_unique<RacingRules>();
    return std::make_unique<TanksRules>();
}
}
