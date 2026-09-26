#import "esp.h"
#import "../Core/GameLogic.h"
#import "mahoa.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#include <cmath>
#include <unordered_map>
#include <algorithm>
#include "KabraxHide.h"

// ─── TỐI ƯU HÓA FONT (Tránh khởi tạo lại nhiều lần) ────────
UIFont *VietnameseFontForLayer(CGFloat size) {
    static UIFont *cachedFont = nil;
    if (!cachedFont) {
        UIFont *f = [UIFont fontWithName:KH_NS("GFF-Latin-Bold") size:size];
        if (!f) f = [UIFont systemFontOfSize:size];
        UIFontDescriptor *boldDesc = [f.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
        UIFont *boldFont = [UIFont fontWithDescriptor:boldDesc size:size];
        cachedFont = boldFont ?: [UIFont boldSystemFontOfSize:size];
    }
    return cachedFont;
}

// ─── LÀM MƯỢT TOÀN BỘ BOX (Chống rung lắc & bám dính) ────────
struct SmoothedBox {
    float x, y, w, h;
};
static std::unordered_map<uint64_t, SmoothedBox> gSmoothedBoxes;

static inline CGRect GetSmoothedBox(uint64_t pawn, float tx, float ty, float tw, float th) {
    auto it = gSmoothedBoxes.find(pawn);
    if (it == gSmoothedBoxes.end()) {
        gSmoothedBoxes[pawn] = {tx, ty, tw, th};
        return CGRectMake(tx, ty, tw, th);
    }
    
    float lerp = 0.5f; // Nhận diện tức thì không trễ (Zero Delay)
    it->second.x += (tx - it->second.x) * lerp;
    it->second.y += (ty - it->second.y) * lerp;
    it->second.w += (tw - it->second.w) * lerp;
    it->second.h += (th - it->second.h) * lerp;
    
    return CGRectMake(it->second.x, it->second.y, it->second.w, it->second.h);
}

// ─── HELPER VẼ HÌNH CƠ BẢN (Dùng CGFloat để nét kẻ siêu mượt) ──
static inline void ESPAddLine(CGMutablePathRef path, CGPoint p1, CGPoint p2) {
    if (!path) return;
    CGPathMoveToPoint(path, NULL, p1.x, p1.y);
    CGPathAddLineToPoint(path, NULL, p2.x, p2.y);
}

static inline void ESPAddFullRect(CGMutablePathRef path, CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    if (!path || w < 1.0f || h < 1.0f) return;
    CGPathAddRect(path, NULL, CGRectMake(x, y, w, h));
}

static inline void ESPAddCornerBox(CGMutablePathRef path, CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    if (!path || w < 1.0f || h < 1.0f) return;

    CGFloat cornerW = w * 0.20f; 
    CGFloat cornerH = h * 0.22f; 

    // Top Left
    ESPAddLine(path, CGPointMake(x, y), CGPointMake(x + cornerW, y));
    ESPAddLine(path, CGPointMake(x, y), CGPointMake(x, y + cornerH));
    // Top Right
    ESPAddLine(path, CGPointMake(x + w, y), CGPointMake(x + w - cornerW, y));
    ESPAddLine(path, CGPointMake(x + w, y), CGPointMake(x + w, y + cornerH));
    // Bottom Left
    ESPAddLine(path, CGPointMake(x, y + h), CGPointMake(x + cornerW, y + h));
    ESPAddLine(path, CGPointMake(x, y + h), CGPointMake(x, y + h - cornerH));
    // Bottom Right
    ESPAddLine(path, CGPointMake(x + w, y + h), CGPointMake(x + w - cornerW, y + h));
    ESPAddLine(path, CGPointMake(x + w, y + h), CGPointMake(x + w, y + h - cornerH));
}

BOOL RenderFOVCirclePath(CGMutablePathRef path, float viewWidth, float viewHeight, BOOL aimbotEnabled, float fovRadius) {
    if (!path || !aimbotEnabled || fovRadius <= 0 || viewWidth < 10 || viewHeight < 10) return NO;
    float cx = viewWidth / 2.0f;
    float cy = viewHeight / 2.0f;
    float d  = fovRadius * 2.0f;
    CGPathAddEllipseInRect(path, NULL, CGRectMake(cx - fovRadius, cy - fovRadius, d, d));
    return YES;
}

// LƯU TRỮ SỐ LƯỢNG KẺ ĐỊCH HIỆN TẠI TRONG TRẬN
static int gEnemyCountThisFrame = 0;

// Gọi hàm này tại đầu vòng lặp Render chính của bạn (trước khi lặp qua danh sách Pawn) để reset bộ đếm
void ESPBeginFrame() {
    gEnemyCountThisFrame = 0;
}

// Gọi hàm này ở cuối vòng lặp chính để hiển thị số lượng địch lên trên màn hình (ESP COUNT)
void ESPEndFrame(ESPAddTextCallback textCallback, void *callbackContext, float viewWidth) {
    if (!textCallback || gEnemyCountThisFrame <= 0) return;
    
    @autoreleasepool {
        char countBuf[32];
        snprintf(countBuf, sizeof(countBuf), KH_STR("ENEMIES: %d"), gEnemyCountThisFrame);
        NSString *countStr = [NSString stringWithUTF8String:countBuf];
        
        // Đặt ở vị trí trung tâm phía trên cùng màn hình
        CGFloat textW = (CGFloat)(countStr.length * 7.0f);
        CGFloat textH = 16.0f;
        CGFloat textX = (viewWidth / 2.0f) - (textW / 2.0f);
        CGFloat textY = 25.0f; // Cách tai thỏ/đỉnh màn hình một khoảng an toàn
        
        textCallback(callbackContext, countStr, CGRectMake(textX, textY, textW, textH), [UIColor redColor], 12.0f, YES);
    }
}

// ─── HÀM RENDER ESP CHÍNH (SIÊU TỐI ƯU HÓA FPS) ───────────
void _0x35572DA(
    ESPGeometryBuffers *buffers,
    ESPAddTextCallback textCallback,
    void *callbackContext,
    uint64_t PawnObject,
    int CurHP,
    float dis,
    float *matrix,
    float layerWidth,
    float layerHeight,
    float matrixVpWidth,
    float matrixVpHeight
) {
    // 1. [TỐI ƯU SỚM] Loại bỏ mục tiêu ngoài tầm 150m hoặc con trỏ lỗi ngay lập tức
    if (dis > 150.0f || !buffers || !matrix || !PawnObject || !isVaildPtr(PawnObject)) return;

    Vector3 pos = getPositionExt(getRoot(PawnObject)); 

    if(pos.x == 0 && pos.y == 0 && pos.z == 0) return; 

    // 2. KIỂM TRA MỤC TIÊU TRONG GÓC NHÌN ĐỂ CẮT GIẢM TÍNH TOÁN
    



Vector3 HeadTop = pos; HeadTop.y += 1.5f; 

Vector3 RightToePos = pos; RightToePos.y -= 0.0f; 




    Vector3 w2sHead = WorldToScreenLayer(HeadTop, matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight); 
    if (w2sHead.z < 0.001f) return; // Địch ở sau lưng -> Bỏ qua toàn bộ đọc ghi

    Vector3 w2sToe = WorldToScreenLayer(RightToePos, matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight); 
    if (w2sToe.z < 0.001f) return; 

    const float margin = layerWidth * 0.2f;
    if (w2sHead.x < -margin || w2sHead.x > layerWidth + margin || 
        w2sHead.y < -margin || w2sHead.y > layerHeight + margin) return; 

    bool isKnocked = get_IsKnockedDown(PawnObject);
    if (CurHP <= 0 && !isKnocked) return; 
    
    BOOL isBot = get_IsBot(PawnObject);
    
    // Tăng biến đếm số lượng địch hiển thị trong frame này
    gEnemyCountThisFrame++;

/*
    // Kích thước Box
    float rawBoxHeight = fabsf(w2sHead.y - w2sToe.y); 
    float rawBoxWidth = rawBoxHeight * 0.40f; 
    
    float rawX = w2sHead.x - (rawBoxWidth * 0.5f); 
    float rawY = w2sHead.y; 

    // Áp dụng bộ lọc làm mượt CG-Float
    CGRect finalBox = GetSmoothedBox(PawnObject, rawX, rawY, rawBoxWidth, rawBoxHeight);
    CGFloat x = (CGFloat)finalBox.origin.x;
    CGFloat y = (CGFloat)finalBox.origin.y;
    CGFloat boxWidth = (CGFloat)finalBox.size.width;
    CGFloat boxHeight = (CGFloat)finalBox.size.height;
*/

float boxHeight = fabsf(w2sHead.y - w2sToe.y); //if (rawBoxHeight < 12.0f) rawBoxHeight = 12.0f; 

//float boxHeight = SmoothedBoxHeight(PawnObject, rawBoxHeight); 

//boxHeight = roundf(boxHeight / 2.0f) * 2.0f; 

float boxWidth = boxHeight * 0.5f; 

//boxWidth = roundf(boxWidth);

//float x = roundf(headX - boxWidth * 0.5f); 

//float y = roundf(headY); 


float x = w2sHead.x - boxWidth * 0.5f;

float y = w2sHead.y;

    // ─── VẼ BỘ PHẬN ĐẦU MÀU ĐỎ (HEAD RED DOT ESP) ───────────────
    uint64_t headNode = getHead(PawnObject);
    if (isVaildPtr(headNode)) {
        Vector3 headPos = getPositionExt(headNode);
        if (!IsZeroVec(headPos)) {
            Vector3 w2sDot = WorldToScreenLayer(headPos, matrix, matrixVpWidth, matrixVpHeight, layerWidth, layerHeight);
            if (w2sDot.z > 0.001f) {
                // Vẽ Chấm Đỏ Hình Tròn Trực Tiếp Trên Đầu Người Chơi
                CGPathAddArc(buffers->boxKnockPath, NULL, (CGFloat)w2sDot.x, (CGFloat)w2sDot.y, 5.5f, 0, M_PI * 2, YES);
                buffers->boxKnockDirty = true;
            }
        }
    }

    // ─── SNAPLINE ──────────────────────────────────────────────
    if (isLine) {
        CGPoint lineStart = CGPointMake((CGFloat)layerWidth / 2.0f, 20.0f);
        CGPoint enemyCenterTop = CGPointMake(x + (boxWidth * 0.5f), y);

        if(isKnocked) {
            ESPAddLine(buffers->lineKnockPath, lineStart, enemyCenterTop);
            buffers->lineKnockDirty = true;
        } else if (isBot) {
            ESPAddLine(buffers->lineBotPath, lineStart, enemyCenterTop);
            buffers->lineBotDirty = true;
        } else {
            ESPAddLine(buffers->linePlayerPath, lineStart, enemyCenterTop);
            buffers->linePlayerDirty = true;
        }
    }

    // ─── BOX ───────────────────────────────────────────────────
    if (isBox) {
        
            if(isKnocked) { ESPAddFullRect(buffers->boxKnockPath, x, y, boxWidth, boxHeight); buffers->boxKnockDirty = true; }
            else if (isBot) { ESPAddFullRect(buffers->boxBotPath, x, y, boxWidth, boxHeight); buffers->boxBotDirty = true; }
            else { ESPAddFullRect(buffers->boxPlayerPath, x, y, boxWidth, boxHeight); buffers->boxPlayerDirty = true; }
        } 
    

    // ─── HEALTH BAR (BÊN PHẢI BOX) ──────────────────────────────
    if (isHealth) {
        int MaxHP = get_MaxHP(PawnObject);
        if (MaxHP > 0) {
            float healthRatio = (float)CurHP / (float)MaxHP;
            healthRatio = fmaxf(0.0f, fminf(healthRatio, 1.0f)); 

            const CGFloat barWidth = 3.0f;
            // DỊCH TOẠ ĐỘ SANG PHẢI: Tọa độ X của box + chiều rộng của box + 2px khoảng cách
            CGFloat barX      = x + boxWidth + 2.0f; 
            CGFloat filledH   = boxHeight * (CGFloat)healthRatio;
            CGFloat filledTop = (y + boxHeight) - filledH;

            CGPathAddRect(buffers->hpBackgroundPath, NULL, CGRectMake(barX - 0.5f, y - 0.5f, barWidth + 1.0f, boxHeight + 1.0f));
            buffers->hpBackgroundDirty = true;

            if (filledH > 0.5f) {
                CGPathAddRect(buffers->hpFillPath, NULL, CGRectMake(barX, filledTop, barWidth, filledH));
                buffers->hpFillDirty = true;
            }
        }
    }

    // ─── TEXT RENDER (ĐÃ LOẠI BỎ TÊN & MÁU ĐỂ TỐI ƯU FPS) ───────
    if (textCallback) {
        @autoreleasepool { 
            const CGFloat kNameLineH = 12.0f;
            const CGFloat kDistY     = y + boxHeight + 3.0f; // Khoảng cách cách đáy Box 3px

            // In Khoảng Cách (Meter) phía dưới chân Box
            if (isDis) {
                char distBuf[16];
                snprintf(distBuf, sizeof(distBuf), KH_STR("[%dM]"), (int)dis);
                NSString *distString = [NSString stringWithUTF8String:distBuf];
                
                CGFloat distWidth = (CGFloat)(distString.length * 5.5f);
                CGFloat distX = (x + boxWidth * 0.5f) - (distWidth * 0.5f); // Căn giữa
                
                textCallback(callbackContext, distString, CGRectMake(distX, kDistY, distWidth, kNameLineH), [UIColor whiteColor], 9.0f, YES);
            }
        } 
    }
}