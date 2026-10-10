package vn.mizze.androidviet;
import org.json.JSONObject;
import org.junit.Test;
import static org.junit.Assert.*;

public class LicensePolicyTest {
    private static final String DEVICE="a".repeat(64), OTHER="b".repeat(64);
    private JSONObject valid() throws Exception {
        return new JSONObject().put("enabled",true).put("protocol",4).put("expiresAt",2_000_000)
            .put("binding",new JSONObject().put("deviceHash",DEVICE).put("version",1).put("claimedAt",1_000_000));
    }
    private LicensePolicy.Result check(JSONObject r,boolean claim){return LicensePolicy.evaluate(r,DEVICE,1_000_000,100,101,claim);}
    @Test public void validLeaseUsesMonotonicTime() throws Exception {var r=check(valid(),false);assertEquals(30_100,r.deadline());assertTrue(r.valid(30_099));assertFalse(r.valid(30_100));}
    @Test public void expiryCapsLeaseAndIncludesHeaderPrecision() throws Exception {var r=check(valid().put("expiresAt",1_010_000),false);assertEquals(9_100,r.deadline());}
    @Test public void expired() throws Exception {assertFalse(check(valid().put("expiresAt",999_999),true).valid(101));}
    @Test public void deletedKey(){assertFalse(check(null,true).valid(101));}
    @Test public void disabled() throws Exception {assertFalse(check(valid().put("enabled",false),true).valid(101));}
    @Test public void numericEnabledIsRejected() throws Exception {assertFalse(check(valid().put("enabled",1),true).valid(101));}
    @Test public void stringExpiryIsRejected() throws Exception {assertFalse(check(valid().put("expiresAt","2000000"),true).valid(101));}
    @Test public void wrongProtocol() throws Exception {assertFalse(check(valid().put("protocol",3),true).valid(101));}
    @Test public void booleanProtocol() throws Exception {assertFalse(check(valid().put("protocol",true),true).valid(101));}
    @Test public void onlyExplicitLoginMayClaim() throws Exception {JSONObject r=valid();r.remove("binding");assertTrue(check(r,true).needsBinding());assertFalse(check(r,false).needsBinding());assertFalse(check(r,true).valid(101));}
    @Test public void deviceMismatch() throws Exception {JSONObject r=valid();r.getJSONObject("binding").put("deviceHash",OTHER);assertFalse(check(r,true).valid(101));assertFalse(check(r,true).needsBinding());}
    @Test public void malformedBinding() throws Exception {for(Object bad:new Object[]{"wrong",new JSONObject().put("deviceHash",DEVICE).put("version",true).put("claimedAt",1),new JSONObject().put("deviceHash",DEVICE).put("version",1).put("claimedAt",0)})assertFalse(check(valid().put("binding",bad),true).valid(101));}
    @Test public void permanentLockPreservesNotice() throws Exception {var r=check(valid().put("lock",new JSONObject().put("until",0).put("message","Liên hệ admin")),true);assertEquals("Liên hệ admin",r.message());assertFalse(r.valid(101));assertFalse(r.needsBinding());}
    @Test public void timedLock() throws Exception {assertFalse(check(valid().put("lock",new JSONObject().put("until",1_100_000).put("message","Tạm khóa")),false).valid(101));}
    @Test public void expiredLockDoesNotBlock() throws Exception {assertTrue(check(valid().put("lock",new JSONObject().put("until",999_999).put("message","")),false).valid(101));}
    @Test public void lockPreventsNewBinding() throws Exception {JSONObject r=valid();r.remove("binding");r.put("lock",new JSONObject().put("until",0).put("message","Khóa"));assertFalse(check(r,true).needsBinding());}
    @Test public void malformedLock() throws Exception {for(Object bad:new Object[]{"locked",new JSONObject().put("until",true).put("message",""),new JSONObject().put("until",0).put("message",2),new JSONObject().put("until",0).put("message","x".repeat(501))})assertFalse(check(valid().put("lock",bad),true).valid(101));}
    @Test public void missingServerClock() throws Exception {assertFalse(LicensePolicy.evaluate(valid(),DEVICE,0,100,101,true).valid(101));}
    @Test public void slowResponseCannotExtendLease() throws Exception {assertFalse(LicensePolicy.evaluate(valid(),DEVICE,1_000_000,100,30_100,true).valid(30_100));}
    @Test public void clockCannotGoBackwards() throws Exception {assertFalse(LicensePolicy.evaluate(valid(),DEVICE,1_000_000,100,99,true).valid(99));}
    @Test public void noGameFeatureClaimedByAdapter(){assertFalse(new AndroidGameData().canReadPlayers());assertFalse(new AndroidGameData().canApplyGameFeatures());}
}
