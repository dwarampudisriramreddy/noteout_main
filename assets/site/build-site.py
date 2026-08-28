#!/usr/bin/env python3
"""Build a documentation-style site from noteout markdown notes."""

import json
import os
import re
import html
from pathlib import Path
from datetime import datetime

NOTES_DIR = Path('notes')
SITE_DIR = Path('_site')
EMOJI_FILE = Path('emojis.json')

# Structural tags auto-injected by the app; hidden from the tag tree
# so the docs look clean instead of a giant "note/journal" folder.
STRUCTURAL_TAGS = {'note', 'journal'}

MONTHS = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
]

# Accent presets: key -> (primary, secondary) used for the site's palette.
ACCENTS = {
    'indigo': ('#4f46e5', '#8b5cf6'),
    'violet': ('#7c3aed', '#a855f7'),
    'emerald': ('#059669', '#34d399'),
    'rose': ('#e11d48', '#fb7185'),
    'sky': ('#0284c7', '#38bdf8'),
    'amber': ('#d97706', '#fbbf24'),
}

LAYOUTS = ('personal', 'docs', 'simple')


def _to_bool(value, default=True):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in ('1', 'true', 'yes', 'on')
    return default


def accent_css(accent_key):
    """CSS variable overrides for the chosen accent palette."""
    prim, sec = ACCENTS.get((accent_key or 'indigo').lower(), ACCENTS['indigo'])
    return f'''\
:root{{
  --pc:{prim};
  --accent:{sec};
  --primary:var(--pc);
  --primary-soft:color-mix(in srgb, var(--pc) 12%, transparent);
  --ring:color-mix(in srgb, var(--pc) 22%, transparent);
}}
[data-theme=dark]{{
  --primary:color-mix(in srgb, var(--pc) 62%, white);
  --primary-soft:color-mix(in srgb, var(--pc) 20%, transparent);
}}'''

