using UnityEngine;
namespace UnityEngine
{
    public enum EventType {MouseDown=0,MouseUp=1,MouseMove=2,MouseDrag=3,Repaint=7,Used=12}
    public enum ScaleMode {StretchToFill=0}
    public class Event {public static Event current {get;set;}public EventType type {get;set;}public Vector2 mousePosition {get;set;}public void Use(){}}
    public class GUIStyleState {public Color textColor {set{}}}
    public class GUISkin {public Font font {get{return null;}}}
    public class GUIStyle {public static void SetDefaultFont(Font f){}public GUIStyle(){}public int fontSize {set{}}public bool wordWrap {set{}}public TextAnchor alignment {set{}}public GUIStyleState normal {get{return null;}}}
    public static class GUI {public static GUISkin skin {get{return null;}}public static bool enabled {get;set;}public static Matrix4x4 matrix {get;set;}public static Color color {get;set;}public static Color contentColor {get;set;}public static void Label(Rect r,string s){}public static void Label(Rect r,string s,GUIStyle style){}public static void DrawTexture(Rect r,Texture t){}public static void DrawTexture(Rect r,Texture t,ScaleMode mode,bool alphaBlend,float aspect,Color c,float borderWidth,float radius){} }
}
