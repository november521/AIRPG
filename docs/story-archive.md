# 故事档案界面交付

## 最新改版（2026-09-28，用户已确认观感无问题）

布局改为左侧 24% 固定档案栏、右侧全幅场景，返回按钮位于左上，移除左侧及详情序号。
标题、标签、简介分别为 components/story_title、story_tags、story_description 原生组件，
由 story_details 组合；卡片复用标题和标签。场景负责布局，内容仍来自目录与本地化。
三个开发占位“山间驿站 / 旧城来信 / 海岸迷雾”仅用于查看多故事列表和切换效果，
使用明确标注的渐变美术占位，不含正式剧情。进入按钮禁用，应用层同样拒绝占位 ID。
配置位于 data/stories/preview_catalog.json；app.json 的 story_archive_placeholders
可关闭它们。发布构建无论该开关如何均不显示。正式 catalog.json 仍只有 deadlight。
详见 ADR 0004。当前用户已接管后续测试；下方旧交付描述属于上一轮历史记录。


日期：2026-09-28。分支 `feature/story-archive`。起点为主菜单 `fb2272c`。
实际 Godot 项目：`C:/Users/31286/Desktop/AIRPG/.tools/worktrees/start-screen/game/project.godot`。
本轮不合并 main、不推送，不改主工作区。

## 完成范围

- 主菜单开始 → 档案页 → 返回；返回不重复播放完整主菜单开场。
- 默认唯一正式配置故事 deadlight；名称、简介、标签完全采用用户给定文本。
- 1920×1080 原生 Control 设计画布，等比适配并居中留边；左侧列表约 28%，
  右侧大幅插画约 70%。没有主菜单 Logo/星轨，也没有虚构待开放故事。
- 封面列表可滚动；选中指示与悬停光效 220 ms；鼠标悬停不擅自改变选择。
- 键盘焦点选择故事，方向键/Tab 导航、Enter 激活焦点按钮、Esc 或返回按钮回主菜单。
- 预览切换先淡出 220 ms、替换全部信息、再淡入 230 ms，快速切换取消旧 Tween。
- 页面进入/返回分别是旧页 250 ms + 新页 250 ms；开始按钮有短反馈并淡出后调用端口。
- 启动失败会显示本地化提示并淡入恢复，可继续操作，重复点击和动画中退出不能重复提交。
- 缺图、空目录、目录错误有明确降级；长简介可滚动，不覆盖启动按钮。

## 明确没有实现

按第五/六节及后续范围说明，没有动态天气或音频；插画本身描绘静态雨夜。
没有故事存档、角色创建、同行者、AI 请求、检定、剧情状态结算、实际《死光》游玩流程。
目录元数据不是可玩内容包，生成插画不是官方模组原图或已审定的全部场景设定。
生产启动端口返回 STORY_START_UNAVAILABLE，不将测试替身或灰盒当作实际故事。

## 数据与启动接口

配置：`game/data/stories/catalog.json`（schema_version=1）。
每项包含 id、title_key、description_key、tag_keys、art_key、accent（RGB 三个 0–1 数值）。
文本放 `game/data/localization/zh_CN.json`。
图片放项目内并在 `game/presentation/story_archive/art/story_art_library.tres` 登记 Texture2D；
资源表可由编辑器维护并参与导出依赖图。JSON 不携带资源路径、不允许脚本执行。
新增故事无须改 UI、应用用例或 bootstrap 代码；同一图片可被多个条目引用。
未知美术 key 显示缺图提示。资源表直接引用的文件缺失属于工程资源错误，不能绕过导入检查。

UI 只接收 StoryArchiveService 和只读美术映射；Service 只允许目录中的 ID 调用
StoryLauncher.start_story(id)。替换实际启动实现时只由 bootstrap 注入。
同步成功意味着新流程接管页面；同步失败必须无状态副作用。
未来异步启动必须单独扩展取消与终止协议，不能把未完成的后台启动返回假成功。
参见 ADR 0003 与 contracts.md。

## 新增及修改文件清单

新增（所有 .gd 均附 .gd.uid）：

