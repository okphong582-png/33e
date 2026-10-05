#pragma once
#define MODES_PAGE 0x4000
#define MODES_POST_ENTRY 16
#define MODES_ORIGINAL 0
#define MODES_CLOCK 8
#define MODES_CURRENT_MATCH 16
#define MODES_GET_POS 24
#define MODES_SET_POS 32
#define MODES_HP 40
#define MODES_VEHICLE 48
#define MODES_PARACHUTE 56
#define MODES_WAIT_SYNC 64
#define MODES_SEQUENCE 72
#define MODES_FLAGS 76
#define MODES_DEADLINE 80
#define MODES_MATCH 88
#define MODES_LOCAL 96
#define MODES_EPOCH 104
#define MODES_COUNT 108
#define MODES_HEIGHT 112
#define MODES_PLAYERS 120
#define MODES_FLY_CCT 632
#define MODES_FLY_CLASS 640
#define MODES_BUSY 648
#define MODES_TICKS 656
#define MODES_APPLIES 664
#define MODES_RESTORES 672
#define MODES_MAGIC 680
#define MODES_POST_ORIGINAL 696
#define MODES_POST_TICKS 704
#define MODES_FORCE_POS 712
#define MODES_ROWS 720
#define MODES_CAPACITY 64
#define MODES_ROW_SIZE 64
#define ROW_PLAYER 0
#define ROW_MATCH 8
#define ROW_LOCAL 16
#define ROW_EPOCH 24
#define ROW_MODE 28
#define ROW_REAL 32
#define ROW_ID 44
#define ROW_SHOWN 48
#ifndef __ASSEMBLER__
#include <cstddef>
#include <cstdint>
namespace PlayerModesRemote {
constexpr uint64_t Magic = 0x504c4d4f44453036ULL;
struct Row {
    uint64_t player=0, match=0, local=0;
    uint32_t epoch=0, mode=0;
    float real[3]={}; uint32_t identity=0;
    float shown[3]={}; uint32_t pad2=0;
};
struct Input {
    uint32_t flags=0;
    uint64_t deadline=0, match=0, local=0;
    uint32_t epoch=0, count=0;
    float height=3.0f; uint32_t reserved=0;
    uint64_t players[MODES_CAPACITY]={};
    uint64_t flyCCT=0, flyClass=0;
} __attribute__((packed));
struct State {
    uint64_t original=0, clock=0, currentMatch=0, getPos=0, setPos=0, hp=0;
    uint64_t vehicle=0, parachute=0, waitSync=0;
    uint32_t sequence=0;
    Input input;
    uint32_t busy=0, pad=0;
    uint64_t ticks=0, applies=0, restores=0, magic=Magic, pad2=0;
    uint64_t originalPost=0, postTicks=0;
    uint64_t forcePos=0;
    Row rows[MODES_CAPACITY];
};
static_assert(offsetof(State, input)==MODES_FLAGS);
static_assert(offsetof(State, input)+offsetof(Input, players)==MODES_PLAYERS);
static_assert(offsetof(State, input)+offsetof(Input, height)==MODES_HEIGHT);
static_assert(offsetof(State, input)+offsetof(Input, flyCCT)==MODES_FLY_CCT);
static_assert(offsetof(State, forcePos)==MODES_FORCE_POS);
static_assert(offsetof(State, busy)==MODES_BUSY);
static_assert(offsetof(State, ticks)==MODES_TICKS);
static_assert(offsetof(State, applies)==MODES_APPLIES);
static_assert(offsetof(State, restores)==MODES_RESTORES);
static_assert(offsetof(State, magic)==MODES_MAGIC);
static_assert(offsetof(State, originalPost)==MODES_POST_ORIGINAL);
static_assert(offsetof(State, postTicks)==MODES_POST_TICKS);
static_assert(offsetof(State, rows)==MODES_ROWS);
static_assert(sizeof(Row)==MODES_ROW_SIZE);
static_assert(offsetof(Row, real)==ROW_REAL && offsetof(Row, shown)==ROW_SHOWN);
static_assert(offsetof(Row, identity)==ROW_ID);
static_assert(sizeof(State)<MODES_PAGE);
}
#endif
