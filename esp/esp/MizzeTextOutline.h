#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

// Main render thread. Cache only font-local geometry; positions stay live.
void MizzeAppendTextOutline(CGMutablePathRef destination, NSString *text,
                           CTFontRef font, CGRect frame);
