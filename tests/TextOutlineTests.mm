#import "../esp/esp/MizzeTextOutline.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <initializer_list>
#import <QuartzCore/QuartzCore.h>
static CGPathRef reference(NSString *s,CTFontRef font,CGRect frame){
 if(s.length>48)s=[s substringToIndex:48];CFIndex n=s.length;UniChar chars[48];CGGlyph glyphs[48]={};CGSize widths[48]={};
 [s getCharacters:chars range:NSMakeRange(0,n)];
 if(!CTFontGetGlyphsForCharacters(font,chars,glyphs,n))for(CFIndex i=0;i<n;i++)CTFontGetGlyphsForCharacters(font,chars+i,glyphs+i,1);
 double width=CTFontGetAdvancesForGlyphs(font,kCTFontOrientationHorizontal,glyphs,widths,n);
 double x=frame.origin.x+(frame.size.width-width)/2;
 double y=frame.origin.y+(frame.size.height+CTFontGetAscent(font)+CTFontGetDescent(font))/2-CTFontGetDescent(font);
 CGMutablePathRef path=CGPathCreateMutable();
 for(CFIndex i=0;i<n;i++){CGAffineTransform m=CGAffineTransformMake(1,0,0,-1,x,y);CGPathRef g=glyphs[i]?CTFontCreatePathForGlyph(font,glyphs[i],&m):NULL;if(g){CGPathAddPath(path,NULL,g);CGPathRelease(g);}x+=widths[i].width;}return path;
}
int main(){@autoreleasepool{
 int failures=0;setbuf(stdout,NULL);
 for(double size: {3.87,5.5,8.25,12.0}){
 CTFontRef font=CTFontCreateWithName(CFSTR("Helvetica-Bold"),size,NULL);
 for(NSString *text in @[@"Mizze",@"[123M]",@"Người chơi",@"A😀B",@"012345678901234567890123456789012345678901234567890123456789"]){
 for(int i=0;i<4;i++){
 CGRect frame=CGRectMake(i*12.5,i*23.25,90,20);CGPathRef a=reference(text,font,frame);CGMutablePathRef b=CGPathCreateMutable();MizzeAppendTextOutline(b,text,font,frame);
 CGRect x=CGPathGetBoundingBox(a),y=CGPathGetBoundingBox(b);
 if(!(fabs(x.origin.x-y.origin.x)<.00001&&fabs(x.origin.y-y.origin.y)<.00001&&fabs(x.size.width-y.size.width)<.00001&&fabs(x.size.height-y.size.height)<.00001)){
   printf("GEOMETRY size=%.8f text=%s iteration=%d old=(%.8f,%.8f,%.8f,%.8f) cached=(%.8f,%.8f,%.8f,%.8f)\n",size,text.UTF8String,i,x.origin.x,x.origin.y,x.size.width,x.size.height,y.origin.x,y.origin.y,y.size.width,y.size.height);failures++;
 }
 CGPathRelease(a);CGPathRelease(b);
 }}CFRelease(font);}
 assert(failures==0);
 CTFontRef font=CTFontCreateWithName(CFSTR("Helvetica-Bold"),8,NULL);CGRect frame=CGRectMake(10,20,90,20);
 double start=CACurrentMediaTime();for(int i=0;i<3000;i++){CGPathRef p=reference(@"MizzePlayer123",font,frame);CGPathRelease(p);}double oldTime=CACurrentMediaTime()-start;
 start=CACurrentMediaTime();for(int i=0;i<3000;i++){CGMutablePathRef p=CGPathCreateMutable();MizzeAppendTextOutline(p,@"MizzePlayer123",font,frame);CGPathRelease(p);}double newTime=CACurrentMediaTime()-start;CFRelease(font);
 printf("PASS: cached geometry, positions, sizes, Unicode and truncation; 3000 labels reference=%.4fs cached=%.4fs\n",oldTime,newTime);
}return 0;}
