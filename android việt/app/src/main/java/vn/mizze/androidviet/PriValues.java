package vn.mizze.androidviet;
/** Widths follow Android IRepDataPool calls, rather than the host word size. */
final class PriValues {
    static int width(int index){return index==12||index==21||index==34?1:2;}
    static int decode(int index,byte[] data){int width=width(index);if(data.length<width)throw new IllegalArgumentException("Short PRI value");return (data[0]&255)|(width==2?(data[1]&255)<<8:0);}
    static boolean firing(int value){return value==2;}
}