CSS = """
:root{
  --bg:#f5f6fa; --surface:#ffffff; --surface-2:#eef0f7; --line:#e4e6f0;
  --text:#1c2130; --muted:#68718a; --faint:#9aa3b8;
  --primary:#4f46e5; --primary-strong:#4338ca; --accent:#8b5cf6;
  --primary-soft:#eef0ff; --ring:rgba(79,70,229,.16);
  --shadow-sm:0 1px 2px rgba(16,20,40,.06);
  --shadow:0 8px 24px -12px rgba(16,20,40,.25);
  --radius:14px;
}
[data-theme=dark]{
  --bg:#0b0e17; --surface:#12161f; --surface-2:#1a1f2c; --line:#232a3b;
  --text:#e6e9f2; --muted:#9aa3b8; --faint:#67708a;
  --primary:#818cf8; --primary-strong:#a5b4fc; --accent:#a78bfa;
  --primary-soft:rgba(129,140,248,.14); --ring:rgba(129,140,248,.22);
  --shadow-sm:0 1px 2px rgba(0,0,0,.4);
  --shadow:0 8px 24px -12px rgba(0,0,0,.6);
}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{display:flex;flex-direction:column;min-height:100vh;margin:0;font-family:'Inter',ui-sans-serif,system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--text);line-height:1.65;-webkit-font-smoothing:antialiased}
img{max-width:100%}
a{color:var(--primary);text-decoration:none}
svg{flex:none}

.topbar{position:sticky;top:0;z-index:40;height:60px;display:flex;align-items:center;gap:12px;padding:0 18px;background:var(--surface);border-bottom:1px solid var(--line)}
.topbar .logo{display:inline-flex;align-items:center;gap:10px;font-weight:700;font-size:.96em;color:var(--text);min-width:0}
.topbar .logo img{width:30px;height:30px;border-radius:50%;object-fit:cover;flex:none}
.topbar .logo span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.burger{display:none;align-items:center;justify-content:center;width:38px;height:38px;border-radius:10px;border:1px solid var(--line);background:var(--surface);cursor:pointer;color:var(--text);flex:none}
.icobtn{width:38px;height:38px;border-radius:10px;border:1px solid var(--line);background:var(--surface);cursor:pointer;color:var(--muted);display:inline-flex;align-items:center;justify-content:center;transition:.15s;flex:none}
.icobtn:hover{color:var(--primary);border-color:var(--primary)}
.topnav{display:flex;gap:4px;margin-left:auto;align-items:center}
.topnav a{padding:7px 13px;border-radius:9px;color:var(--muted);font-weight:500;font-size:.92em}
.topnav a:hover{color:var(--text);background:var(--surface-2)}
.topnav a.active{color:var(--primary);background:var(--primary-soft)}

.layout{flex:1;width:100%;display:grid;grid-template-columns:280px minmax(0,1fr);max-width:1300px;margin:0 auto}
.sidebar{position:sticky;top:60px;height:calc(100vh - 60px);overflow-y:auto;background:var(--surface);border-right:1px solid var(--line);padding:18px 12px 40px;scrollbar-width:thin;scrollbar-color:var(--line) transparent}
.content{padding:42px 46px 70px;min-width:0}
@media(max-width:920px){
  .layout{grid-template-columns:minmax(0,1fr)}
  .sidebar{position:fixed;left:0;top:60px;bottom:0;height:auto;width:290px;transform:translateX(-102%);transition:transform .22s ease;z-index:30;box-shadow:var(--shadow)}
  body.nav-open .sidebar{transform:none}
  .burger{display:inline-flex}
  .content{padding:28px 20px 60px}
}

.brand{display:flex;align-items:center;gap:12px;padding:4px 8px;margin-bottom:16px;color:var(--text)}
.brand img{width:44px;height:44px;border-radius:50%;object-fit:cover;border:2px solid var(--line);flex:none}
.brand .b1{font-weight:700;font-size:.95em;line-height:1.2;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
.brand .b2{font-size:.75em;color:var(--muted);overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
.snav a{display:flex;align-items:center;gap:10px;padding:8px 11px;border-radius:10px;font-weight:500;font-size:.92em;color:var(--text);margin-bottom:2px}
.snav a:hover{background:var(--surface-2)}
.snav a.active{background:var(--primary);color:#fff}
.snav .ico{width:18px;height:18px;opacity:.85}
.slabel{font-size:.7em;font-weight:700;letter-spacing:.07em;text-transform:uppercase;color:var(--faint);margin:20px 10px 8px}

.ttree{font-size:.9em}
.ttree .tmut{list-style:none;display:flex;align-items:center;gap:8px;padding:6px 9px;border-radius:9px;cursor:pointer;color:var(--text);font-weight:500;outline:none;transition:background .12s}
.ttree .tmut:hover{background:var(--surface-2)}
.ttree .tmut::-webkit-details-marker{display:none}
.ttree .chev{width:16px;height:16px;color:var(--faint);display:inline-flex;align-items:center;justify-content:center;transition:transform .16s}
.ttree details[open]>.tmut .chev{transform:rotate(90deg)}
.ttree .fname{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:inherit}
.ttree .fname:hover{color:var(--primary)}
.ttree .fld{color:var(--muted)}
.ttree .cnt{margin-left:auto;font-size:.72em;color:var(--muted);background:var(--surface-2);border-radius:99px;padding:0 7px;line-height:17px;flex:none}
.ttree .kids{margin:2px 0 4px;padding-left:15px;border-left:1px dashed var(--line)}
.ttree a.tlink{display:flex;align-items:center;gap:8px;padding:6px 9px;border-radius:9px;color:var(--text);transition:background .12s}
.ttree a.tlink:hover{background:var(--surface-2);color:var(--primary)}
.ttree a.tlink .hash{color:var(--primary);font-weight:700}

.crumbs{display:flex;flex-wrap:wrap;align-items:center;gap:7px;font-size:.85em;color:var(--muted);margin-bottom:16px}
.crumbs a{color:var(--muted)}
.crumbs a:hover{color:var(--primary)}
.crumbs .sep{color:var(--faint)}
.crumbs .cur{color:var(--text);font-weight:600;max-width:60vw;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
h1.doctitle{font-size:1.95em;letter-spacing:-.02em;line-height:1.2;margin:6px 0 6px;font-weight:800}
.docsub{color:var(--muted);margin:0 0 26px;font-size:1.02em}

.notes{display:flex;flex-direction:column;gap:14px}
.card{display:block;background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:16px 19px;color:inherit;transition:transform .15s ease,box-shadow .15s ease,border-color .15s ease}
.card h3{margin:0 0 4px;font-size:1.02em;font-weight:700}
.card p.ex{margin:0 0 12px;color:var(--muted);font-size:.89em;line-height:1.55;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.card .meta{display:flex;flex-wrap:wrap;align-items:center;gap:8px;font-size:.78em;color:var(--faint)}
.card time{font-variant-numeric:tabular-nums}
.card:hover{transform:translateY(-2px);box-shadow:var(--shadow);border-color:var(--primary)}
.card.dd{display:grid;grid-template-columns:1fr 1fr;gap:14px}
@media(max-width:760px){.card.dd{grid-template-columns:1fr}}
.pill{display:inline-flex;align-items:center;gap:4px;background:var(--primary-soft);color:var(--primary);border-radius:99px;padding:2px 10px;font-weight:600;font-size:.8em;transition:background .15s,color .15s}
.pill:hover{background:var(--primary);color:#fff}
.section{display:flex;align-items:center;gap:10px;font-size:1.02em;font-weight:800;margin:32px 0 14px;color:var(--text)}
.section .fldr{color:var(--primary)}
.section .cnt{font-weight:600;font-size:.76em;color:var(--muted);background:var(--surface-2);border-radius:99px;padding:2px 9px}
.section .more{margin-left:auto;font-size:.78em;font-weight:600;color:var(--muted)}
.section .more:hover{color:var(--primary)}
.group .notes{margin-bottom:6px}

.hero{display:flex;align-items:center;gap:22px;padding:30px 32px;border-radius:20px;background:linear-gradient(135deg,var(--primary),var(--accent));color:#fff;margin-bottom:26px;position:relative;overflow:hidden;box-shadow:var(--shadow)}
[data-theme=dark] .hero{background:linear-gradient(135deg,var(--primary-strong),var(--accent))}
.hero::after{content:'';position:absolute;right:-70px;top:-70px;width:230px;height:230px;border-radius:50%;background:rgba(255,255,255,.12)}
.hero::before{content:'';position:absolute;left:38%;bottom:-90px;width:180px;height:180px;border-radius:50%;background:rgba(255,255,255,.08)}
.hero img{width:86px;height:86px;border-radius:50%;object-fit:cover;border:3px solid rgba(255,255,255,.45);flex:none;position:relative;z-index:1}
.hero .hx{position:relative;z-index:1;min-width:0}
.hero h1{margin:0 0 4px;font-size:1.7em;letter-spacing:-.02em;line-height:1.15;color:#fff}
.hero .tag{opacity:.92;font-size:1em;margin:0}
.hero .at{opacity:.8;font-size:.84em;margin-top:2px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:12px;margin:26px 0 30px}
.stat{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:15px 18px;display:flex;flex-direction:column;gap:2px;color:var(--text);text-decoration:none;transition:border-color .15s ease,box-shadow .15s ease}
.stat[href]{cursor:pointer;transition:border-color .15s ease,box-shadow .15s ease}
.stat[href]:hover{border-color:var(--primary);box-shadow:var(--shadow)}
.stat b{font-size:1.55em;font-weight:800;letter-spacing:-.02em}
.stat span{font-size:.76em;color:var(--muted)}
.stat.dark b{color:var(--primary)}
.search{position:relative;margin-bottom:28px}
.search input{width:100%;padding:12px 16px 12px 44px;border-radius:12px;border:1px solid var(--line);background:var(--surface);color:var(--text);font-size:.95em;outline:none;transition:border-color .15s,box-shadow .15s}
.search input:focus{border-color:var(--primary);box-shadow:0 0 0 4px var(--ring)}
.search svg{position:absolute;left:16px;top:50%;transform:translateY(-50%);color:var(--faint);pointer-events:none}
.empty{color:var(--muted);text-align:center;margin:56px 0;font-size:1em}

.heatmap-wrap{overflow-x:auto;padding:10px 0 20px;scrollbar-width:none}
.heatmap-wrap::-webkit-scrollbar{display:none}
.hm-months{display:flex;font-size:11px;color:var(--muted);margin-bottom:6px;font-weight:500}
.hm-month{flex-shrink:0}
.heatmap{display:grid;grid-template-rows:repeat(7,20px);grid-auto-flow:column;grid-auto-columns:20px;gap:4px}
.hm-day{width:20px;height:20px;border-radius:4px;background:var(--surface-2);position:relative;text-decoration:none;display:flex;align-items:center;justify-content:center;transition:transform 0.1s;font-size:13px;line-height:1}
.hm-day.active{background:var(--primary)}
.hm-day:hover{transform:scale(1.2);z-index:2}
.hm-day::after{content:attr(data-title);position:absolute;bottom:100%;left:50%;transform:translate(-50%, -4px);background:var(--text);color:var(--surface);padding:4px 8px;border-radius:4px;font-size:11px;white-space:nowrap;opacity:0;pointer-events:none;transition:opacity 0.2s;z-index:10;font-weight:600}
.hm-day:hover::after{opacity:1}

.empty-search{display:none;color:var(--muted);text-align:center;margin:34px 0;font-size:.95em}
.tblocks{display:flex;flex-wrap:wrap;gap:8px}
.tblock{display:flex;flex-direction:row;align-items:center;gap:8px;background:var(--surface);border:1px solid var(--line);border-radius:24px;padding:6px 14px 6px 10px;color:var(--text);transition:transform .15s ease,border-color .15s ease,box-shadow .15s ease;text-decoration:none}
.tblock:hover{transform:translateY(-1px);border-color:var(--primary);box-shadow:var(--shadow-sm)}
.tblock .tb-ico{color:var(--primary);display:flex;align-items:center;width:16px;height:16px}
.tblock .tb-ico svg{width:100%;height:100%}
.tblock .tb-name{font-weight:600;font-size:.85em;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tblock .tb-cnt{font-size:.75em;color:var(--muted);background:var(--surface-2);padding:2px 6px;border-radius:12px;margin-left:2px}

.meta-line{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin-bottom:22px}
article{font-size:1.02em;max-width:860px}
article h2{font-size:1.35em;margin:1.8em 0 .6em;letter-spacing:-.01em}
article h3{font-size:1.14em}
article h4{font-size:1.02em}
article a{text-decoration:underline;text-underline-offset:3px;text-decoration-color:var(--primary-soft)}
article code{background:var(--surface-2);border:1px solid var(--line);padding:2px 6px;border-radius:6px;font-family:'JetBrains Mono',ui-monospace,SFMono-Regular,monospace;font-size:.85em}
article pre{background:#0f1524;color:#e6e9f2;border:1px solid var(--line);border-radius:12px;padding:16px 18px;overflow-x:auto;font-size:.86em;line-height:1.6;box-shadow:inset 0 1px 3px rgba(0,0,0,.25);font-family:'JetBrains Mono',ui-monospace,monospace}
[data-theme=dark] article pre{background:#05070d}
article pre code{background:none;border:none;padding:0;color:inherit}
article blockquote{margin:1.4em 0;border-left:3px solid var(--primary);background:var(--surface-2);padding:14px 18px;border-radius:0 10px 10px 0;color:var(--muted);font-style:italic}
article img.note-img{border-radius:12px;border:1px solid var(--line);box-shadow:var(--shadow-sm);margin:10px 0}
article hr{border:none;border-top:2px dashed var(--line);margin:28px 0}
article ul,article ol{padding-left:1.4em}
article li{margin:.35em 0}
.wiki-link{background:var(--primary-soft);border-radius:6px;padding:1px 7px;color:var(--primary);text-decoration:none;font-weight:500;white-space:nowrap}
.wiki-link:hover{background:var(--primary);color:#fff}
.katex-display{overflow-x:auto;overflow-y:hidden;padding:.4em 0}
.links{border-top:1px solid var(--line);margin-top:36px;padding-top:20px}
.links h3{font-size:.9em;margin:0 0 10px}
.links .wiki-link{margin-right:4px;display:inline-block;margin-bottom:6px}

.cal-wrap{display:flex;flex-direction:column;gap:24px;width:100%;max-width:780px;margin:0 auto}
.cal-embed{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px;width:100%;max-width:1160px;margin:0 auto}
.cal-embed .month{margin:0}
.month{border:1px solid var(--line);background:var(--surface);border-radius:16px;padding:18px 18px 20px}
.month h2{margin:0 0 12px;font-size:1.05em;font-weight:800}
.cweek{display:grid;grid-template-columns:repeat(7,1fr);gap:5px;margin-bottom:6px;padding:0 2px}
.cweek span{text-align:center;font-family:'JetBrains Mono',ui-monospace,monospace;font-size:.64em;font-weight:700;color:var(--faint);text-transform:uppercase;letter-spacing:.06em}
.cal-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:5px}
.day{aspect-ratio:1;display:flex;align-items:center;justify-content:center;border-radius:9px;font-variant-numeric:tabular-nums;color:var(--text);background:var(--surface-2);border:1px solid transparent}
.day.empty{background:transparent}
.day .cel{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;width:100%;height:100%;border-radius:inherit;text-decoration:none;color:inherit}
.day .dn{font-family:'JetBrains Mono',ui-monospace,monospace;font-size:.86em;font-weight:500;line-height:1;color:var(--text)}
.day .em{font-size:15px;line-height:1;height:15px}
.day .dot{width:5px;height:5px;border-radius:50%;background:#3b82f6}
.day.today .dn{color:#3b82f6;font-weight:700}
.day.today{box-shadow:inset 0 0 0 1.5px #3b82f6}
.day.has-note{border-color:var(--primary);background:var(--primary-soft);cursor:pointer}
.day.has-note .dn{color:var(--primary);font-weight:600}
.day.has-note:hover{border-color:var(--primary);box-shadow:var(--shadow)}

footer.site{width:100%;box-sizing:border-box;max-width:1300px;margin:0 auto;border-top:1px solid var(--line);padding:22px 30px 30px;color:var(--muted);font-size:.78em;display:flex;justify-content:center;text-align:center;}
footer.site b{color:var(--text)}
.scrim{display:none;position:fixed;inset:0;background:rgba(8,10,20,.45);z-index:29}
body.nav-open .scrim{display:block}
@media(max-width:920px){
  .topnav{display:none}
}
"""

