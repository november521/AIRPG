# NPC 绑定与动作原型

更新：2026-10-03。工作包 C-NPC-RIG，负责人本任务，独立复核待分配。范围为庄园原型 NPC 的视觉绑定、移动动画、面对玩家和相关回归；对应 PRD 8.1、9.1、10.4、14.2。正式《死光》人物资料、台词和剧情状态仍待授权正文导入。

2026-10-03 追加：两个“身份待确认”预览 NPC 改用基础绑定模型 `npc_preview_basic_rig.glb`，见“资产与重建”。文末保留 C-NPC-RIG 原始程序几何占位模型的记录，其“公开仓库只用原创几何”的取舍已被本轮用户决定取代，取舍与后果见 [ADR 0010](adr/0010-npc-rig-asset-substitution.md)。

## 资产与重建

游戏内 NPC 视觉现在是 `game/presentation/manor/npc_preview_basic_rig.glb`，与交付文件 `output/npc_basic_rig/mujer_sexy_rigged.glb` 逐字节一致：

- GLB SHA-256 `905fb38d1460fbf5ad38fa1284ebaafd5793a3e1f3621122678308d2b55008e3`，2 478 900 字节。
- 1 个蒙皮网格，29 495 顶点 / 49 986 三角面；1 张内嵌 JPEG 贴图，Godot 用 `embedded_image_handling=1` 抽取为 `npc_preview_basic_rig_Image_0.jpg`（500 448 字节，SHA-256 `65cb23dc7c59e606604df33cad5bbed7039df22a7694e6cb2fb110b088e1f479`）。
- 23 根骨骼（Root + 22 变形骨），6 段动作：idle 2.0 s、walk 1.067 s、run 0.733 s、sit_down 1.0 s、sit_idle 2.0 s、stand_up 1.0 s。
- 身高规整为约 1.75 米，脚底在本地原点，骨骼本地朝向 +Z（脚踝→脚掌的水平分量约 +0.91 Z）。
- 上游网格与贴图来自 Sketchfab Standard 许可的 `mujer_sexy.glb`（输入 SHA-256 `78ae294fcee181406547f8d5af2d6a490fd045e368313ce361c66ceded144ad2`，与本机 `game/presentation/manor/mujer_sexy.glb` 相同）。绑定过程、权重和循环检查见 `output/npc_basic_rig/rig_report.json`。

用户在本轮明确选择把该绑定模型提交进本仓库，因此不再要求“公开仓库只用原创程序几何”。原来为此生成的 `game/presentation/manor/npc_preview_public.glb`（17 骨、idle/talk/walk、无贴图）及其生成脚本 `scripts/assets/build_npc_public.py` 仍保留在仓库中，但已不被任何场景引用，可作回退视觉。重建公开占位模型的命令仍为：

`blender -b -t 2 --python scripts/assets/build_npc_public.py`

## 运行与边界

`NpcActor.configure` 用 `preload` 显式实例化该 GLB，检查 `AnimationPlayer`、`NPC_Rig/Skeleton3D`、23 根骨骼、`NPC_Rig/Skeleton3D/NPC_Body` 的 Skin 以及状态到动作的映射；缺失时庄园启动报 `NPC_VISUAL_INVALID` 并停止场景更新。动作由真实物理位移与 `NpcPresence.paused` 决定，根节点碰撞体是位移权威，GLB 不使用根运动。朝向以实际位移平滑转动，交谈时转向玩家，关闭后回到待机或继续漫步。

演员状态与导入动作是两层，映射写在一处 `CLIP_BY_STATE`：

| 状态 | 动作 | 说明 |
| --- | --- | --- |
| idle | idle | 站姿循环 |
| walk | walk | 原地走循环，位移仍由角色控制器产生 |
| talk | idle | 绑定包没有交谈动作，交谈时保持站姿循环并转向玩家 |

`_play_clip` 不再对“已经在播的同一个动作”重新调用 `play()`：既避免站姿循环在每次进入/退出交谈时跳回第一帧，也回避了一个已复现的引擎问题——Godot 4.7.2 中，被重复播放的当前动作其后随场景释放会段错误（见 ADR 0010 与 `artifacts/verify_equivalent.ps1` 之外的窗口截图复现命令）。run、sit_down、sit_idle、stand_up 四段动作在本场景尚未使用；坐姿需要椅面锚点与就座行为，属于后续工作包。

