#!/usr/bin/env node
// Rukhmini - hpo film-streaming server
// The clever elephant thief serves your movies across the network
// Usage: node rukhmini-server.js <video-dir> <port>

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');
const CFG_DIR = path.join(os.homedir(), '.config', 'hpo');
let OMDB_KEY = '';
try { OMDB_KEY = fs.readFileSync(path.join(CFG_DIR,'omdb_key.txt'),'utf8').trim(); } catch(e){}
let posterCache = {};
try { posterCache = JSON.parse(fs.readFileSync(path.join(CFG_DIR,'rukhmini_posters.json'),'utf8')); } catch(e){}
let titleMap = {};
try { titleMap = JSON.parse(fs.readFileSync(path.join(CFG_DIR,'rukhmini_titles.json'),'utf8')); } catch(e){}
function saveCache(){ try { fs.mkdirSync(CFG_DIR,{recursive:true}); fs.writeFileSync(path.join(CFG_DIR,'rukhmini_posters.json'), JSON.stringify(posterCache,null,2)); } catch(e){} }
function fileToTitle(rel){
  let base = path.basename(rel, path.extname(rel));
  if (titleMap[base]) return titleMap[base];
  return base.replace(/[_.]/g,' ').replace(/([a-zA-Z])(\d)/g,'$1 $2').replace(/\b(19|20)\d{2}\b/g,'').replace(/\b(1080p|720p|2160p|4k|bluray|bd|web|x264|x265|hevc)\b/gi,'').replace(/\s+/g,' ').trim().toLowerCase().replace(/\b\w/g,c=>c.toUpperCase());
}
function fetchPoster(title){
  return new Promise((resolve)=>{
    if(!OMDB_KEY){resolve(null);return;}
    if(posterCache[title]!==undefined){resolve(posterCache[title]);return;}
    https.get('https://www.omdbapi.com/?apikey='+OMDB_KEY+'&t='+encodeURIComponent(title),(r)=>{
      let d='';r.on('data',c=>d+=c);r.on('end',()=>{
        let poster=null;
        try{const j=JSON.parse(d);if(j.Poster&&j.Poster!=='N/A')poster=j.Poster;}catch(e){}
        posterCache[title]=poster;saveCache();resolve(poster);
      });
    }).on('error',()=>resolve(null));
  });
}

const VIDEO_DIR = process.argv[2] || path.join(os.homedir(), 'Videos');
const PORT = parseInt(process.argv[3] || '8377', 10);

const VIDEO_EXT = new Set(['.mp4', '.mkv', '.webm', '.avi', '.mov', '.m4v', '.ts']);
const MIME = {
  '.mp4': 'video/mp4', '.mkv': 'video/x-matroska', '.webm': 'video/webm',
  '.avi': 'video/x-msvideo', '.mov': 'video/quicktime', '.m4v': 'video/mp4',
  '.ts': 'video/mp2t',
};

// Recursively find video files
function findVideos(dir, base = dir) {
  let out = [];
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
  catch (e) { return out; }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      out = out.concat(findVideos(full, base));
    } else if (VIDEO_EXT.has(path.extname(e.name).toLowerCase())) {
      out.push({ rel: path.relative(base, full), full });
    }
  }
  return out;
}

// Get the LAN IP so other devices can connect
function getLanIP() {
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  return 'localhost';
}

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

