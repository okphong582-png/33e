package vn.mizze.androidviet;
/** Silent is unsupported: it must never fall back to camera aiming. */
final class AimWritePolicy {
 static boolean normal(boolean head,boolean neck,boolean silent){return !silent&&(head||neck);}
}
