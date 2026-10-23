# 狗哩狗哩 (Gouli Gouli) — a Bilibili client for Roku

[中文](README.md) | English

Watch Bilibili on a Roku TV. **Everything runs on the TV itself** — no computer needs to stay on; you only use one to install and update the channel.

Features: home feeds (recommended / popular / ranking / history, with publish dates), search with pinyin suggestions, favourites, video pages (multi-part videos, related videos, resume), player, danmaku (on/off, opacity), QR-code login (1080P when logged in), two-way watch-progress sync with your Bilibili account, deleting watch history from the TV, theme colours (yellow / pink / blue / green / purple) and fonts (Kai / Hei / Song).

The interface is in Chinese, as is Bilibili.

> **Unofficial project**, not affiliated with Bilibili (Shanghai Kuanyu Digital Technology Co., Ltd.) in any way. It only calls the endpoints Bilibili's own website already uses, with your own account, for personal and educational use. Please follow Bilibili's terms of service and don't use it commercially.

## Install

Enable developer mode on the TV (remote: Home ×3, Up ×2, Right, Left, Right, Left, Right) and set a password. Then put the TV's address and that password in `.env.local` (ignored by git):

```bash
cp .env.example .env.local   # then fill in your TV's IP and developer password
```

and run:

```bash
scripts/deploy.sh
```

## Home tabs

| Tab | What it shows |
| --- | --- |
| 推荐 Recommended | Bilibili's home feed — personalised once you log in; OK loads a fresh batch |
| 热门 Popular | Bilibili's "综合热门": what is trending in the last day or two; updates often and scrolls on and on |
| 排行 Ranking | Bilibili's site-wide chart: the 100 videos that did best over the last few days by overall score (views, coins, likes…), refreshed about daily |
| 历史 History | Your watch history with how far you got; `*` deletes one entry or clears it all |
| 搜索 Search | OK opens search |
| 我的 Me | Logged out: the login QR code right there. Logged in: the videos in your favourites; `*` switches folder or logs out |
| 设置 Settings | Theme colour, font and danmaku defaults — press Down to go in and change them in place |

## Remote

| Where | Keys |
| --- | --- |
| Tab bar | Left/Right switch tabs, Down enters the content |
| Video grid | Up / Back return to the tab bar, `*` refreshes (on History and Me `*` opens a menu); scrolling down loads more |
| Settings | Up/Down pick a row, Left/Right change it, applied immediately; Up on the first row returns to the tab bar |
| Video page | Down = related videos, Right = parts |
| Player | **OK = pause / resume**, Left/Right seek, **Down = danmaku settings**, Up = show title, Back exits (progress is saved) |
| Search | Type pinyin initials, e.g. `ys`, and suggestions such as 原神 appear below |

Deleting or clearing history and logging out all ask for confirmation, with Cancel selected by default. During playback a Roku TV keeps the `*` key for its own picture menu, so danmaku settings live on Down; the system player also swallows the OK press, so pause triggers when OK is released.

## Login (1080P)

On the 我的 tab, scan the QR code with the Bilibili phone app. Logged out, playback tops out at 720P (MP4); logged in, it uses DASH up to 1080P. Cookies are stored only in the TV's local storage.

Once logged in, watch progress syncs with the account:
- While playing on the TV, progress is reported to your Bilibili history every 30 seconds and when you leave or finish (`/x/v2/history/report`), so it shows up on your phone too.
- When you open a video this TV hasn't played, it reads the account's position (`last_play_time` / `last_play_cid` from `/x/player/wbi/v2`) and resumes where another device left off, including the right part of multi-part videos. The TV's own bookmark wins when it has one.

## Cast from a computer

```bash
scripts/cast.sh "https://www.bilibili.com/video/BV1GJ411x7h7"
```

## How it runs on the TV alone

