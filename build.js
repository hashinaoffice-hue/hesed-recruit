// Claude 없이 쓰는 웹사이트용 묶음(docs/, GitHub Pages가 그대로 올림)을 만든다.
// cloud.json 의 Supabase 주소와 공개(anon) 키를 페이지에 넣고, 글꼴과 사진을 함께 복사한다.
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const OUT = path.join(ROOT, 'docs');
const cfgFile = path.join(ROOT, 'cloud.json');
if (!fs.existsSync(cfgFile)) { console.error('cloud.json 이 없어요. {"url": "...", "key": "..."} 형식으로 만들어 주세요.'); process.exit(1); }
const cfg = JSON.parse(fs.readFileSync(cfgFile, 'utf8'));

const head = '<!doctype html><html lang="ko"><head><meta charset="utf-8">'
  + '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
  + '<meta name="robots" content="noindex">'
  + '<style>:root{color-scheme:light;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0;font:14px system-ui,sans-serif}img{max-width:100%}[hidden]{display:none!important}</style>'
  + `<script>window.HESED_CLOUD=${JSON.stringify({url: cfg.url, key: cfg.key})}</script>`
  + '</head><body>';

fs.rmSync(OUT, {recursive: true, force: true});
fs.mkdirSync(OUT, {recursive: true});
fs.writeFileSync(path.join(OUT, 'index.html'), head + fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8') + '</body></html>');
for (const dir of ['fonts', 'img']) fs.cpSync(path.join(ROOT, dir), path.join(OUT, dir), {recursive: true});
fs.writeFileSync(path.join(OUT, '.nojekyll'), '');
console.log('docs/ 준비 완료');