- game/application/ports/story_launcher.gd
- game/application/story_archive/story_archive_service.gd
- game/domain/content/story_catalog.gd
- game/bootstrap/story_archive_composition.gd
- game/data/stories/catalog.json
- game/data/schemas/story_catalog.schema.json
- game/presentation/story_archive/story_archive.gd 与 .tscn
- game/presentation/story_archive/story_card.gd 与 .tscn
- game/presentation/story_archive/story_preview.gd 与 .tscn
- game/presentation/story_archive/art/archive_theme.tres
- game/presentation/story_archive/art/story_art_library.gd 与 .tres
- game/presentation/story_archive/art/deadlight_road_v1.png 与 .png.import
- game/tests/story_archive/test_story_archive.gd
- game/tests/story_archive/run_story_archive_tests.gd
- docs/adr/0003-story-archive-launch-boundary.md
- docs/story-archive.md

修改：

- game/bootstrap/composition.gd：组装档案服务与美术表。
- game/bootstrap/main.gd：路由注册、注入、返回菜单短过渡。
- game/presentation/menu/start_screen.gd：仅开始路由/返回开场处理，不改美术和布局。
- game/data/localization/zh_CN.json：界面与故事信息键。
- game/tests/run_tests.gd：登记新套件，并修正旧主页属性断言为当前主页节点断言。
- scripts/verify.ps1：要求非空 ARCHIVE_TESTS 完成标记，不放宽原检查。
- docs/contracts.md、docs/testing.md、docs/handoff.md：契约、验证与接续记录。

本地运行产物（不提交）：artifacts/story-archive-running.png、archive-tests.engine.log、
archive-gui*.engine.log，以及统一入口的 import/tests/boot 日志。

## 美术来源与完整生成提示词

项目原有素材只包含主菜单 Logo/烟雾，没有死光道路插画。本轮使用内置 image_gen
（非 CLI、无项目 API 密钥）按用户文字需求新生成 1672×941 场景图，
已人工查看年代风格、车灯、冷蓝灰雨夜构图；不冒称原始授权美术或正式地图。
保存路径为 game/presentation/story_archive/art/deadlight_road_v1.png。
同一图用于封面和大图，文字/按钮均为真实原生 UI，不烧进图片。

```text
Use case: historical-scene. Asset type: finished game story archive environment illustration, not a UI mockup. Wide 16:9 landscape painting for AIRPG. Scene: a remote rural road at night in torrential rain, bordered by dense dark woods. One broken-down early 1920s touring automobile pulled onto the roadside, viewed three-quarter front, with narrow tires, separate rounded fenders, upright windshield and two round dim warm-white headlights reflecting in puddles. No people. Far down the road a very faint ambiguous pale glow behind mist, not a creature and not a clearly defined event. Semi-realistic vintage digital illustration, cinematic noir composition, richly detailed wet ground and branches, cold blue-gray palette with small restrained warm gold headlight accents. Place car and most readable road detail in upper middle/right area; lower quarter dark natural wet-road negative space for later live UI text, not text inside image. Legible shapes with shadow detail, not an almost completely black image. Oppressive, mysterious, unknown fear. No modern cars, no modern road markings, no extra characters, no houses, no signs, no text, no logos, no watermarks, no frames, no menus. This is original illustrative preview art, not a copy of any existing game artwork.
```

## 验证结果与限制

独立故事档案 50 checks / 0 failures；统一入口 713 checks / 0 failures；
架构 104 文件 + 3 个负向用例；固定 Godot 4.7.2 导入与离线启动通过。
检查命令、分项数量与图形操作记录见 docs/testing.md。

图形检查实际完成鼠标进入、键盘启动拒绝反馈、Esc 返回、鼠标返回、窗口放大；
截图来自运行中的 Godot 窗口，而非生成的 UI 概念图。
没有做导出包、低配长时间性能、全部 DPI/字体环境、独立对抗或逐像素视觉回归。
新页面没有每帧天气/粒子/音频处理，运行时资源释放由节点与绑定 Tween 生命周期管理。

独立复核重点：高 DPI 字体可读性、更多条目滚动与焦点、极长本地化文本、
动画中退出和重复确认、真实启动端口接管责任、导出美术资源和失败不推进状态。