JS = """
(function(){try{var t=localStorage.getItem('theme');if(t){document.documentElement.setAttribute('data-theme',t);}else{var d=window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light';document.documentElement.setAttribute('data-theme',d);}}catch(e){}})();
function toggleTheme(){var h=document.documentElement;var n=h.getAttribute('data-theme')==='dark'?'light':'dark';h.setAttribute('data-theme',n);try{localStorage.setItem('theme',n);}catch(e){}}
function toggleNav(){document.body.classList.toggle('nav-open');}
document.addEventListener('click',function(e){
  if(e.target.closest('.sidebar a')){document.body.classList.remove('nav-open');}
});
document.querySelectorAll('.searchbox').forEach(function(input){
  input.addEventListener('input',function(){
    var q=this.value.toLowerCase().trim();
    var wrap=this.closest('.search-wrap');
    if(!wrap)return;
    var cards=wrap.querySelectorAll('.card');
    var any=false;
    cards.forEach(function(c){
      var txt=c.getAttribute('data-search')||'';
      var hit=!q||txt.toLowerCase().indexOf(q)>-1;
      c.style.display=hit?'':'none';
      if(hit)any=true;
    });
    var emp=wrap.querySelectorAll('.empty-search');
    emp.forEach(function(e){e.style.display=any?'none':'block';});
  });
});

document.addEventListener('DOMContentLoaded',function(){
  var hw=document.querySelector('.heatmap-wrap');
  if(hw) hw.scrollLeft=hw.scrollWidth;
});
"""