两个预览 NPC 复用同一蒙皮模型并各自独立播放动作。本轮移除了按装配数据给外套上色的代码：绑定模型只有一张带贴图的整体材质，按同一材质改色会连皮肤和头发一起染色，身份区分仍由悬浮名牌承担。

NPC 仍使用场景内固定问候，近距与墙体视线门槛保留。没有 AI、知识库、正式身份、存档或跨房间导航。外形、角色所在房间和模型源不构成《死光》事实。后续正式角色应提供经批准的角色参考图、模型与授权正文资料，复用当前骨架/动作接口或明确替换。

## 验收

等价驱动的三步与 `scripts/verify.ps1` 一致（退出码、错误正则、完成标记、套件标记），只登记本机既有的 Windows 根证书读取失败与沙箱下的编辑器设置写入失败两行环境噪声，未放宽其他判定：架构检查 197 个源/场景文件、3 项负向用例、资源导入、`AIRPG_TESTS: 990 checks, 0 failures`（BASE 95 / G1 138 / F1 174 / NPC_AI 35 / I1 246 / ARCHIVE 62 / MANOR 118 / NPC_RIG 15 / CHARACTER 38 / INTERACTION 69）、启动标记 `AIRPG_BOOT_READY` 通过。NPC 套件实际实例化庄园模型，检查蒙皮与 23 骨、站姿循环把骨架从建模 A 姿势驱动开、物理行走驱动走循环、转身、交谈停步并面对玩家、共用一个动作的状态不重播该循环、以及模型本地朝向 +Z。

Godot 4.7.2 / RTX 4060 实际图形窗口截图：`artifacts/npc_study.png`（书房 NPC 站位、身高、贴图与名牌）和 `artifacts/npc_study_greeting.png`（按 F 后的固定问候与面对玩家姿态，同时是上一节段错误的复现路径）。截图复现命令（模式 `study` 无对话，`study_talk` 触发并保持固定问候）：

`Godot_v4.7.2-stable_win64_console.exe --path game --script res://tests/manor/capture_main.gd -- <输出.png> study`

复核重点：真实门口长期漫步与碰撞、导出包的蒙皮材质、动作权重在不同姿势下的破面、50k 三角面加入后的绘制开销、以及许可取舍本身是否需要在上架前替换为经批准的角色美术。没有外部试玩或独立对抗签字。

## 历史记录：C-NPC-RIG 程序几何占位模型（2026-10-03）

公开仓库当时使用项目原创的程序几何占位模型。`scripts/assets/build_npc_public.py` 用 Blender 5.2.2 后台生成 `game/presentation/manor/npc_preview_public.glb`：简化的衣帽、手脚和头部网格，17 根骨骼与逐顶点权重，以及循环待机、行走、交谈动画。原本地原型使用的 `mujer_sexy.glb` 标有 Sketchfab Standard 许可，当时判断不能作为独立可下载资产放入公开仓库，其源网格、纹理和衍生蒙皮文件留在本机。

几何与服装仅用于验证演出，不是正式年代服装或角色形象。两个“身份待确认”预览 NPC 复用同一蒙皮模型，各自独立播放动作，外套颜色由装配数据区分。

当时的 `NpcActor.configure` 检查 Skeleton3D、17 根骨骼、Skin、AnimationPlayer 和 `idle/walk/talk`；动作由真实物理位移与 `NpcPresence.paused` 决定，根节点碰撞体是位移权威，GLB 不使用根运动。朝向以实际位移平滑转动，交谈时转向玩家，关闭后回到待机或继续漫步。模型资源用 `preload`，不在运行时按字符串动态加载。

当时的验收：`scripts/verify.ps1 -Godot D:/Godot/Godot_v4.7.2-stable_win64_console.exe`：123 文件架构检查、3 项负向、312 项行为/集成检查零失败，导入与启动标记通过；Godot RTX 4060 实际图形截图 `artifacts/npc-rig-game.png` 已核对正面、身高、衣色与交谈 UI。

本工作先在独立 `codex/npc-rig-animation` 工作树完成，起点是当前原型未提交快照；核对重叠文件后，已将本轮变更同步到主工作区。快照还包含其他任务在进行的角色物品与门交互。为了让统一验证能真实运行，本目录修正了其中的补给回血夹具、测试参数和非法回执类型校验。主工程集成时还发现门体启用 `sync_to_physics` 会把新建门体重置到原点，现改为由门视图在物理帧直接驱动；场景与领域测试按 0.42 秒动画和忙碌状态验收。门净空检查独立于必须瞄准门的玩家命令，因为玩家站在门扇扫掠区时准星可能没有命中门。
