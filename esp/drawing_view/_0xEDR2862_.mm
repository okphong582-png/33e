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
    CGPathAddRoundedRect(path, nullptr, rect, radius, radius);
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
        (!isBox && !isHeadRedDot && !isLine && !isHealth && !isDis)) return;

    const Vector3 head = getPositionExt(getHead(pawn));
    if (!ValidPosition(head) || !ValidPosition(hip)) return;
    auto project = [&](Vector3 v) {
        return WorldToScreenLayer(v, matrix, vpWidth, vpHeight, width, height);
    };
    const Vector3 headScreen = project(head);
    if (!ValidPosition(headScreen) || headScreen.z <= 0.001f) return;
    // Head markers and lines do not need ankle transforms or a projected box.
    if (!isBox && !isHealth && !isDis) {
        if (isHeadRedDot && headScreen.x >= 0 && headScreen.x <= width &&
            headScreen.y >= 0 && headScreen.y <= height) {
            CGPathAddEllipseInRect(buffers->boxKnockPath, nullptr,
                CGRectMake(headScreen.x - 3, headScreen.y - 3, 6, 6));
            buffers->boxKnockDirty = true;
        }
        if (isLine) {
            CGMutablePathRef path = knocked ? buffers->lineKnockPath :
                (bot ? buffers->lineBotPath : buffers->linePlayerPath);
            AddLine(path, CGPointMake(width * 0.5f, 48),
                    CGPointMake(headScreen.x, headScreen.y - 4), width, height);
            if (knocked) buffers->lineKnockDirty = true;
            else if (bot) buffers->lineBotDirty = true;
            else buffers->linePlayerDirty = true;
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

    CGMutablePathRef boxPath = knocked ? buffers->boxKnockPath : (bot ? buffers->boxBotPath : buffers->boxPlayerPath);
    if (isBox) {
        if (isBox3D) {
            for (int i = 0; i < 8; ++i) {
                for (int bit = 1; bit <= 4; bit <<= 1) {
                    if (i & bit) continue;
                    const Vector3 a = corners[i], b = corners[i | bit];
                    AddLine(boxPath, CGPointMake(a.x, a.y), CGPointMake(b.x, b.y), width, height);
                }
            }
        } else {
            // Lightly rounded corners remain legible without glow or extra layers.
            AddRoundedRect(boxPath, CGRectMake(minX, minY, boxWidth, boxHeight),
                           std::min(3.0, (double)boxWidth * 0.08));
        }
        if (knocked) buffers->boxKnockDirty = true;
        else if (bot) buffers->boxBotDirty = true;
        else buffers->boxPlayerDirty = true;
    }
    if (isHeadRedDot) {
        const CGFloat radius = std::max(2.0, std::min(4.0, (double)boxHeight * 0.025));
        CGPathAddEllipseInRect(buffers->boxKnockPath, nullptr,
            CGRectMake(headScreen.x - radius, headScreen.y - radius, radius * 2, radius * 2));
        buffers->boxKnockDirty = true;
    }
    if (isLine) {
        CGMutablePathRef linePath = knocked ? buffers->lineKnockPath : (bot ? buffers->lineBotPath : buffers->linePlayerPath);
        const CGPoint end = CGPointMake(headScreen.x, minY - 4);
        AddLine(linePath, CGPointMake(width * 0.5f, 48), end, width, height);
        if (knocked) buffers->lineKnockDirty = true;
        else if (bot) buffers->lineBotDirty = true;
        else buffers->linePlayerDirty = true;
    }
    if (isHealth) {
        const int maxHP = get_MaxHP(pawn);
        if (maxHP > 0) {
            const float ratio = std::max(0.0f, std::min(1.0f, (float)hp / maxHP));
            const CGFloat barX = maxX + 4, barWidth = 3;
            const CGFloat filled = boxHeight * ratio;
            AddRoundedRect(buffers->hpBackgroundPath, CGRectMake(barX - 1, minY - 1, barWidth + 2, boxHeight + 2), 2);
            buffers->hpBackgroundDirty = true;
            if (filled >= 0.5f) {
                CGMutablePathRef fill = ratio > 0.5f ? buffers->hpFillPath :
                    (ratio > 0.25f ? buffers->hpWarningPath : buffers->hpCriticalPath);
                AddRoundedRect(fill, CGRectMake(barX, maxY - filled, barWidth, filled), 1);
                if (ratio > 0.5f) buffers->hpFillDirty = true;
                else if (ratio > 0.25f) buffers->hpWarningDirty = true;
                else buffers->hpCriticalDirty = true;
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
