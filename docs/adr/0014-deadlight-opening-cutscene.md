# ADR 0014：进入《死光》先播开场动画的门

日期：2026-10-04。状态：已实施（本机 + CI 验证）。工作包：开场动画接入 / 负责人本任务 / 独立对抗复核待分配。

## 背景

用户交付了一段 20 秒的《死光》开场动画（1280×720、24 fps、H.264 + AAC、3.7 MB），要求
「玩家在点进死光这个副本后，先展示一段开场动画再进入游戏」。

工程此前的进入链路是：故事档案里点「进入庄园原型」→ `StoryArchive` 的 `_dispatch` 调
`story_archive.request_start("deadlight")` → `ManorLauncher`（注入的本地发射器）→ `bootstrap/main.gd`
的 `_launch_creation()` → 建卡页 → 确认后 `route_requested.emit("manor")` → 庄园。整条链路里没有任何
视频播放能力，也没有资源级的视频文件。

## 决定

1. **格式**：Godot 的 `VideoStreamPlayer` 只吃 **Ogg Theora**（+ Vorbis），不支持 MP4/H.264。因此把源片
   转码为 `game/presentation/cinematic/deadlight_opening.ogv`（theora q6 / vorbis q4，转码后 3.9 MB，
   与源片同量级）。**保留 1280×720 与 24 fps**，与工程 1920×1080 设计尺寸匹配，不做二次缩放。
   转码命令记录在 `docs/cinematic-assets.md`，便于日后替换素材时复现。
2. **门的位置**：把注入给 `ManorLauncher` 的回调从 `_launch_creation` 换成 `_launch_deadlight`。
   档案的 `request_start("deadlight")` 因此先落到新增的 `cutscene` 路由；开场结束后才继续原来的
   建卡 → 庄园链路。**每次从档案进入副本都会播**（符合「点进副本后先展示」的字面要求），不做持久化
   「已看过」标记——那属于存档格式改动，需要单独 ADR。
3. **视图**：新增 `presentation/cinematic/opening_cutscene.gd` + `.tscn`。它只拥有播放器、跳过按钮、
   提示行和一个守护计时器；**不自己做路由**，结束时只发 `finished` 信号，由 `bootstrap/main.gd`
   决定后续。这保持了既有的「视图不导航、bootstrap 决定去向」结构。
4. **跳过**：按钮（本地化 `cutscene.skip`）+ Esc / Enter / Space / K 键 + 鼠标点击。**移动键（WASD）刻意
   不跳过**：玩家按着 W 进场时仍应看到开场。跳过是幂等的——跳过、播完、守护超时三条路径都收敛到
   同一个 `skip()`，因此实例只会被进入一次。
5. **失败开放（fail-open）**：无头运行不播放（`configure(playback_enabled)` 由 bootstrap 按
   `DisplayServer.get_name()` 传入），视频流为空或视图像素不可用时也直接 `skip()`；若 `cutscene`
   路由本身不可用，`_launch_deadlight()` 直接走原来的 `_launch_creation()`。**开场动画坏掉不能
   让玩家进不去副本**，这是本 ADR 最关键的取舍。
6. **守护计时器**：`stream_length + 5 s` 的 one-shot `Timer`，防止解码卡死把玩家永久锁在开场画面。

## 兼容性

- 新增一条路由（`cutscene`）与一个视图；`main.gd` 的进入链路只多一跳，建卡与庄园逻辑不变。
- 新增两个本地化键（`cutscene.skip`、`cutscene.hint`），无硬编码文本。
- 视频资源以**路径** `preload` 引用，`.tscn` 不引用它：资源 uid 不参与引用，因此不需要提交
  `deadlight_opening.ogv.uid`（仓库对非脚本资源本就不提交 uid，与 `game/audio/**` 一致）。

## 未决与复核重点

素材来源与许可：影片由用户提供，工程不掌握其版权状态；`docs/cinematic-assets.md` 只记录来源与转码
参数，**对外分发/上架前必须由用户确认授权**。此外未实现：字幕/多语言音轨、跳过后的黑屏淡出、把
「已看过」写进存档、开场动画与庄园音乐的交叉淡入淡出（当前进入开场即 `set_music("")` 停掉菜单床）。
