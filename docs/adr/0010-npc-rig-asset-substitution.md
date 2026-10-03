# ADR 0010：预览 NPC 改用基础绑定模型及随之而来的许可取舍

日期：2026-10-03。状态：已实施（本机验证，未推送）。工作包：庄园 NPC 视觉替换。依据 PRD §9.1、§14.2、§14.3；用户直接指示“用 `output/npc_basic_rig/mujer_sexy_rigged.glb` 替换游戏书房 NPC 建模”，并在被明确告知许可影响后选择“直接提交进仓库”“两个 NPC 都换”。

## 背景

`docs/npc-rig-preview.md` 原记录的取舍是：公开仓库只使用项目原创的程序几何占位模型 `game/presentation/manor/npc_preview_public.glb`（17 骨、idle/talk/walk、无贴图，由 `scripts/assets/build_npc_public.py` 生成），而带 Sketchfab Standard 许可的 `mujer_sexy.glb` 及其蒙皮衍生文件只留在本机，因为该许可不允许把模型作为可下载资产再分发。

用户随后交付了 `output/npc_basic_rig/mujer_sexy_rigged.glb`：同一来源网格与内嵌贴图，23 根骨骼、六段动作、身高规整为约 1.75 米，并明确要求把它接进游戏的书房 NPC。

## 决定

1. 把该 GLB 复制进项目为 `game/presentation/manor/npc_preview_basic_rig.glb`，随仓库提交，并在 Godot 中导入（含抽取出的贴图与 `.import`）。工作室节点、骨数与动作名以实际导入结果为准，不按交付说明书假定。
2. 两个合成预览 NPC（接待室、韦伯医生的书房）都换用该模型；原来的程序几何占位模型保留在仓库中但不被引用，作为一次性回退视觉，生成脚本不改。
3. 演员状态与动作分离：`CLIP_BY_STATE` 一处映射 `idle→idle`、`walk→walk`、`talk→idle`。绑定包没有交谈动作，因此交谈时保持站姿循环并转向玩家，不假装有交谈演出。
4. 移除按装配数据给外套上色的代码与名单里的 `color` 字段：绑定模型只有一张带贴图的整体材质，改色会连皮肤和头发一起染色，身份区分交给已有的悬浮名牌。

## 许可后果（用户已知悉并接受）

本决定取代上述“公开仓库不含该资产”的约定：仓库从此包含 Sketchfab Standard 许可的网格、贴图及其蒙皮衍生文件。该许可允许在项目中使用，但通常不允许把模型本身作为可下载资产再分发；本仓库是公开远程。发行、上架或对外分发前应复核这一取舍，必要时换回 `npc_preview_public.glb` 或改用经批准的角色美术。本 ADR 只记录工程现实与决定，不构成法律意见。

## 兼容与实现要点

- `NpcActor` 检查 `AnimationPlayer`、`NPC_Rig/Skeleton3D`、23 根骨骼、`NPC_Rig/Skeleton3D/NPC_Body` 的 Skin 与动作映射；失败仍在庄园启动时报 `NPC_VISUAL_INVALID` 并停止场景更新。
- 演员状态名保持 `idle/walk/talk`，`current_clip()` 语义不变，NPC 动作端口（`npc.stay`、`npc.face_player`、`npc.move_to_anchor`）与对话用例不受影响。
- `_play_clip` 不再对已经在播的同一动作再次调用 `play()`。这既避免站姿循环在进入/退出交谈时跳回第一帧，也回避一个已复现的引擎问题：Godot 4.7.2 中，重复播放当前动作后随场景释放会段错误。复现与排除过程（旧模型不崩、换用不同动作不崩、跳过重播不崩、不释放场景不崩）在 `docs/handoff.md` 本轮记录中。
- 位移权威仍是根节点碰撞体，GLB 不含根运动；`run`、`sit_down`、`sit_idle`、`stand_up` 暂未使用，坐姿需要椅面锚点与就座行为。

## 验证

等价驱动（与 `scripts/verify.ps1` 相同的退出码、错误正则与完成标记，只登记本机既有的根证书读取失败与沙箱下的编辑器设置写入失败两行）通过：架构检查 197 个源/场景文件、3 项负向用例、导入与启动标记；`AIRPG_TESTS: 990 checks, 0 failures`，其中 NPC_RIG 15 项覆盖 23 骨、A 姿势驱动、物理行走、转身、交谈停步与面对玩家、共用动作不重播、以及模型本地朝向 +Z。图形窗口截图 `artifacts/npc_study.png`、`artifacts/npc_study_greeting.png`。

## 未决与复核

50k 三角面加入后的绘制开销、多 NPC 同屏、导出包内的蒙皮与贴图表现、以及许可取舍在上架前是否必须替换，均未验收；独立对抗复核待分配。本 ADR 未变更 PRD、状态格式、存档、共享契约或引擎版本。
