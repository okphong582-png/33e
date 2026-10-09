package vn.mizze.androidviet;
import android.os.SystemClock;
/** Bounded auxiliary writes; every pulse revalidates live target/trigger/identity and lease. */
final class AimPulse {
 interface Action {void run()throws Exception;}
 private record Pending(long deadline,Action update,Action restore){}
 private static volatile Pending pending;private static Thread worker;
 static synchronized void publish(long deadline,Action update,Action restore){
  pending=new Pending(deadline,update,restore);
  if(worker==null){worker=new Thread(()->{try{while(!Thread.currentThread().isInterrupted()){
   synchronized(AimPulse.class){Pending p=pending;if(p!=null){try{if(SystemClock.elapsedRealtime()<p.deadline())p.update().run();else clear();}catch(Exception e){clear();}}}
   Thread.sleep(4);
  }}catch(InterruptedException e){Thread.currentThread().interrupt();}},"auxiliary-aim");worker.setDaemon(true);worker.start();}
 }
 static synchronized void clear(){Pending p=pending;pending=null;if(p!=null)try{p.restore().run();}catch(Exception ignored){}}
 static synchronized void stop(){clear();if(worker!=null){worker.interrupt();worker=null;}}
}