ICONS = {
    'home': '<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.3V21h14V9.3"/></svg>',
    'notes': '<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M16 13H8"/><path d="M16 17H8"/></svg>',
    'tags': '<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>',
    'calendar': '<svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>',
    'folder': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>',
    'chev': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>',
    'moon': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>',
    'burger': '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 6h16M4 12h16M4 18h16"/></svg>',
    'search': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>',
}


def parse_frontmatter(content):
    """Parse YAML-ish frontmatter from markdown."""
    if not content.startswith('---'):
        return {}, content
    end = content.find('---', 3)
    if end == -1:
        return {}, content
    raw = content[3:end].strip()
    meta = {}
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            meta = parsed
    except Exception:
        for line in raw.split('\n'):
            if ':' in line:
                key, val = line.split(':', 1)
                key = key.strip()
                val = val.strip()
                if val.startswith('[') and val.endswith(']'):
                    val = [v.strip().strip('"').strip("'") for v in val[1:-1].split(',') if v.strip()]
                elif val.startswith('"') and val.endswith('"'):
                    val = val[1:-1]
                elif val.startswith("'") and val.endswith("'"):
                    val = val[1:-1]
                meta[key] = val
    body = content[end + 3:].strip()
    return meta, body


def slug(title):
    """Create URL-safe slug from title."""
    name = title.lower()
    name = re.sub(r'[^\w\s-]', '', name)
    name = re.sub(r'\s+', '-', name)
    name = re.sub(r'-+', '-', name)
    name = re.sub(r'^-|-$', '', name)
    return name or 'untitled'


