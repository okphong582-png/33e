using UnityEngine;
namespace UnityEngine
{
    public enum EventType {MouseDown=0,MouseUp=1,MouseMove=2,MouseDrag=3,Repaint=7,Used=12}
    public enum ScaleMode {StretchToFill=0}
    public class Event {public static Event current {get;set;}public EventType type {get;set;}public Vector2 mousePosition {get;set;}public void Use(){}}
    public static class GUI {public static Matrix4x4 matrix {get;set;}public static Color color {get;set;}public static void Label(Rect r,string s){}public static void DrawTexture(Rect r,Texture t){}public static void DrawTexture(Rect r,Texture t,ScaleMode mode,bool alphaBlend,float aspect,Color c,float borderWidth,float radius){} }
}
