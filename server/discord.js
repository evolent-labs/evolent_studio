const https = require('https');

const MIME_TYPE = { webp: 'image/webp', png: 'image/png', jpg: 'image/jpeg' };

// Lua's PerformHttpRequest cuts a body at its first zero byte, and every picture has one near the start,
// so the picture goes to Discord from here.
exports('sendToDiscord', (webhook, model, extension, base64, done) => {
  const boundary = `----evolent${Date.now()}`;
  const payload = JSON.stringify({ content: model, allowed_mentions: { parse: [] } });
  const body = Buffer.concat([
    Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="payload_json"\r\nContent-Type: application/json\r\n\r\n` +
        `${payload}\r\n--${boundary}\r\nContent-Disposition: form-data; name="files[0]"; filename="${model}.${extension}"\r\n` +
        `Content-Type: ${MIME_TYPE[extension]}\r\n\r\n`,
    ),
    Buffer.from(base64, 'base64'),
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);

  const request = https.request(
    `${webhook}?wait=true`,
    {
      method: 'POST',
      headers: { 'Content-Type': `multipart/form-data; boundary=${boundary}`, 'Content-Length': body.length },
    },
    (response) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => done(response.statusCode, Buffer.concat(chunks).toString('utf8')));
    },
  );

  request.on('error', (error) => done(0, error.message));
  request.end(body);
});