def simple_md(text):
    """Minimal markdown to HTML conversion."""
    text = html.escape(text)
    # code blocks
    text = re.sub(r'```(\w*)\n(.*?)```', r'<pre><code>\2</code></pre>', text, flags=re.DOTALL)
    # inline code
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    # images ![](url)
    text = re.sub(
        r'!\[([^\]]*)\]\(([^)]+)\)',
        r'<img src="\2" alt="\1" class="note-img" loading="lazy">',
        text,
    )
    # headers (before bold/italic so #### doesn't eat text)
    text = re.sub(r'^##### (.+)$', r'<h5>\1</h5>', text, flags=re.MULTILINE)
    text = re.sub(r'^#### (.+)$', r'<h4>\1</h4>', text, flags=re.MULTILINE)
    text = re.sub(r'^### (.+)$', r'<h3>\1</h3>', text, flags=re.MULTILINE)
    text = re.sub(r'^## (.+)$', r'<h2>\1</h2>', text, flags=re.MULTILINE)
    text = re.sub(r'^# (.+)$', r'<h1>\1</h1>', text, flags=re.MULTILINE)
    # bold and italic
    text = re.sub(r'\*\*\*(.+?)\*\*\*', r'<strong><em>\1</em></strong>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
    # wiki links [[note]]
    text = re.sub(
        r'\[\[([^\]]+)\]\]',
        lambda m: f'<a href="{slug(m.group(1))}.html" class="wiki-link">[[{html.escape(m.group(1))}]]</a>',
        text
    )
    # tags #tag (including nested tag/tag)
    text = re.sub(
        r'(?:^|\s)#([a-zA-Z0-9_]+(?:/[a-zA-Z0-9_]+)*)',
        r' <span class="pill">#\1</span>',
        text
    )
    # blockquote
    text = re.sub(r'^> (.+)$', r'<blockquote>\1</blockquote>', text, flags=re.MULTILINE)
    # unordered list
    text = re.sub(r'^[-*] (.+)$', r'<li>\1</li>', text, flags=re.MULTILINE)
    text = re.sub(r'(<li>.*</li>\n?)+', lambda m: f'<ul>{m.group(0)}</ul>', text)
    # ordered list
    text = re.sub(r'^\d+\. (.+)$', r'<li>\1</li>', text, flags=re.MULTILINE)
    text = re.sub(r'(<li>.*</li>\n?)+', lambda m: f'<ol>{m.group(0)}</ol>', text)
    # horizontal rule
    text = re.sub(r'^---+$', r'<hr>', text, flags=re.MULTILINE)
    # paragraphs (double newline)
    text = re.sub(r'\n\n+', '</p><p>', text)
    text = '<p>' + text + '</p>'
    # single newline to br
    text = text.replace('\n', '<br>')
    # clean empty p tags
    text = re.sub(r'<p>\s*</p>', '', text)
    text = re.sub(r'<p>(<h[1-6])', r'\1', text)
    text = re.sub(r'(</h[1-6]>)</p>', r'\1', text)
    text = re.sub(r'<p>(<ul>|<ol>)', r'\1', text)
    text = re.sub(r'(</ul>|</ol>)</p>', r'\1', text)
    text = re.sub(r'<p>(<hr>)', r'\1', text)
    text = re.sub(r'(</?blockquote>)</p>', r'\1', text)
    text = re.sub(r'<p>\s*<br>\s*', '<p>', text)
    text = re.sub(r'<br>\s*</p>', '</p>', text)
    return text


def load_emojis():
    """Load emoji data if available."""
    if EMOJI_FILE.exists():
        try:
            return json.loads(EMOJI_FILE.read_text())
        except Exception:
            return {}
    return {}


def _env(*keys):
    """First non-empty environment variable."""
    for key in keys:
        val = os.environ.get(key)
        if val:
            return val
    return ''


def get_config():
    """Site identity: display name, GitHub username/owner, avatar."""
    config = {}
    if Path('config.json').exists():
        try:
            config = json.loads(Path('config.json').read_text())
        except Exception:
            pass

    owner = (config.get('username') or config.get('owner') or '').strip()
    if not owner:
        owner = _env('GITHUB_REPOSITORY').split('/')[0]
    if not owner:
        owner = _env('GITHUB_ACTOR').strip()

    name = (config.get('name') or '').strip() or owner or 'Your Name'

    profile_img = ''
    for ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']:
        if Path(f'profile.{ext}').exists():
            profile_img = f'profile.{ext}'
            try:
                (SITE_DIR / profile_img).write_bytes(Path(profile_img).read_bytes())
            except Exception:
                pass
            break

    if profile_img:
        avatar = profile_img
    elif owner:
        avatar = f'https://github.com/{owner}.png?size=256'
    else:
        avatar = ''

    layout = (config.get('layout') or 'personal').strip()
    if layout not in LAYOUTS:
        layout = 'personal'

    return {
        'name': name,
        'owner': owner,
        'about': (config.get('about', config.get('tagline')) or '').strip()
        or 'my notes, published',
        'layout': layout,
        'accent': (config.get('accent') or 'indigo').strip(),
        'show_calendar': _to_bool(config.get('showCalendar'), True),
        'show_profile': _to_bool(config.get('showProfile'), True),
        'profile_img': profile_img,
        'avatar': avatar,
    }


def avatar_url(config, prefix=''):
    """Resolve avatar src, honoring the page depth prefix for local files."""
    av = config.get('avatar') or ''
    if not av:
        return ''
    if av.startswith('http'):
        return av
    return f'{prefix}{av}'


def tag_href(tag):
    """URL for a tag page, using folders for nested tags (tag-a/b.html)."""
    return 'tag-' + '/'.join(slug(seg) for seg in tag.split('/')) + '.html'


def prefix_for(tag):
    """'../'-prefix required to reach the site root from a page's folder."""
    return '../' * tag.count('/')


def _meta_tags(meta):
    """Return the note's tags as a list (handles list or string forms)."""
    tags = meta.get('tags', [])
    if isinstance(tags, str):
        return [tags] if tags else []
    return list(tags)


def _primary_tag(meta):
    """First real (non-structural) tag; '' if only structural tags exist."""
    for t in _meta_tags(meta):
        if t not in STRUCTURAL_TAGS:
            return t
    return ''


def _tag_match(meta, tag):
    """True if the note has this tag or a descendant (nested) tag."""
    tags = _meta_tags(meta)
    return tag in tags or any(t.startswith(tag + '/') for t in tags)


def _excerpt(content, length=160):
    """Plain-ish excerpt for cards."""
    text = re.sub(r'```.*?```', ' ', content, flags=re.DOTALL)
    text = re.sub(r'!\[[^\]]*\]\([^)]*\)', ' ', text)
    text = re.sub(r'[#*`>\-\[\]]', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    if len(text) > length:
        text = text[:length].rstrip() + '…'
    return text


def page_shell(title, body_html, active, tree_html, prefix=''):
    """Wrap content in the docs-style page template."""
    cfg = get_config()
    site_title = f"{cfg['name']}'s notes" if cfg.get('name') else 'notes'
    av = avatar_url(cfg, prefix)
    nav_items = [
        ('index.html', 'home', ICONS['home'], 'Home'),
        ('notes.html', 'notes', ICONS['notes'], 'Notes'),
        ('journals.html', 'journals', ICONS['calendar'], 'Journals'),
        ('tags.html', 'tags', ICONS['tags'], 'Tags'),
            ]

    def link(href, key, label):
        if key == active:
            return f'<a href="{prefix}{href}" class="active">{label}</a>'
        return f'<a href="{prefix}{href}">{label}</a>'

    topbar_links = ''.join(link(h, k, l) for h, k, _ic, l in nav_items)
    snav_active = ''.join(
        f'<a class="active" href="{prefix}{href}">{ic}{label}</a>'
        if key == active
        else f'<a href="{prefix}{href}">{ic}{label}</a>'
        for href, key, ic, label in nav_items
    )

    brand_avatar = f'<img src="{av}" alt="avatar">' if av else ''
    brand = (
        f'<a class="brand" href="{prefix}index.html">'
        f'{brand_avatar}'
        f'<span><div class="b1">{html.escape(cfg["name"])}</div>'
        f'<div class="b2">{html.escape("@" + cfg["owner"]) if cfg.get("owner") else "notes"}</div></span>'
        f'</a>'
    )
    hero_avatar = f'<img src="{av}" alt="avatar">' if av else ''

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)} — {html.escape(site_title)}</title>
  <meta name="description" content="{html.escape(cfg['name'])}'s notes">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js" onload="renderMathInElement(document.body,{{delimiters:[{{left:'$',right:'$',display:false}},{{left:'$$',right:'$$',display:true}}]}})"></script>
  <style>{accent_css(cfg.get('accent'))}{CSS}</style>
</head>
<body>
  <div class="scrim" onclick="toggleNav()"></div>
  <header class="topbar">
    <button class="burger" onclick="toggleNav()" aria-label="Menu">{ICONS['burger']}</button>
    <a class="logo" href="{prefix}index.html">{brand_avatar}<span>{html.escape(cfg['name'])}</span></a>
    <div style="flex: 1"></div>
    <nav class="topnav">{topbar_links}</nav>
    <button class="icobtn" onclick="toggleTheme()" aria-label="Toggle theme">{ICONS['moon']}</button>
  </header>

  <div class="layout">
    <aside class="sidebar">
      <nav class="snav">{snav_active}</nav>
      <div class="slabel">Categories</div>
      <div class="ttree">{tree_html}
      </div>
    </aside>
    <main class="content">
      {body_html}
    </main>
  </div>

  <footer class="site">
    <div>© {datetime.now().year} <b>{html.escape(cfg['name'])}</b> - made with noteout</div>
  </footer>
  <script>{JS}</script>
