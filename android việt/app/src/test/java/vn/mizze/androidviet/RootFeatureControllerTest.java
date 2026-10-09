package vn.mizze.androidviet;

import org.junit.Test;
import static org.junit.Assert.*;
import java.io.IOException;
import java.util.HashMap;

public class RootFeatureControllerTest {
    static final long ATTR=0x30000;
    static final class Fake implements RootFeatureController.Memory {
        RootFeatureController.Identity id=new RootFeatureController.Identity(22,100,0x100000,0x11000,0x20000,ATTR,0x40000);
        HashMap<Long,Integer> values=new HashMap<>();int writes;boolean failWrite,failRead;int identities;boolean switchBeforeWrite;
        Fake(){values.put(ATTR+0x111,0);values.put(ATTR+0x258,Float.floatToRawIntBits(1));values.put(ATTR+0x3C8,Float.floatToRawIntBits(0));}
        public RootFeatureController.Identity identity(){identities++;if(switchBeforeWrite&&identities>1)return new RootFeatureController.Identity(23,101,0x100000,0x11000,0x20000,ATTR,0x40000);return id;}
        public int read(long a,int n)throws Exception{if(failRead)throw new IOException();return values.get(a);}
        public void write(long a,int n,int v)throws Exception{if(failWrite)throw new IOException();values.put(a,v);writes++;}
        float value(long o){return Float.intBitsToFloat(values.get(ATTR+o));}
    }
    @Test public void appliesThreeFieldsAndRestoresOriginals()throws Exception{
        var c=new RootFeatureController();var m=new Fake();c.update(m,new RootFeatureController.Config(true,true,true,9));
        assertEquals(Integer.valueOf(1),m.values.get(ATTR+0x111));assertEquals(.5f,m.value(0x258),0);assertEquals(9,m.value(0x3C8),0);
        c.update(m,RootFeatureController.Config.off());assertEquals(Integer.valueOf(0),m.values.get(ATTR+0x111));assertEquals(1,m.value(0x258),0);assertEquals(0,m.value(0x3C8),0);assertFalse(c.changed());
    }
    @Test public void repeatedUpdatesDoNotCompoundFireRate()throws Exception{
        var c=new RootFeatureController();var m=new Fake();var cfg=new RootFeatureController.Config(false,true,false,6);
        for(int i=0;i<20;i++)c.update(m,cfg);assertEquals(.5f,m.value(0x258),0);assertEquals(1,m.writes);
    }
    @Test public void failedRestoreIsRetryable()throws Exception{
        var c=new RootFeatureController();var m=new Fake();c.update(m,new RootFeatureController.Config(true,true,false,6));m.failWrite=true;
        try{c.update(m,RootFeatureController.Config.off());fail();}catch(IOException expected){}assertTrue(c.changed());m.failWrite=false;c.update(m,RootFeatureController.Config.off());assertFalse(c.changed());assertEquals(1,m.value(0x258),0);
    }
    @Test public void transientReadFailureKeepsOriginalBaseline()throws Exception{
        var c=new RootFeatureController();var m=new Fake();var cfg=new RootFeatureController.Config(false,true,false,6);c.update(m,cfg);m.failRead=true;
        try{c.update(m,cfg);fail();}catch(IOException expected){}m.failRead=false;c.update(m,cfg);c.update(m,RootFeatureController.Config.off());assertEquals(1,m.value(0x258),0);
    }
    @Test public void refusesWriteWhenContextChanges()throws Exception{
        var c=new RootFeatureController();var m=new Fake();m.switchBeforeWrite=true;
        try{c.update(m,new RootFeatureController.Config(true,false,false,6));fail();}catch(IOException expected){}assertEquals(0,m.writes);
    }
    @Test public void neverRestoresIntoReusedPidOrNewMatch()throws Exception{
        var c=new RootFeatureController();var m=new Fake();c.update(m,new RootFeatureController.Config(false,true,false,6));int before=m.writes;
        m.id=new RootFeatureController.Identity(22,999,0x100000,0x22000,0x20000,ATTR,0x40000);
        c.update(m,RootFeatureController.Config.off());assertEquals(before,m.writes);assertFalse(c.changed());
    }
    @Test public void respectsGameRecalculationOnDisable()throws Exception{
        var c=new RootFeatureController();var m=new Fake();c.update(m,new RootFeatureController.Config(false,true,false,6));m.values.put(ATTR+0x258,Float.floatToRawIntBits(.8f));c.update(m,RootFeatureController.Config.off());assertEquals(.8f,m.value(0x258),0);assertFalse(c.changed());
    }
    @Test public void rejectsInvalidFieldInsteadOfWriting()throws Exception{
        var c=new RootFeatureController();var m=new Fake();m.values.put(ATTR+0x258,Float.floatToRawIntBits(Float.NaN));
        try{c.update(m,new RootFeatureController.Config(false,true,false,6));fail();}catch(IOException expected){}assertEquals(0,m.writes);
    }
    @Test public void failedFirstWriteCannotLoseBaseline()throws Exception{
        var c=new RootFeatureController();var m=new Fake();var cfg=new RootFeatureController.Config(false,true,false,6);m.failWrite=true;
        try{c.update(m,cfg);fail();}catch(IOException expected){}m.failWrite=false;c.update(m,cfg);c.update(m,RootFeatureController.Config.off());assertEquals(1,m.value(0x258),0);
    }
    @Test public void speedClampedAndValueChangeRestoresBaseline()throws Exception{
        assertEquals(30,new RootFeatureController.Config(false,false,true,100).speedValue(),0);assertEquals(6,new RootFeatureController.Config(false,false,true,Float.NaN).speedValue(),0);
        var c=new RootFeatureController();var m=new Fake();c.update(m,new RootFeatureController.Config(false,false,true,7));c.update(m,new RootFeatureController.Config(false,false,true,12));c.update(m,RootFeatureController.Config.off());assertEquals(0,m.value(0x3C8),0);
    }
}
