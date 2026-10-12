namespace SimpleJSON
{
    public enum JSONNodeType {Array=1,Object=2,String=3,Number=4,NullValue=5,Boolean=6,None=7,Custom=255}
    public class JSONNode
    {
        public JSONNode this[string key] {get{return null;}}
        public JSONNodeType Tag {get{return JSONNodeType.None;}}public bool IsObject {get{return false;}}
        public bool IsNull {get{return true;}}public bool IsBoolean {get{return false;}}public bool IsNumber {get{return false;}}public bool IsString {get{return false;}}
        public bool AsBool {get{return false;}}public double AsDouble {get{return 0;}}public int AsInt {get{return 0;}}public string Value {get{return "";}}
        public static JSONNode Parse(string json){return null;}
    }
}