const server = http.createServer(async (req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);

  // Home page - list of movies
  if (url === '/' || url === '/index.html') {
    const videos = findVideos(VIDEO_DIR).sort((a,b)=>a.rel.localeCompare(b.rel));
    const posters = await Promise.all(videos.map(v => fetchPoster(fileToTitle(v.rel))));
    const items = videos.map((v, i) => {
      const title = esc(fileToTitle(v.rel));
      const poster = posters[i];
      const thumb = poster ? `<img class="poster" src="${esc(poster)}" alt="${title}" loading="lazy">` : `<div class="thumb">🎬</div>`;
      return `<div class="movie" onclick="play(${i})">
        ${thumb}
        <div class="title">${title}</div>
      </div>`;
    }).join('\n');
    const list = JSON.stringify(videos.map(v => v.rel));
    const html = `<!DOCTYPE html>
<html lang="da">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>🐘 Rukhmini - hpo Film Server</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #0d0d14; color: #e8e8f0; font-family: system-ui, sans-serif; padding: 1rem; }
  h1 { color: #c9a24b; margin-bottom: 0.3rem; font-size: 1.6rem; }
  .sub { color: #888; margin-bottom: 1.5rem; font-size: 0.9rem; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 1rem; }
  .movie { background: #1a1a26; border-radius: 12px; padding: 1rem; cursor: pointer; transition: transform 0.15s, background 0.15s; border: 1px solid #262636; }
  .movie:hover { transform: translateY(-3px); background: #22222f; border-color: #c9a24b; }
  .thumb { font-size: 2.5rem; aspect-ratio: 2/3; display: flex; align-items: center; justify-content: center; background: #12121a; }
  .poster { width: 100%; aspect-ratio: 2/3; object-fit: cover; display: block; }
  .title { font-size: 0.85rem; word-break: break-word; line-height: 1.3; }
  #player { position: fixed; inset: 0; background: #000; display: none; flex-direction: column; z-index: 10; }
  #player.show { display: flex; }
  #player video { flex: 1; width: 100%; height: 100%; background: #000; }
  #bar { padding: 0.8rem 1rem; background: #12121a; display: flex; align-items: center; gap: 1rem; }
  #bar button { background: #c9a24b; color: #12121a; border: none; padding: 0.5rem 1rem; border-radius: 8px; font-weight: 600; cursor: pointer; }
  #now { color: #e8e8f0; font-size: 0.9rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .empty { color: #666; text-align: center; padding: 3rem; }
</style>
</head>
<body>
  <h1>🐘 Rukhmini</h1>
  <div class="sub">hpo film server &mdash; ${videos.length} film fundet</div>
  <div class="grid">${items || '<div class="empty">Ingen film fundet i ' + esc(VIDEO_DIR) + '</div>'}</div>
  <div id="player">
    <video id="vid" controls autoplay></video>
    <div id="bar">
      <button onclick="closePlayer()">&larr; Tilbage</button>
      <div id="now"></div>
    </div>
  </div>
<script>
  const files = ${list};
  function play(i) {
    const v = document.getElementById('vid');
    v.src = '/stream/' + encodeURIComponent(files[i]);
    document.getElementById('now').textContent = files[i];
    document.getElementById('player').classList.add('show');
    v.play();
  }
  function closePlayer() {
    const v = document.getElementById('vid');
    v.pause(); v.src = '';
    document.getElementById('player').classList.remove('show');
  }
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closePlayer(); });
</script>
</body>
</html>`;
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
    return;
  }

  // Streaming endpoint with range support (crucial for seeking + mobile)
  if (url.startsWith('/stream/')) {
    const rel = url.slice('/stream/'.length);
    // Security: resolve and confirm it's inside VIDEO_DIR
    const target = path.resolve(VIDEO_DIR, rel);
    if (!target.startsWith(path.resolve(VIDEO_DIR))) {
      res.writeHead(403); res.end('Forbidden'); return;
    }
    let stat;
    try { stat = fs.statSync(target); }
    catch (e) { res.writeHead(404); res.end('Not found'); return; }

    const mime = MIME[path.extname(target).toLowerCase()] || 'application/octet-stream';
    const range = req.headers.range;
    if (range) {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : stat.size - 1;
      const chunk = (end - start) + 1;
      res.writeHead(206, {
        'Content-Range': `bytes ${start}-${end}/${stat.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunk,
        'Content-Type': mime,
      });
      fs.createReadStream(target, { start, end }).pipe(res);
    } else {
      res.writeHead(200, { 'Content-Length': stat.size, 'Content-Type': mime, 'Accept-Ranges': 'bytes' });
      fs.createReadStream(target).pipe(res);
    }
    return;
  }

  res.writeHead(404); res.end('Not found');
});

server.listen(PORT, '0.0.0.0', () => {
  const ip = getLanIP();
  console.log(`RUKHMINI_READY`);
  console.log(`  Local:   http://localhost:${PORT}`);
  console.log(`  Network: http://${ip}:${PORT}`);
  console.log(`  Serving: ${VIDEO_DIR}`);
});