</body>
</html>'''


def render_tag_tree(root, notes, tprefix='', href_prefix='', opened=False):
    """Render a nested tag tree as collapsible folder menu.

    tprefix is the tag-path prefix (e.g. 'project/'); href_prefix is the
    '../' depth string needed to reach the site root from the current page.
    """
    items = []
    for seg in sorted(root.keys()):
        child = root[seg]
        full = f'{tprefix}{seg}'
        count = sum(1 for meta, _ in notes if _tag_match(meta, full))
        href = f'{href_prefix}{tag_href(full)}'
        open_attr = ' open' if opened else ''
        if child:
            inner = render_tag_tree(
                child, notes, tprefix=full + '/',
                href_prefix=href_prefix, opened=opened)
            items.append(
                f'<details{open_attr}><summary class="tmut">'
                f'<span class="chev">{ICONS["chev"]}</span>'
                f'<span class="fld">{ICONS["folder"]}</span>'
                f'<a class="fname" href="{href}">{html.escape(seg)}</a>'
                f'<span class="cnt">{count}</span>'
                f'</summary><div class="kids">{inner}</div></details>'
            )
        else:
            items.append(
                f'<div><a class="tlink" href="{href}">'
                f'<span class="hash">#</span><span class="fname">{html.escape(seg)}</span>'
                f'<span class="cnt">{count}</span></a></div>'
            )
    return '\n'.join(items)


def build_tag_tree(notes):
    """Build nested dict from non-structural tags."""
    root = {}
    for meta, _ in notes:
        for tag in _meta_tags(meta):
            if tag in STRUCTURAL_TAGS:
                continue
            node = root
            for seg in tag.split('/'):
                node = node.setdefault(seg, {})
    return root


def pill_html(tags, prefix, exclude=()):
    """Tag pill links, excluding given tags and structural tags."""
    parts = []
    for t in tags:
        if t in exclude or t in STRUCTURAL_TAGS:
            continue
        parts.append(f'<a class="pill" href="{prefix}{tag_href(t)}">#{html.escape(t)}</a>')
    return ''.join(parts)


def card_html(meta, content, prefix, exclude=(), dd=False):
    """A single note card."""
    title = meta.get('title', 'untitled')
    created = meta.get('created', '')[:10]
    tags = _meta_tags(meta)
    others = pill_html(tags, prefix, exclude=exclude)
    excerpt = _excerpt(content)
    search_text = ' '.join([title, excerpt, *tags])
    cls = 'card dd' if dd else 'card'
    return f'''<a class="{cls}" href="{prefix}{slug(title)}.html" data-search="{html.escape(search_text)}">
  <h3>{html.escape(title)}</h3>
  <div class="meta"><time>{created}</time>{others}</div>
</a>'''


def group_section_html(key, items, prefix, limit=None):
    """A tag-folder section: header + cards (optionally limited)."""
    head = '<div class="section">'
    shown = items if limit is None else items[:limit]
    if key:
        pieces = [html.escape(p) for p in key.split('/')]
        label = ' / '.join(pieces)
        head += (
            f'<span class="fldr">{ICONS["folder"]}</span>'
            f'<a class="fname" href="{prefix}{tag_href(key)}">{label}</a>'
            f'<span class="cnt">{len(items)}</span>'
        )
        if limit is not None and len(items) > limit:
            head += (
                f'<a class="more" href="{prefix}{tag_href(key)}">'
                f'view all {len(items) - limit}+ →</a>'
            )
    else:
        head += (
            f'<span class="fldr">{ICONS["folder"]}</span>'
            f'<span>Uncategorized</span>'
            f'<span class="cnt">{len(items)}</span>'
        )
        if limit is not None and len(items) > limit:
            head += f'<a class="more" href="{prefix}notes.html">view all →</a>'
    head += '</div>'

    cards = ''.join(card_html(m, c, prefix, exclude={key} if key else (), dd=True)
                    for m, c in shown)
    return f'<div class="group">{head}<div class="notes dd">{cards}</div></div>'


def group_notes(notes):
    """Group notes by primary tag, alphabetically, untagged last."""
    groups = {}
    for m, c in notes:
        key = _primary_tag(m)
        groups.setdefault(key, []).append((m, c))
    ordered = sorted(groups.items(), key=lambda kv: (kv[0] == '', kv[0]))
    return ordered


def crumbs_html(crumbs, prefix=''):
    """Breadcrumb list: list of (label, href|None)."""
    out = ['<nav class="crumbs">']
    out.append(f'<a href="{prefix}index.html">Home</a><span class="sep">›</span>')
    for i, (label, href, is_last) in enumerate(crumbs):
        if href and not is_last:
            out.append(f'<a href="{prefix}{href}">{html.escape(label)}</a>')
            out.append('<span class="sep">›</span>')
        else:
            out.append(f'<span class="cur">{html.escape(label)}</span>')
    out.append('</nav>')
    return ''.join(out)


def _stats_html(regular, journal, tags_count):
    return f'''
<div class="stats">
  <a class="stat" href="notes.html"><b>{len(regular)}</b><span>notes</span></a>
  <a class="stat" href="tags.html"><b>{tags_count}</b><span>categories</span></a>
  <div class="stat dark"><b>↗</b><span>synced notes site</span></div>
</div>'''


def _hero_html(cfg):
    av = avatar_url(cfg)
    if not cfg.get('show_profile', True):
        return ''
    hero_avatar = f'<img src="{av}" alt="avatar">' if av else ''
    tagline = cfg.get('about') or 'my notes, published'
    return f'''
<div class="hero">
  {hero_avatar}
  <div class="hx">
    <h1>{html.escape(cfg['name'])}</h1>
    {f'<p class="tag">{html.escape(tagline)}</p>' if tagline else ''}
    {f'<p class="at">{html.escape("@" + cfg["owner"])}</p>' if cfg.get('owner') else ''}
  </div>
