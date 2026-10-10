namespace SimpleJSON
{
    public class JSONNode
    {
        public JSONNode this[string key] {get{return null;}}
        public bool IsNull {get{return true;}}public bool IsBoolean {get{return false;}}public bool IsNumber {get{return false;}}public bool IsString {get{return false;}}
        public bool AsBool {get{return false;}}public double AsDouble {get{return 0;}}public int AsInt {get{return 0;}}public string Value {get{return "";}}
        public static JSONNode Parse(string json){return null;}
    }
}
