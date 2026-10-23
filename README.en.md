# 狗哩狗哩 (Gouli Gouli) — a Bilibili client for Roku

[中文](README.md) | English

Watch Bilibili directly on a Roku TV. **The app runs entirely on the TV by itself** — no computer or server has to stay on; you only need a computer to install it the first time and to update it later.

- Home: recommended, popular and ranking, with every video's publish date
- Search with pinyin-initial suggestions (type `ys` and 原神 comes up)
- QR-code login, up to 1080P when logged in
- Me: your account info and favourites
- Watch history, which you can delete from the TV
- Danmaku (bullet comments) with on/off and opacity
- Watch progress syncs with your Bilibili account both ways: stop on the TV and continue on your phone, or the other way round
- Multi-part videos, related videos, resume playback
- Theme colour (yellow / pink / blue / green / purple) and font (Kai / Hei / Song) in Settings

The interface is in Chinese, as is Bilibili.

> **Unofficial project**, not affiliated with Bilibili (Shanghai Kuanyu Digital Technology Co., Ltd.) in any way; for personal and educational use only. It uses your own Bilibili account — please follow Bilibili's terms of service and don't use it commercially.

## Install

You need a Roku TV or Roku player and a computer (macOS or Linux) on the same Wi-Fi.

1. **Enable developer mode on the TV**: on the remote press Home ×3, Up ×2, Right, Left, Right, Left, Right, follow the prompts to enable it, and set a developer password. The screen shows the TV's IP address.
2. **Get this project** and fill in your TV's details from the project folder:

   ```bash
   cp .env.example .env.local
   ```

   Then open `.env.local` and set `ROKU_IP` to the TV's IP address and `ROKU_PASS` to the developer password you just set.
3. **Install it on the TV**:

   ```bash
   scripts/deploy.sh
   ```

   The app opens by itself when the install finishes, and 狗哩狗哩 stays on the Roku home screen. To update after pulling new code, run the same command again.

## Using it

### Home tabs

| Tab | What it shows |
| --- | --- |
| 推荐 Recommended | Bilibili's home feed, personalised once you log in; press OK on the tab for a fresh batch |
| 热门 Popular | What is trending right now; updates often and keeps scrolling |
| 排行 Ranking | The site-wide chart: the 100 videos that did best over the last few days, refreshed about daily |
| 历史 History | Your watch history with how far you got |
| 搜索 Search | Press OK to open search |
| 我的 Me | Logged out: the login QR code. Logged in: your account info on top and your favourite folders below — open a folder to see its videos |
| 设置 Settings | Theme colour, font, danmaku default and opacity — press Down to go in and change them in place |

### Remote

| Where | Keys |
| --- | --- |
| Tab bar | Left/Right switch tabs, Down enters the content |
| Video lists | Scrolling down loads more; Up or Back returns to the tab bar; `*` refreshes |
| History | `*` on a video: delete that entry, or clear all history |
| Me | `*`: refresh, or log out |
| Settings | Up/Down pick a row, Left/Right change it, applied immediately |
| Video page | Down for related videos, Right for parts |
| Player | **OK pauses / resumes**, Left/Right seek, **Down opens danmaku settings**, Up shows the title, Back exits (your position is saved) |
| Search | Type on the on-screen keyboard; pinyin initials work |

Deleting or clearing history and logging out ask for confirmation, with Cancel selected by default.

### Logging in

Open 我的 and scan the QR code on screen with the Bilibili phone app, then confirm on the phone. Logged out, playback tops out at 720P; logged in, 1080P. Your login is stored only on this TV.

Once you are logged in, watch progress syncs with your account: what you watch on the TV shows up in your phone's history, and a video you half-watched on another device continues from there when you open it on the TV.

### Cast a video from your computer

```bash
scripts/cast.sh "https://www.bilibili.com/video/BV1GJ411x7h7"
```

The TV opens that video and starts playing it.

## Fonts

The interface uses subsets of LXGW WenKai, Noto Sans SC and Source Han Serif, all under the SIL Open Font License 1.1; the licences are in [`channel/fonts/`](channel/fonts/).
