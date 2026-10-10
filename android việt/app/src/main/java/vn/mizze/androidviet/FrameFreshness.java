package vn.mizze.androidviet;
final class FrameFreshness {
    static boolean accepts(long sample,long now,long frameEpoch,long viewportEpoch,int frameWidth,int frameHeight,int width,int height){
        return sample>0&&sample<=now&&now-sample<250&&frameEpoch==viewportEpoch
            &&(width==0||frameWidth==width)&&(height==0||frameHeight==height);
    }
}