- **API**: `BiliTask` in `components/bili/` calls Bilibili from background threads: it mints its own buvid cookies, computes the WBI signature (MD5 via `roEVPDigest`), and quotes aid/cid values wider than 32 bits before parsing JSON.
- **Video**: Bilibili's CDN answers 403 without a Referer, so the player sends one through `HttpHeaders`. MP4 plays directly. Roku only accepts a DASH manifest over HTTP, so the channel runs a small `ManifestServer` on `127.0.0.1` to hand it the MPD; segments still come straight from the CDN. Bilibili labels its 1080P H.264 as Level 5.0 (`avc1.640032`); this TV only advertises up to 4.2 and silently drops that rendition, staying at 720P, so the manifest declares 4.2 (it decodes fine).
- **Login**: after the scan is confirmed, Bilibili hands over `SESSDATA` and friends only as `Set-Cookie` response headers; `roUrlEvent.GetResponseHeadersArray()` keeps the repeated `Set-Cookie` lines.
- **Login QR code**: `bili/qr.brs` is a QR encoder that runs on the TV. An online QR service is not an option — the login URL carries the key, and whoever holds it can take over the session.
- **Danmaku**: `widgets/DanmakuLayer` pools labels and moves each one with a SceneGraph animation (the render thread does the motion), releasing comments by video time into lanes so they don't overlap.
- **Chinese fonts**: Roku's system font has no CJK glyphs, so the channel ships three ~10,000-character subsets, switchable in Settings (the home screen is rebuilt after a change). The `.cov` file next to each font is a glyph-coverage bitmap; characters the font can't draw (emoji etc.) are stripped from titles instead of showing as boxes. All three are redistributed under the SIL Open Font License 1.1; because the originals reserve their names, the subsets are renamed "Gouli Kai / Hei / Song" as the licence requires:

  | In Settings | File | Original font | Licence |
  | --- | --- | --- | --- |
  | 楷体 Kai (default) | `channel/fonts/kai.ttf` | LXGW WenKai 霞鹜文楷 | [`OFL-LXGWWenKai.txt`](channel/fonts/OFL-LXGWWenKai.txt) |
  | 黑体 Hei | `channel/fonts/hei.ttf` | Noto Sans SC (Regular) | [`OFL-NotoSansSC.txt`](channel/fonts/OFL-NotoSansSC.txt) |
  | 宋体 Song | `channel/fonts/song.otf` | Source Han Serif 思源宋体 | [`OFL-SourceHanSerif.txt`](channel/fonts/OFL-SourceHanSerif.txt) |

## Theme colours and artwork

Themes are defined in `themes()` in `channel/components/common/utils.brs`. Each colour has its own focus ring, pill button and spinner images (`*_<theme>.9.png`), drawn by `THEMES` in `scripts/make-art.py` — keep the two in step. Yellow is the default. The icon and splash screen (a white puppy) come from the same script.

## Development

```bash
scripts/deploy.sh screenshot            # TV screenshot to build/screen.jpg (video plane not included)
python3 scripts/console.py 30           # BrightScript debug console for 30 seconds
python3 scripts/remote.py Down Select 2 Back   # drive the TV over ECP
```

Regenerating fonts or artwork (needs fonttools / Pillow):

```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
tools/.venv/bin/python scripts/make-font.py path/to/LXGWWenKai-Regular.ttf kai   # second argument: kai / hei / song
tools/.venv/bin/python scripts/make-art.py
```

BrightScript gotchas: it is case-insensitive, and built-in function names such as `pos`, `tab`, `box`, `dim`, `mid`, `right` and `run` cannot be used as variable names.

## Layout

```
channel/components/bili/      Bilibili client: http.brs (cookies/signing), ops.brs (endpoints), media.brs (streams/MPD), qr.brs, text.brs
channel/components/common/    utils.brs (themes, fonts, helpers), ManifestServer (loopback manifest server)
channel/components/screens/   home, video page, player, search
channel/components/widgets/   VideoCard, DanmakuLayer, DanmakuPanel, ActionMenu, LoginPanel, SettingsPanel
scripts/                      deploy / cast / console / remote / make-font / make-art
```
