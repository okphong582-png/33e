#import "MizzeTextOutline.h"
#include <cmath>

@interface MizzeTextOutline : NSObject
@property(nonatomic, assign) CGPathRef path;
@property(nonatomic, assign) double width;
@property(nonatomic, assign) double ascent;
@property(nonatomic, assign) double descent;
@end
@implementation MizzeTextOutline
- (void)dealloc { if (_path) CGPathRelease(_path); }
@end

void MizzeAppendTextOutline(CGMutablePathRef dst, NSString *text,
                           CTFontRef font, CGRect frame) {
    if (!dst || !font || !text.length || CGRectIsEmpty(frame)) return;
    enum { kMaxGlyphs = 48 };
    if (text.length > kMaxGlyphs) text = [text substringToIndex:kMaxGlyphs];
    static NSCache<NSString *, MizzeTextOutline *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        cache.countLimit = 512;
        cache.totalCostLimit = 2 * 1024 * 1024;
    });
    NSString *fontName = CFBridgingRelease(CTFontCopyPostScriptName(font));
    NSString *key = [NSString stringWithFormat:@"%@\x1f%.17g\x1f%@",
                     fontName, (double)CTFontGetSize(font), text];
    MizzeTextOutline *outline = [cache objectForKey:key];
    if (!outline) {
        const CFIndex count = text.length;
        UniChar chars[kMaxGlyphs];
        CGGlyph glyphs[kMaxGlyphs] = {};
        CGSize advances[kMaxGlyphs] = {};
        [text getCharacters:chars range:NSMakeRange(0, count)];
        if (!CTFontGetGlyphsForCharacters(font, chars, glyphs, count)) {
            for (CFIndex i = 0; i < count; ++i) {
                glyphs[i] = 0;
                CTFontGetGlyphsForCharacters(font, chars + i, glyphs + i, 1);
            }
        }
        double width = CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal,
                                                glyphs, advances, count);
        if (!std::isfinite(width) || width <= 0) return;
        CGMutablePathRef path = CGPathCreateMutable();
        double pen = 0;
        for (CFIndex i = 0; i < count; ++i) {
            CGAffineTransform placement = CGAffineTransformMakeTranslation(pen, 0);
            CGPathRef glyph = glyphs[i] ? CTFontCreatePathForGlyph(font, glyphs[i], &placement) : NULL;
            if (glyph) { CGPathAddPath(path, NULL, glyph); CGPathRelease(glyph); }
            pen += advances[i].width;
        }
        outline = [MizzeTextOutline new];
        outline.path = path;
        outline.width = width;
        outline.ascent = CTFontGetAscent(font);
        outline.descent = CTFontGetDescent(font);
        [cache setObject:outline forKey:key cost:(NSUInteger)count * 1024];
    }
    const double dx = frame.origin.x + (frame.size.width - outline.width) * 0.5;
    const double dy = frame.origin.y + (frame.size.height + outline.ascent + outline.descent) * 0.5 - outline.descent;
    CGAffineTransform placement = CGAffineTransformMake(1, 0, 0, -1, dx, dy);
    CGPathAddPath(dst, &placement, outline.path);
}
