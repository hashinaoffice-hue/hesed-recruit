// 로컬 미리보기 서버: Artifact 게시 때 붙는 문서 뼈대를 흉내 내서 index.html을 감싼다.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const PORT = Number(process.env.PORT) || 4210;
const TYPES = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.jpg': 'image/jpeg', '.png': 'image/png', '.woff2': 'font/woff2'};
const HEAD = '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;font:14px system-ui,sans-serif}img{max-width:100%}[hidden]{display:none!important}</style></head><body>';

http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/' || url === '/index.html') {
    res.writeHead(200, {'Content-Type': TYPES['.html'], 'Cache-Control': 'no-store'});
    return res.end(HEAD + fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8') + '</body></html>');
  }
  // /cloud 는 공용 저장소(Supabase)에 연결한 웹사이트 모드로 연다
  if (url === '/cloud') {
    const cfgFile = path.join(ROOT, 'cloud.json');
    const cfg = fs.existsSync(cfgFile) ? fs.readFileSync(cfgFile, 'utf8') : 'null';
    res.writeHead(200, {'Content-Type': TYPES['.html'], 'Cache-Control': 'no-store'});
    return res.end(HEAD + `<script>window.HESED_CLOUD=${cfg}</script>` + fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8') + '</body></html>');
  }
  const file = path.join(ROOT, url);
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); return res.end('not found'); }
  res.writeHead(200, {'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream'});
  fs.createReadStream(file).pipe(res);
}).listen(PORT, () => console.log('hesed-recruit on http://localhost:' + PORT));
