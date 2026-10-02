#import "esp.h"
#import "ESPPrefs.h"
#include "OverlayGeometry.h"
#include "KabraxHide.h"
#include <algorithm>
#include <cmath>
#include <limits>

UIFont *VietnameseFontForLayer(CGFloat size) {
    return [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
}

static bool ValidPosition(const Vector3 &v) {
    return std::isfinite(v.x) && std::isfinite(v.y) && std::isfinite(v.z) &&
           (v.x != 0 || v.y != 0 || v.z != 0);
}
static void AddLine(CGMutablePathRef path, CGPoint a, CGPoint b, float width, float height) {
    if (!path) return;
    double x0 = a.x, y0 = a.y, x1 = b.x, y1 = b.y;
    if (!OverlayGeometry::ClipSegment(x0, y0, x1, y1, width, height)) return;
    CGPathMoveToPoint(path, nullptr, x0, y0);
    CGPathAddLineToPoint(path, nullptr, x1, y1);
}
static void AddRoundedRect(CGMutablePathRef path, CGRect rect, CGFloat radius) {
    if (!path || rect.size.width <= 0 || rect.size.height <= 0) return;
    CGPathAddRoundedRect(path, nullptr, rect, radius, radius);
}

// Tính clip-space thuần (x_c, y_c, w_c) từ VP matrix (column-major 4x4)
// Không chia w — giữ nguyên dấu để phát hiện behind-camera (w_c < 0)
static void WorldToClip(const Vector3 &world, const float *m,
                        float &xc, float &yc, float &wc) {
    xc = m[0]*world.x + m[4]*world.y + m[8]*world.z  + m[12];
    yc = m[1]*world.x + m[5]*world.y + m[9]*world.z  + m[13];
    wc = m[3]*world.x + m[7]*world.y + m[11]*world.z + m[15];
}

// Chiếu line từ tâm màn hình ra mép theo hướng (dirX,dirY) screen-space
static CGPoint ClipToEdge(CGFloat ox, CGFloat oy,
                          CGFloat dirX, CGFloat dirY,
                          CGFloat w,   CGFloat h) {
    if (dirX == 0 && dirY == 0) return CGPointMake(ox, oy);
    const CGFloat margin = 14.0f;
    CGFloat t = std::numeric_limits<CGFloat>::max();
    if (dirX > 0) t = std::min(t, (w - margin - ox) / dirX);
    else if (dirX < 0) t = std::min(t, (margin - ox) / dirX);
    if (dirY > 0) t = std::min(t, (h - margin - oy) / dirY);
    else if (dirY < 0) t = std::min(t, (margin - oy) / dirY);
    if (t <= 0 || !std::isfinite(t)) return CGPointMake(ox, oy);
    return CGPointMake(ox + dirX * t, oy + dirY * t);
}

// Snapline: KHÔNG dùng lerp — lerp gây dây trôi xuống đất khi địch biến mất
// Endpoint được tính trực tiếp mỗi frame → mượt tự nhiên, không delay
static inline CGPoint SmoothedEndpoint(uint64_t /*pawn*/, CGPoint target) {
    return target; // instant, không cache
}



static void AddSkeleton(ESPGeometryBuffers *buffers, uint64_t pawn,
                        const Vector3 &head, const Vector3 &hip, float *matrix,
                        float width, float height, float vpWidth, float vpHeight) {
    if (!isBone || !buffers->bonePath) return;
    // One bounded set of joint reads and one shared path for all players.
    // Reuse the existing per-frame transform cache; no per-joint UI layers.
    using Reader = uint64_t (*)(uint64_t);
    const Reader readers[] = {getLeftShoulder, getRightShoulder,
        getLeftElbow, getRightElbow, getLeftHand, getRightHand,
        getLeftAnkle, getRightAnkle, getLeftToeNode, getRightToeNode};
    Vector3 world[13] = {head, hip};
    Vector3 screen[13]{};
    bool valid[13]{};
    for (int i = 0; i < 10; ++i) world[i + 2] = getPositionExt(readers[i](pawn));
    // No verified neck/spine/knee nodes were supplied. Use the shoulder
    // midpoint for the torso and direct hip-to-ankle segments for the legs.
    for (int i = 0; i < 12; ++i)
        valid[i] = ValidPosition(world[i]) && Vector3::Distance(world[i], hip) <= 3.0f;
    if (valid[2] && valid[3]) {
        world[12] = (world[2] + world[3]) * 0.5f;
        valid[12] = true;
    }
    for (int i = 0; i < 13; ++i) {
        if (!valid[i]) continue;
        screen[i] = WorldToScreenLayer(world[i], matrix, vpWidth, vpHeight, width, height);
        valid[i] = ValidPosition(screen[i]) && screen[i].z > 0.001f;
    }
    const int edges[][2] = {{0,12}, {12,1}, {2,3}, {2,4}, {4,6},
        {3,5}, {5,7}, {1,8}, {1,9}, {8,10}, {9,11}};
    for (const auto &edge : edges) {
        const int a = edge[0], b = edge[1];
        if (!valid[a] || !valid[b]) continue;
        AddLine(buffers->bonePath, CGPointMake(screen[a].x, screen[a].y),
                CGPointMake(screen[b].x, screen[b].y), width, height);
        buffers->boneDirty = true;
    }
}

BOOL RenderFOVCirclePath(CGMutablePathRef path, float w, float h, BOOL enabled, float radius) {
    if (!path || !enabled || radius <= 0 || w <= 0 || h <= 0) return NO;
    CGPathAddEllipseInRect(path, nullptr, CGRectMake(w / 2 - radius, h / 2 - radius, radius * 2, radius * 2));
    return YES;
}

void _0x35572DA(ESPGeometryBuffers *buffers, ESPAddTextCallback textCallback,
               void *context, uint64_t pawn, int hp, float distance, const Vector3 &hip,
               bool knocked, bool bot, float *matrix,
               float width, float height, float vpWidth, float vpHeight) {
    if (!buffers || !matrix || !isVaildPtr(pawn) || hp <= 0 ||
        !std::isfinite(distance) || distance > 150 || width <= 0 || height <= 0 ||
        (!isBox && !isBone && !isHeadRedDot && !isLine && !isHealth && !isDis && !isName)) return;

    const Vector3 head = getPositionExt(getHead(pawn));
    if (!ValidPosition(head) || !ValidPosition(hip)) return;
    auto project = [&](Vector3 v) {
        return WorldToScreenLayer(v, matrix, vpWidth, vpHeight, width, height);
    };
    const Vector3 headScreen = project(head);
    const bool headOnScreen  = ValidPosition(headScreen) && headScreen.z > 0.001f &&
                               headScreen.x >= 0 && headScreen.x <= width &&
                               headScreen.y >= 0 && headScreen.y <= height;
    const bool headInFront   = ValidPosition(headScreen) && headScreen.z > 0.001f;

    // --- Snapline: luôn vẽ, kể cả khi địch sau lưng ---
    if (isLine) {
        CGMutablePathRef linePath = knocked
            ? buffers->lineKnockPath
            : (bot ? buffers->lineBotPath : buffers->linePlayerPath);
        if (linePath) {
            const CGFloat cx = width * 0.5f;
            const CGFloat cy = 40.0f;
            CGPoint rawEnd;
            bool drawLine = false;

            if (headInFront) {
                // Địch phía trước: line đến đầu
                rawEnd   = CGPointMake(headScreen.x, headScreen.y - 4);
                drawLine = true;
            } else {
                // Địch sau lưng: dùng clip-space thật
                float xc, yc, wc;
                WorldToClip(head, matrix, xc, yc, wc);
                if (std::isfinite(xc) && std::isfinite(yc) && std::isfinite(wc) && wc != 0) {
                    const CGFloat ndx =  (CGFloat)(xc / wc);
                    const CGFloat ndy = -(CGFloat)(yc / wc);
                    rawEnd   = ClipToEdge(cx, cy, ndx * width, ndy * height, width, height);
                    drawLine = true;
                }
            }

            if (drawLine) {
                // Lerp endpoint để line không giật khi xoay 360°
                CGPoint endPt = SmoothedEndpoint(pawn, rawEnd);
                AddLine(linePath, CGPointMake(cx, cy), endPt, width, height);
                if (knocked) buffers->lineKnockDirty = true;
                else if (bot) buffers->lineBotDirty  = true;
                else          buffers->linePlayerDirty = true;
            }
        }
    }

    // Phần còn lại chỉ vẽ khi đầu địch thực sự trong FOV
    if (!headInFront) return;

    AddSkeleton(buffers, pawn, head, hip, matrix, width, height, vpWidth, vpHeight);
    if (!isBox && !isHealth && !isDis && !isName) {
        if (isHeadRedDot && headOnScreen && buffers->boxKnockPath) {
            CGPathAddEllipseInRect(buffers->boxKnockPath, nullptr,
                CGRectMake(headScreen.x - 3, headScreen.y - 3, 6, 6));
            buffers->boxKnockDirty = true;
        }
        return;
    }
    const Vector3 left = getPositionExt(getLeftAnkle(pawn));
    const Vector3 right = getPositionExt(getRightAnkle(pawn));
    Vector3 feet = hip;
    feet.y -= 0.85f;
    if (ValidPosition(left) && ValidPosition(right)) feet = (left + right) * 0.5f;
    else if (ValidPosition(left)) feet = left;
    else if (ValidPosition(right)) feet = right;
    feet.y -= 0.08f;

    // Project all eight world-space corners, rather than offsetting a 2D rectangle.
    const float lowY = std::min(feet.y, head.y - 0.20f);
    const float highY = std::max(head.y + 0.18f, lowY + 0.35f);
    const float halfWidth = knocked ? 0.48f : 0.30f;
    const float halfDepth = knocked ? 0.48f : 0.23f;
    Vector3 corners[8];
    CGFloat minX = std::numeric_limits<CGFloat>::infinity();
    CGFloat minY = minX, maxX = -minX, maxY = -minX;
    for (int i = 0; i < 8; ++i) {
        Vector3 world(hip.x + ((i & 1) ? halfWidth : -halfWidth),
                      (i & 2) ? highY : lowY,
                      hip.z + ((i & 4) ? halfDepth : -halfDepth));
        corners[i] = project(world);
        if (!ValidPosition(corners[i]) || corners[i].z <= 0.001f) return;
        minX = std::min(minX, (CGFloat)corners[i].x);
        minY = std::min(minY, (CGFloat)corners[i].y);
        maxX = std::max(maxX, (CGFloat)corners[i].x);
        maxY = std::max(maxY, (CGFloat)corners[i].y);
    }
    if (maxX < 0 || minX > width || maxY < 0 || minY > height) return;
    const CGFloat boxHeight = maxY - minY;
    const CGFloat boxWidth = maxX - minX;
    if (!std::isfinite(boxHeight) || !std::isfinite(boxWidth) ||
        boxHeight < 2 || boxHeight > height * 3 || boxWidth < 1 || boxWidth > width * 3) return;

    // Render Player Name above head
    if (isName && textCallback) {
        NSString *nick = GetNickName(pawn);
        if (!nick || nick.length == 0) {
            nick = bot ? @"[BOT]" : @"Player";
        }
        UIColor *nameColor = knocked ? [UIColor colorWithRed:1.0f green:0.25f blue:0.3f alpha:1.0f]
                                      : (bot ? [UIColor colorWithRed:1.0f green:0.84f blue:0.0f alpha:1.0f]
                                             : [UIColor colorWithRed:0.2f green:0.9f blue:1.0f alpha:1.0f]);
        textCallback(context, nick, CGRectMake((minX + maxX) / 2.0f - 60.0f, minY - 18.0f, 120.0f, 14.0f),
                     nameColor, 10.0f, NO);
    }

    CGMutablePathRef boxPath = knocked ? buffers->boxKnockPath : (bot ? buffers->boxBotPath : buffers->boxPlayerPath);
    if (isBox && boxPath) {
        if (isBox3D) {
            for (int i = 0; i < 8; ++i) {
                for (int bit = 1; bit <= 4; bit <<= 1) {
                    if (i & bit) continue;
                    const Vector3 a = corners[i], b = corners[i | bit];
                    AddLine(boxPath, CGPointMake(a.x, a.y), CGPointMake(b.x, b.y), width, height);
                }
            }
        } else {
            AddRoundedRect(boxPath, CGRectMake(minX, minY, boxWidth, boxHeight),
                           std::min(3.0, (double)boxWidth * 0.08));
        }
        if (knocked) buffers->boxKnockDirty = true;
        else if (bot) buffers->boxBotDirty = true;
        else buffers->boxPlayerDirty = true;
    }
    if (isHeadRedDot && buffers->boxKnockPath) {
        const CGFloat radius = std::max(2.0, std::min(4.0, (double)boxHeight * 0.025));
        CGPathAddEllipseInRect(buffers->boxKnockPath, nullptr,
            CGRectMake(headScreen.x - radius, headScreen.y - radius, radius * 2, radius * 2));
        buffers->boxKnockDirty = true;
    }
    if (isLine) {
        CGMutablePathRef linePath = knocked
            ? buffers->lineKnockPath
            : (bot ? buffers->lineBotPath : buffers->linePlayerPath);
        if (linePath) {
            // Line đã vẽ ở trên (kể cả off-screen), chỉ mark dirty nếu chưa
            if (!knocked && !bot && !buffers->linePlayerDirty) buffers->linePlayerDirty = true;
            else if (bot && !buffers->lineBotDirty) buffers->lineBotDirty = true;
            else if (knocked && !buffers->lineKnockDirty) buffers->lineKnockDirty = true;
        }
    }
    if (isHealth && buffers->hpBackgroundPath) {
        const int maxHP = get_MaxHP(pawn);
        if (maxHP > 0) {
            const float ratio = std::max(0.0f, std::min(1.0f, (float)hp / maxHP));
            const CGFloat barX = maxX + 4, barWidth = 3.5f;
            const CGFloat filled = boxHeight * ratio;
            AddRoundedRect(buffers->hpBackgroundPath, CGRectMake(barX - 1, minY - 1, barWidth + 2, boxHeight + 2), 2.0f);
            buffers->hpBackgroundDirty = true;
            if (filled >= 0.5f) {
                CGMutablePathRef fill = ratio > 0.5f ? buffers->hpFillPath :
                    (ratio > 0.25f ? buffers->hpWarningPath : buffers->hpCriticalPath);
                if (fill) {
                    AddRoundedRect(fill, CGRectMake(barX, maxY - filled, barWidth, filled), 1.5f);
                    if (ratio > 0.5f) buffers->hpFillDirty = true;
                    else if (ratio > 0.25f) buffers->hpWarningDirty = true;
                    else buffers->hpCriticalDirty = true;
                }
            }
        }
    }
    if (isDis && textCallback) {
        static NSArray<NSString *> *labels;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSMutableArray<NSString *> *items = [NSMutableArray arrayWithCapacity:151];
            for (int meters = 0; meters <= 150; ++meters)
                [items addObject:[NSString stringWithFormat:@"%dm", meters]];
            labels = [items copy];
        });
        NSString *label = labels[std::max(0, std::min(150, (int)distance))];
        textCallback(context, label, CGRectMake((minX + maxX) / 2 - 28, maxY + 4, 56, 14),
                     UIColor.whiteColor, 10, NO);
    }
}
