# 狗哩狗哩 —— Roku 上的 B 站客户端

在 Roku 电视上看 B 站的客户端。**全部运行在电视上**，不需要电脑开着；电脑只在安装和更新时用一下。

功能：首页（推荐 / 热门 / 排行 / 历史，带发布时间）、搜索（拼音联想）、详情页（分 P、相关推荐、断点续播）、播放器、弹幕（开关、不透明度）、扫码登录（登录后 1080P）、观看进度与 B 站账号双向同步、在电视上删除观看历史、主题色可选（黄 / 粉 / 蓝 / 绿 / 紫）。

> **非官方项目**，与哔哩哔哩（上海宽娱数码科技有限公司）没有任何关系。只调用 B 站网页版本来就开放的接口，用你自己的账号登录，仅供个人学习和自用。请遵守 B 站用户协议，不要用于商业用途。

## 安装

电视先开开发者模式（遥控器按 Home ×3、上 ×2、右、左、右、左、右），设好密码后，把电视地址和密码写进 `.env.local`（不会进 git）：

```bash
cp .env.example .env.local   # 然后改成你电视的 IP 和开发者密码
```

然后：

```bash
scripts/deploy.sh
```

## 遥控器

| 位置 | 操作 |
| --- | --- |
| 首页标签栏 | 左右切换，下进入视频，OK 在「推荐」上换一批；「设置」里改主题色和弹幕默认值 |
| 首页视频 | 上 / 返回 回到标签栏，`*` 刷新；往下翻会自动加载更多（历史也是） |
| 历史 | 在视频上按 `*`：从观看历史中删除，或清空全部（会再确认一次，默认选「取消」） |
| 详情页 | 下 = 相关推荐，右 = 选集 |
| 播放器 | **OK = 暂停 / 继续**，左右快进快退，**下 = 弹幕设置**，上 = 显示标题，返回退出（自动记进度） |
| 搜索 | 可以输拼音首字母，比如 `ys`，下方会出现「原神」 |

播放时 `*` 键会被 Roku 电视系统拿去开画面设置，所以弹幕设置放在「下」键。OK 键按下时会被系统播放器拿走，所以暂停是在松开 OK 时触发的。

## 登录（1080P）

「我的」→ 用 B 站手机客户端扫码。未登录最高 720P（MP4），登录后走 DASH 最高 1080P。Cookie 只存在电视的本地存储里。

登录后观看进度和账号同步：
- 电视上播放时，每 30 秒以及退出 / 播完时把进度上报到 B 站历史（`/x/v2/history/report`），手机上的历史记录里也能看到。
- 打开视频时，如果这台电视没看过，就去读账号里的进度（`/x/player/wbi/v2` 的 `last_play_time` / `last_play_cid`），从别的设备看到的地方继续，分 P 视频会定位到对应的那一集。电视自己的进度优先。

## 从电脑投屏

```bash
scripts/cast.sh "https://www.bilibili.com/video/BV1GJ411x7h7"
```

## 它是怎么在电视上自己跑起来的

- **接口**：`components/bili/` 里的 `BiliTask` 在后台线程直接请求 B 站：自己拿 buvid Cookie、算 WBI 签名（`roEVPDigest` MD5）、把超过 32 位的 aid/cid 先转成字符串再解析 JSON。
- **视频**：B 站 CDN 不带 Referer 就返回 403，播放器的 `HttpHeaders` 会把 Referer 带上。MP4 直接播；DASH 的清单 Roku 只接受 HTTP 地址，所以频道里有个 `ManifestServer` 在 `127.0.0.1` 上提供清单，视频分段仍然直接从 CDN 拉。B 站把 1080P 的 H.264 标成 Level 5.0（`avc1.640032`），这台电视只认到 4.2，会把整档悄悄丢掉、一直停在 720P，所以清单里把级别写成 4.2（实际解码没问题）。
- **登录**：扫码确认后，B 站只通过响应头 `Set-Cookie` 下发 `SESSDATA` 等，`roUrlEvent.GetResponseHeadersArray()` 能拿到重复的 `Set-Cookie`。
- **登录二维码**：`bili/qr.brs` 是电视上的二维码生成器。不能用网上的二维码服务——登录链接里带着 key，谁拿到谁就能拿到登录态。
- **弹幕**：`widgets/DanmakuLayer` 用对象池 + SceneGraph 动画滚动（渲染线程负责移动），按视频时间放出、分轨道防重叠。
- **中文字体**：Roku 系统字体没有中文，频道带了一个约 1 万字的子集字体（`channel/fonts/cjk.otf`），旁边的 `cjk.cov` 是字形覆盖表，标题里字体画不出的字符（emoji 等）会被去掉，免得显示成方块。字体是 Adobe 思源宋体的子集，按 SIL Open Font License 1.1 再分发，许可证见 [`channel/fonts/OFL.txt`](channel/fonts/OFL.txt)；因为改动过（子集化），按许可证要求改名为 "BiliTV CJK"。

## 主题色和图标

主题色在 `channel/components/common/utils.brs` 的 `themes()` 里定义，每种颜色对应一套焦点框、胶囊按钮、加载圈图片（`*_<主题>.9.png`），由 `scripts/make-art.py` 里的 `THEMES` 生成，两边要保持一致。默认是黄色。图标和启动画面是一只白色小狗，也由这个脚本画出来。

## 开发

```bash
scripts/deploy.sh screenshot            # 电视截图到 build/screen.jpg（不含视频画面）
python3 scripts/console.py 30           # 看 BrightScript 调试输出 30 秒
python3 scripts/remote.py Down Select 2 Back   # 用 ECP 模拟遥控器
```

重新生成字体或图片（需要 fonttools / Pillow）：

```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install -r tools/requirements.txt
tools/.venv/bin/python scripts/make-font.py path/to/SourceHanSans-or-NotoSansSC.otf
tools/.venv/bin/python scripts/make-art.py
```

写 BrightScript 时注意：它不区分大小写，而且 `pos`、`tab`、`box`、`dim`、`right`、`run` 这类内置函数名不能当变量名。

## 目录

```
channel/components/bili/      B 站客户端：http.brs（Cookie/签名）、ops.brs（各接口）、media.brs（选码流/MPD）、qr.brs、text.brs
channel/components/common/    utils.brs、ManifestServer（本地清单服务）
channel/components/screens/   首页、详情、播放器、搜索、登录
channel/components/widgets/   VideoCard、DanmakuLayer、DanmakuPanel
scripts/                      deploy / cast / console / remote / make-font / make-art
```
