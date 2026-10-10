package vn.mizze.androidviet;

/** Claims each backend once per menu session; manual OFF is never overwritten by later frames. */
final class FeatureAutoStart {
    private int applied;
    synchronized String[] claim(int ready){int fresh=(ready&7)&~applied;applied|=fresh;java.util.ArrayList<String> keys=new java.util.ArrayList<>();
        if((fresh&1)!=0)java.util.Collections.addAll(keys,"ShootNoReload","FastFire","RunSpeed");
        if((fresh&2)!=0)java.util.Collections.addAll(keys,"ESPEnabled","CleanESP","Name","Health","Line","TracerLine","Box","Skeleton","HeadRedDot","Dis","ShowFov","AimTargetLine");
        if((fresh&4)!=0)java.util.Collections.addAll(keys,"AimHead","AimbotFire");
        return keys.toArray(new String[0]);
    }
}