</div>'''






def _journal_section(notes, emojis):
    now = datetime.now()
    start = now - __import__('datetime').timedelta(days=364)
    start -= __import__('datetime').timedelta(days=(start.weekday() + 1) % 7)

    journal_dates = {}
    for meta, _c in notes:
        title = meta.get('title', '')
        if title.startswith('journal:'):
            d = title.replace('journal:', '')
            journal_dates[d] = meta

    cells = []
    months = []
    last_month = None
    curr = start
    
    while curr <= now:
        if curr.weekday() == 6 or last_month is None:
            if curr.month != last_month:
                months.append([curr.strftime('%b'), 1])
                last_month = curr.month
            else:
                if months:
                    months[-1][1] += 1

        date_key = f'{curr.year}-{curr.month:02d}-{curr.day:02d}'
        emoji = emojis.get(date_key, '')
        has_note = date_key in journal_dates
        cls = 'hm-day active' if has_note else 'hm-day'
        
        title_attr = f'{emoji} {date_key}'.strip() if has_note else date_key
        
        if has_note:
            s = slug(f'journal:{date_key}')
            cells.append(f'<a href="{s}.html" class="{cls}" data-title="{title_attr}">{emoji}</a>')
        else:
            cells.append(f'<div class="{cls}" data-title="{title_attr}">{emoji}</div>')
            
        curr += __import__('datetime').timedelta(days=1)

    month_html = '<div class="hm-months">'
    for m, span in months:
        width = span * 24
        month_html += f'<div style="width:{width}px" class="hm-month">{m}</div>'
    month_html += '</div>'

    grid = '<div class="heatmap">' + ''.join(cells) + '</div>'
    
    return f'''
<div class="section"><span class="fldr">{ICONS['calendar']}</span><span>activity</span></div>
<div class="heatmap-wrap">{month_html}{grid}</div>'''


def build_index(notes, tree_html, emojis):
    """Generate index.html home page, honoring the chosen layout."""
    cfg = get_config()
    if cfg.get('layout') == 'docs':
        return _build_index_docs(notes, tree_html, cfg)
    return _build_index_personal(notes, tree_html, cfg, emojis)



def build_tag_blocks(notes):
    """Grid of tag blocks linking to each category's notes."""
    tags = {}
    for meta, _ in notes:
        for t in _meta_tags(meta):
            if t in STRUCTURAL_TAGS:
                continue
            tags[t] = tags.get(t, 0) + 1
    if not tags:
        return '<p class="empty">no categories yet</p>'
    blocks = []
    regular_count = sum(1 for m, _ in notes if not m.get('title', '').startswith('journal:'))
    blocks.append(
        f'<a class="tblock" href="notes.html"><span class="tb-ico">{ICONS["notes"]}</span>'
        f'<span class="tb-name">All Notes</span>'
        f'<span class="tb-cnt">{regular_count} note{"s" if regular_count != 1 else ""}</span></a>'
    )
    for tag in sorted(tags.keys()):
        label = ' / '.join(__import__('html').escape(p) for p in tag.split('/'))
        n = tags[tag]
        blocks.append(
            f'<a class="tblock" href="{tag_href(tag)}"><span class="tb-ico">{ICONS["folder"]}</span>'
            f'<span class="tb-name">{label}</span>'
            f'<span class="tb-cnt">{n} note{"s" if n != 1 else ""}</span></a>'
        )
    return f'<div class="tblocks">{"".join(blocks)}</div>'


def _build_index_personal(notes, tree_html, cfg, emojis):
    """Personal home: hero, stats, emoji calendar, category blocks."""
    regular = [(m, c) for m, c in notes if not m.get('title', '').startswith('journal:')]
    journal = [(m, c) for m, c in notes if m.get('title', '').startswith('journal:')]
    all_tags = {t for m, _ in notes for t in _meta_tags(m) if t not in STRUCTURAL_TAGS}

    body = [
        _stats_html(regular, journal, len(all_tags)),
    ]
    if cfg.get('show_calendar', True):
        body.append(_journal_section(notes, emojis))
    body.append(
        '<div class="section"><span class="fldr">{}</span><span>categories</span>'
        '<a class="more" href="tags.html">all tags →</a></div>'
        .format(ICONS['folder'])
    )
    body.append(build_tag_blocks(notes))
    if not regular and not journal:
        body.append('<p class="empty">no notes yet — write one in the noteout app and sync</p>')

    return page_shell('Home', '\n'.join(body), 'home', tree_html)


def _build_index_docs(notes, tree_html, cfg):
    """Docs-style home: hero, stats, search, notes grouped by category."""
    regular = [(m, c) for m, c in notes if not m.get('title', '').startswith('journal:')]
    journal = [(m, c) for m, c in notes if m.get('title', '').startswith('journal:')]
    all_tags = {t for m, _ in notes for t in _meta_tags(m) if t not in STRUCTURAL_TAGS}

    body = [
        _stats_html(regular, journal, len(all_tags)),
        '<div class="search-wrap">',
        f'<div class="search">{ICONS["search"]}<input class="searchbox" type="search" placeholder="Search notes…" aria-label="Search notes"></div>',
    ]
    if regular:
        body.extend(group_section_html(k, items, '', limit=4) for k, items in group_notes(regular))
    else:
        body.append('<p class="empty">no notes yet — write one in the noteout app and sync</p>')
    body.append('<p class="empty-search">no matching notes</p></div>')

    return page_shell('Home', '\n'.join(body), 'home', tree_html)



def build_journals_page(notes, tree_html, emojis):
    journal = [(m, c) for m, c in notes if m.get('title', '').startswith('journal:')]
    journal.sort(key=lambda x: x[0].get('title', ''), reverse=True)
    
    body = [
        '<h1 class="doctitle">Journals</h1>',
        _journal_section(notes, emojis),
        '<div class="search-wrap" style="margin-top: 30px">',
        f'<div class="search">{ICONS["search"]}<input class="searchbox" type="search" placeholder="Search journals…" aria-label="Search journals"></div>',
    ]
    if journal:
        cards = ''.join(card_html(m, c, '', dd=True) for m, c in journal)
        body.append(f'<div class="group"><div class="notes dd">{cards}</div></div>')
    else:
        body.append('<p class="empty">no journals yet</p>')
    body.append('<p class="empty-search">no matching notes</p></div>')
    return page_shell('Journals', '\n'.join(body), 'journals', tree_html)

def build_notes_page(notes, tree_html):
    """Generate notes.html listing all notes grouped by category."""
    regular = [(m, c) for m, c in notes if not m.get('title', '').startswith('journal:')]
    body = f'''
<h1 class="doctitle">All Notes</h1>
<div class="search-wrap">
  <div class="search">{ICONS['search']}<input class="searchbox" type="search" placeholder="Search notes…" aria-label="Search notes"></div>
  {'' if regular else '<p class="empty">no notes yet</p>'}
  {''.join(group_section_html(k, items, '') for k, items in group_notes(regular))}
  <p class="empty-search">no matching notes</p>
