using UnityEngine;
namespace UnityEngine {public class Collider:Component {public bool enabled {get;set;}}
    public class BoxCollider:Collider {public Vector3 size {get;set;}}
    public class SphereCollider:Collider {public float radius {get;set;}}}
