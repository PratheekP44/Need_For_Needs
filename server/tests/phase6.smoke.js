'use strict';

const http = require('http');

function request(method, path, { token, body } = {}) {
  const payload = body ? JSON.stringify(body) : null;
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 5000,
        path,
        method,
        headers: {
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(data || '{}');
          } catch {
            json = { raw: data };
          }
          resolve({ status: res.statusCode, json });
        });
      },
    );
    req.on('error', reject);
    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}

async function waitForHealth(retries = 30) {
  for (let i = 0; i < retries; i += 1) {
    try {
      const res = await request('GET', '/health');
      if (res.status === 200) {
        return;
      }
    } catch {
      // retry
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error('Server did not become healthy');
}

async function main() {
  await waitForHealth();

  const stamp = Date.now();
  const adminSignup = await request('POST', '/auth/signup', {
    body: {
      name: 'Phase6 Admin2',
      email: `p6.admin.${stamp}@campus.edu`,
      phone: `+9198${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'admin',
    },
  });
  if (adminSignup.status !== 201) {
    throw new Error(`admin signup failed: ${JSON.stringify(adminSignup.json)}`);
  }
  const adminToken = adminSignup.json.data.accessToken;

  const userSignup = await request('POST', '/auth/signup', {
    body: {
      name: 'Phase6 User2',
      email: `p6.user.${stamp}@campus.edu`,
      phone: `+9197${String(stamp).slice(-8)}`,
      password: 'Password1',
      accountType: 'user',
    },
  });
  const userToken = userSignup.json.data.accessToken;

  const created = await request('POST', '/lockers', {
    token: adminToken,
    body: {
      lockerId: `LB-${String(stamp).slice(-6)}`,
      lockerName: 'Library Annex',
      latitude: 12.9716,
      longitude: 77.5946,
      status: 'ACTIVE',
      totalBoxes: 3,
      description: 'Near main library',
    },
  });
  if (created.status !== 201) {
    throw new Error(`create locker failed: ${JSON.stringify(created.json)}`);
  }

  const locker = created.json.data.locker;
  console.log('created_boxes', locker.boxes.length);
  console.log('distanceInMeters', locker.distanceInMeters);
  console.log('first_box', JSON.stringify(locker.boxes[0]));

  const boxId = locker.boxes[0].id;
  const updatedBox = await request('PUT', `/boxes/${boxId}`, {
    token: adminToken,
    body: { status: 'AVAILABLE', isEmpty: false, doorState: 'OPEN' },
  });
  if (updatedBox.status !== 200) {
    throw new Error(`update box failed: ${JSON.stringify(updatedBox.json)}`);
  }
  console.log('updated_box', JSON.stringify(updatedBox.json.data.box));

  const listed = await request('GET', `/lockers?search=Library`, {
    token: userToken,
  });
  console.log('list_ok', listed.status === 200, 'count', listed.json.data.lockers.length);

  const forbidden = await request('POST', '/lockers', {
    token: userToken,
    body: {
      lockerId: `ZZ-${String(stamp).slice(-6)}`,
      lockerName: 'Should Fail',
      latitude: 1,
      longitude: 1,
      totalBoxes: 1,
    },
  });
  console.log('user_create_blocked', forbidden.status);

  const expanded = await request('PUT', `/lockers/${locker.id}`, {
    token: adminToken,
    body: { totalBoxes: 4 },
  });
  console.log('expanded_boxes', expanded.json.data.locker.boxes.length);

  const deleted = await request('DELETE', `/lockers/${locker.id}`, {
    token: adminToken,
  });
  console.log('deleted', deleted.status === 200);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
