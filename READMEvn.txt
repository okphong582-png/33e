addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

// ⚙️ Cấu hình – thay secret bằng giá trị thật
const SECRET_KEY = 'MyAdminSecret123';      // Dùng để vào trang admin tạo tài khoản
const APP_USER_AGENT = 'PubgModVip/';       // Phải khớp với app gửi lên

// UUID hợp lệ – nên dùng biến môi trường env.VALID_UUID để dễ thay đổi từ xa
// Nếu không có biến môi trường, dùng giá trị mặc định (có thể hardcode)
const VALID_UUID = typeof VALID_UUID !== 'undefined' ? VALID_UUID : '90EE2980-87D6-3864-B3B1-9012008AB6AA';

async function handleRequest(request) {
  const url = new URL(request.url);
  const userAgent = request.headers.get('User-Agent') || '';

  // Nếu không phải từ app (User-Agent không chứa chuỗi PubgModVip/) → trả 404
  if (!userAgent.includes(APP_USER_AGENT)) {
    // Ngoại lệ: cho phép truy cập trang admin với đúng secret key
    if (url.pathname === '/admin' && url.searchParams.get('key') === SECRET_KEY) {
      return serveAdminPage();
    }
    return new Response('Not Found', { status: 404 });
  }

  // ========== CÁC ROUTE CHO APP ==========
  if (url.pathname === '/auth' && request.method === 'POST') {
    return handleAuth(request);
  } else if (url.pathname === '/create-account' && request.method === 'POST') {
    return handleCreateAccount(request);
  } else if (url.pathname === '/uuid' && request.method === 'GET') {
    return handleUUID();
  } else {
    return new Response('Not Found', { status: 404 });
  }
}

// Xác thực đăng nhập
async function handleAuth(request) {
  try {
    const { account, password, udid } = await request.json();
    if (!account || !password || !udid) {
      return json({ success: false });
    }

    const accountKey = `account:${account}`;
    const accountData = await ACCOUNT_DATA.get(accountKey);
    if (!accountData) {
      return json({ success: false });
    }

    const data = JSON.parse(accountData);
    if (data.password !== password) {
      return json({ success: false });
    }

    // Kiểm tra UDID: nếu đã gán UDID khác → từ chối
    if (data.udid && data.udid !== udid) {
      return json({ success: false, message: 'UDID mismatch' });
    }

    // Lưu UDID nếu lần đầu
    if (!data.udid) {
      data.udid = udid;
      await ACCOUNT_DATA.put(accountKey, JSON.stringify(data));
    }

    // Hạn VIP
    const now = Date.now();
    const expiry = data.expiry ? new Date(data.expiry).getTime() : 0;
    if (expiry && now > expiry) {
      return json({ success: false, message: 'Expired' });
    }

    const remainingHours = Math.max(0, (expiry - now) / 3600000);
    return json({ success: true, vip_hours: Math.floor(remainingHours) });
  } catch (e) {
    return json({ success: false });
  }
}

// Tạo tài khoản mới (chỉ dùng khi có secret)
async function handleCreateAccount(request) {
  try {
const { secret, account, password, hours } = await request.json();
    if (secret !== SECRET_KEY) {
      return new Response(JSON.stringify({ success: false, message: 'Unauthorized' }), { status: 401 });
    }
    if (!account || !password) {
      return json({ success: false, message: 'Missing fields' });
    }

    const accountKey = `account:${account}`;
    const existing = await ACCOUNT_DATA.get(accountKey);
    if (existing) {
      return json({ success: false, message: 'Account already exists' });
    }

    const expiryDate = new Date(Date.now() + (hours || 9999) * 3600000).toISOString();
    const newAccount = {
      password: password,
      udid: null,
      expiry: expiryDate
    };
    await ACCOUNT_DATA.put(accountKey, JSON.stringify(newAccount));

    return json({ success: true, message: 'Account created', expiry: expiryDate });
  } catch (e) {
    return json({ success: false, message: 'Server error' });
  }
}

// 🆕 Xử lý GET /uuid – trả về UUID hợp lệ
function handleUUID() {
  // Lấy từ biến môi trường (env.VALID_UUID) – nếu dùng Cloudflare, truyền vào env
  // Ở đây ta dùng global VALID_UUID (đã định nghĩa ở đầu file)
  const uuid = VALID_UUID;
  if (!uuid) {
    return new Response('UUID not configured', { status: 500 });
  }
  return new Response(uuid, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' }
  });
}

// Trang admin tạo tài khoản (giao diện web)
function serveAdminPage() {
  const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Quản lý tài khoản PubgModVip</title>
  <style>body { font-family: sans-serif; margin: 2em; } input, button { margin: 0.5em 0; }</style>
</head>
<body>
  <h2>Tạo tài khoản mới</h2>
  <input id="account" placeholder="Tài khoản"><br>
  <input id="password" type="password" placeholder="Mật khẩu"><br>
  <input id="hours" type="number" value="9999" placeholder="Giờ VIP"><br>
  <button onclick="create()">Tạo</button>
  <p id="msg"></p>
  <script>
    async function create() {
      const secret = '${SECRET_KEY}';
      const account = document.getElementById('account').value;
      const password = document.getElementById('password').value;
      const hours = parseInt(document.getElementById('hours').value) || 9999;
      const res = await fetch('/create-account', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'User-Agent': 'PubgModVip/1.0' },
        body: JSON.stringify({ secret, account, password, hours })
      });
      const data = await res.json();
      document.getElementById('msg').innerText = JSON.stringify(data);
    }
  </script>
</body>
</html>`;
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

function json(obj) {
  return new Response(JSON.stringify(obj), { headers: { 'Content-Type': 'application/json' } });
}
