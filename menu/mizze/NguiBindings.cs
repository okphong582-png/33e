using UnityEngine;
public class UIRect:Component {}
public class UIWidget:UIRect {public bool fillGeometry;public int width {get{return 0;}set{}}public int height {get{return 0;}set{}}public int depth {get{return 0;}set{}}}
public class UIPanel:UIRect {public int depth {get{return 0;}set{}}}
public class UICamera:Component {public static Camera mainCamera {get{return null;}}}
