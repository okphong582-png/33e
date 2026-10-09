package vn.mizze.androidviet;

import org.json.JSONObject;

/** Protocol v4 shared with iOS. All times are milliseconds. */
final class LicensePolicy {
    static final long LEASE_MS = 30_000;
    record Result(long deadline, long expiresAt, String message, boolean needsBinding) {
        boolean valid(long now) { return now >= 0 && now < deadline; }
    }
    static Result denied(String message) { return new Result(0, 0, message, false); }
    static boolean number(Object value) {
        return value instanceof Number && Double.isFinite(((Number)value).doubleValue());
    }
    static Result evaluate(JSONObject record, String deviceHash, long serverTime, long started, long now, boolean allowBinding) {
        if (record == null) return denied("Key không tồn tại hoặc đã bị xóa.");
        Object enabled = record.opt("enabled"), expiry = record.opt("expiresAt"), protocol = record.opt("protocol");
        if (!(enabled instanceof Boolean) || !number(expiry) || !number(protocol) || ((Number)protocol).doubleValue() != 4)
            return denied("Dữ liệu key không hợp lệ. Liên hệ người cấp key.");
        if (!((Boolean)enabled)) return denied("Key đã bị khóa.");
        if (serverTime <= 0 || started < 0 || now < started) return denied("Chưa xác minh được thời gian máy chủ.");
        double remaining = ((Number)expiry).doubleValue() - (serverTime + 1000.0);
        if (remaining <= 0) return denied("Key đã hết hạn.");
        long deadline = started + (long)Math.min(LEASE_MS, remaining);
        if (now >= deadline) return denied("Phiên xác thực đã hết hạn. Vui lòng thử lại.");
        Object lockValue = record.opt("lock");
        if (lockValue != null && lockValue != JSONObject.NULL) {
            if (!(lockValue instanceof JSONObject)) return denied("Dữ liệu khóa key không hợp lệ.");
            JSONObject lock = (JSONObject)lockValue;
            Object until = lock.opt("until"), message = lock.opt("message");
            if (!number(until) || ((Number)until).doubleValue() < 0 || !(message instanceof String) || ((String)message).length() > 500)
                return denied("Dữ liệu khóa key không hợp lệ.");
            if (((Number)until).doubleValue() == 0 || ((Number)until).doubleValue() > serverTime)
                return denied(((String)message).isEmpty() ? "Tài khoản đã bị khóa." : (String)message);
        }
        Object bindingValue = record.opt("binding");
        if (bindingValue == null || bindingValue == JSONObject.NULL)
            return new Result(0, 0, "Key đã được gỡ máy. Vui lòng đăng nhập lại.", allowBinding);
        if (!(bindingValue instanceof JSONObject)) return denied("Dữ liệu khóa máy không hợp lệ.");
        JSONObject binding = (JSONObject)bindingValue;
        Object boundDevice = binding.opt("deviceHash"), version = binding.opt("version"), claimed = binding.opt("claimedAt");
        if (!(boundDevice instanceof String) || !((String)boundDevice).matches("[0-9a-f]{64}") ||
                !number(version) || ((Number)version).doubleValue() != 1 || !number(claimed) || ((Number)claimed).doubleValue() <= 0)
            return denied("Dữ liệu khóa máy không hợp lệ.");
        if (!deviceHash.equals(boundDevice)) return denied("Key này đã được kích hoạt trên máy khác.");
        return new Result(deadline, ((Number)expiry).longValue(), "Đã xác thực.", false);
    }
}