</div>'''
    return page_shell('Notes', body, 'notes', tree_html)


def build_tags_page(notes, tree_html):
    """Generate tags.html with the full folder tree."""
    root = build_tag_tree(notes)
    tree = render_tag_tree(root, notes, opened=True) if root else (
        '<p class="empty" style="margin:20px 0">no categories yet</p>')
    count = sum(1 for m, _ in notes if _primary_tag(m))
    body = f'''
<h1 class="doctitle">Categories</h1>
<div class="ttree" style="font-size:.98em">{tree}
</div>'''
    return page_shell('Categories', body, 'tags', tree_html)








def build_note(meta, content, all_notes, tree_html):
    """Generate an individual note HTML page."""
    title = meta.get('title', 'untitled')
    created = meta.get('created', '')[:10]
    tags = _meta_tags(meta)
    tags_html = ''.join(
        f'<a class="pill" href="{tag_href(t)}">#{html.escape(t)}</a>'
        for t in tags
    )
    body_html = simple_md(content)

    outgoing = re.findall(r'\[\[([^\]]+)\]\]', content)
    links_html = ''
    if outgoing:
        link_items = ' '.join(
            f'<a href="{slug(link)}.html" class="wiki-link">[[{html.escape(link)}]]</a>'
            for link in outgoing
        )
        links_html = f'<div class="links"><h3>linked notes</h3>{link_items}</div>'

    primary = _primary_tag(meta)
    if primary:
        crumbs = crumbs_html([
            ('Notes', 'notes.html', False),
            (primary, tag_href(primary), False),
            (title, None, True),
        ])
    else:
        crumbs = crumbs_html([
            ('Notes', 'notes.html', False),
            (title, None, True),
        ])

    body = f'''{crumbs}
<h1 class="doctitle">{html.escape(title)}</h1>
<div class="meta-line">{tags_html}</div>
<article>{body_html}</article>
{links_html}'''
    return page_shell(title, body, 'notes', tree_html)


def build_tag_page(tag, notes, root, tree_html):
    """Generate tag page (e.g. tag-project/alpha.html) listing notes."""
    prefix = prefix_for(tag)
    sidebar_tree = render_tag_tree(root, notes, href_prefix=prefix)
    matches = [(m, c) for m, c in notes if _tag_match(m, tag)]
    label = ' / '.join(html.escape(p) for p in tag.split('/'))
    cards = ''.join(card_html(m, c, prefix, exclude=(tag,)) for m, c in matches)
    crumbs = crumbs_html([
        ('Categories', 'tags.html', False),
        (tag.split('/')[-1], None, True),
    ], prefix=prefix)
    body = f'''{crumbs}
<h1 class="doctitle">#{label}</h1>
<p class="docsub">{len(matches)} note{'s' if len(matches) != 1 else ''} in this category</p>
<div class="notes">{cards if cards else '<p class="empty">no notes in this category</p>'}</div>'''
    return page_shell(f'#{tag}', body, 'tags', sidebar_tree, prefix=prefix)


def build_readme(notes, emojis):
    """Generate README.md."""
    cfg = get_config()
    regular = [(m, c) for m, c in notes if not m.get('title', '').startswith('journal:')]
    journal = [(m, c) for m, c in notes if m.get('title', '').startswith('journal:')]

    lines = [
        f'# {cfg["name"]}"s notes',
        '',
        'a personal notes site, built with noteout.',
        '',
        '---',
        '',
        '## notes',
        '',
    ]
    if not regular:
        lines.append('_no notes yet_')
    else:
        for k, items in group_notes(regular):
            tag_note = f' — `#{k}`' if k else ''
            lines.append(f'### {k or "Uncategorized"}{tag_note}')
            lines.append('')
            for meta, content in items:
                title = meta.get('title', 'untitled')
                s = slug(title)
                created = meta.get('created', '')[:10]
                lines.append(f'- [{title}]({s}.html) — {created}')
            lines.append('')

    if journal:
        lines.extend(['## journal', ''])
        for meta, content in journal:
            title = meta.get('title', '')
            date_str = title.replace('journal:', '')
            emoji = emojis.get(date_str, '')
            s = slug(title)
            lines.append(f'- [{emoji} {date_str}]({s}.html)')
        lines.append('')

    lines.extend([
        '---',
        '',
        '*built with noteout*',
    ])
    return '\n'.join(lines)


def main():
    SITE_DIR.mkdir(exist_ok=True)
    (SITE_DIR / 'notes').mkdir(exist_ok=True)

    emojis = load_emojis()
    notes = []

    if NOTES_DIR.exists():
        for md_file in sorted(NOTES_DIR.glob('*.md')):
            raw = md_file.read_text(encoding='utf-8')
            meta, content = parse_frontmatter(raw)
            if not meta.get('title'):
                continue
            notes.append((meta, content))
            (SITE_DIR / 'notes' / md_file.name).write_text(raw, encoding='utf-8')

    # sort by created date, newest first
    notes.sort(key=lambda x: x[0].get('created', ''), reverse=True)

    tree_html = render_tag_tree(build_tag_tree(notes), notes)
    root = build_tag_tree(notes)

    (SITE_DIR / 'index.html').write_text(
        build_index(notes, tree_html, emojis), encoding='utf-8')
    (SITE_DIR / 'notes.html').write_text(build_notes_page(notes, tree_html), encoding='utf-8')
    (SITE_DIR / 'tags.html').write_text(build_tags_page(notes, tree_html), encoding='utf-8')
    (SITE_DIR / 'journals.html').write_text(build_journals_page(notes, tree_html, emojis), encoding='utf-8')
    (SITE_DIR / 'README.md').write_text(build_readme(notes, emojis), encoding='utf-8')

    for meta, content in notes:
        title = meta.get('title', '')
        if not title:
            continue
        s = slug(title)
        (SITE_DIR / f'{s}.html').write_text(
            build_note(meta, content, notes, tree_html), encoding='utf-8')

    # per-tag pages
    all_tags = {
        t
        for meta, _ in notes
        for t in _meta_tags(meta)
        if t not in STRUCTURAL_TAGS
    }
    for tag in all_tags:
        page_path = SITE_DIR / tag_href(tag)
        page_path.parent.mkdir(parents=True, exist_ok=True)
        page_path.write_text(
            build_tag_page(tag, notes, root, tree_html), encoding='utf-8')

    print(f' built docs site: {len(notes)} notes -> {SITE_DIR}/')


if __name__ == '__main__':
    main()