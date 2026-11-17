namespace UnityEngine
{
    // Compile-time declarations. These are not embedded as a managed assembly.
    public class Object
    {
        public static void DontDestroyOnLoad(Object obj) { }
    }

    public class GameObject : Object
    {
        public GameObject(string name) { }
    }
}
