# ADR 0009：运行时输入 API 的 NPC 对话与语义移动

日期：2026-10-03。状态：工程预览已实现。工作包 AFGCI-NPC-AI，负责人本任务，独立复核待分配。
依据 PRD 的 AI 信任边界、NPC 对话与场景行动目标；不确定的剧情、角色、检定和存档决策保持未实现。

## 决策

采用“玩家在游戏内输入 API 连接信息，游戏直接调用 Chat Completions 兼容端点”的模式。
借鉴 AI 酒馆类前端的角色设定、世界资料和最近对话分层思路，但模型只生成候选回复与语义动作，
不成为游戏状态权威。启动层仍是唯一装配入口，不增加 Autoload、服务定位器或全局事件总线。

开始界面的设置面板接收完整 HTTPS endpoint、模型 ID 和 API Key。endpoint 与模型 ID 可进入只读诊断；
Key 只保存在本次进程内的凭据对象中，提交后清空输入框，断开或退出时释放，不进入 `res://`、内容、
存档、诊断或日志。本阶段不替用户预设供应商、模型型号或密钥，也不在配置时主动发起计费探测请求。

## 请求与验证链

`DialogueUseCase` 先按 speaker / scene / topic 投影上下文，再由请求构建器把权威事实正文、可感知信息、
最近对话与显式 `untrusted` 区域编译为 system + user 两条消息。版本化 prompt 位于
`data/ai/npc_prompt.zh_CN.json`，外部 JSON 先按 `npc_prompt.schema.json` 校验。传输适配器负责 HTTPS、
SSE、UTF-8、超时与取消；`ChatCompletionGateway` 缓存完整响应，拒绝非 `stop` 结束和无效 JSON，
且不把 `raw_delta` 转发给对话/UI。

回复必须严格包含 `schema_version`、`speaker_id`、`reply_text`、`used_fact_ids`、`options`、`actions`。
事实 ID、说话者、选项与动作均通过 F1 白名单；每次最多一个动作。验证成功后，动作先转换为带
session、request、state revision、speaker、scene 的 `NpcActionContract` 提案，经场景动作端口接受，
之后才发布已验证回复。任何失败、取消、过期或动作拒绝都不显示模型回复，也不提交剧情、物品或掷骰。

## 移动权限

模型只可选择 `npc.stay`、`npc.face_player` 或 `npc.move_to_anchor(anchor_id)`，不能输出坐标、路径、
速度、脚本或状态补丁。`NpcActionDriver` 在当前庄园场景内把预先登记、且属于该 NPC 的 anchor ID
映射为 `Vector3`；未知锚点、其他 NPC 的锚点和额外字段全部拒绝。移动指令是意图，不等于抵达，
角色到达或卡住由场景运动控制器独立处理。

当前 `preview_reception` / `preview_study`、观察文本和锚点只是合成工程预览，不是正式人物、剧情或内容包。

## 取舍与后续

直接连接减少独立后端部署，但玩家设备会持有运行期 Key，发布版仍需评估代理服务、额度控制、撤销、
供应商隐私条款和滥用防护。HTTPS 校验和内存保存不能等价于系统级秘密保险箱。

结构校验、事实 ID 白名单和提示词不能证明自然语言没有暗含新事实；正式内容接入前仍需语义验收策略。
尚未实现真实外部环境联调、正式角色卡/知识包、长期记忆、语音、路径规划、动作完成后续对话、计费展示、
存档恢复或检定/剧情状态提交。这些能力不得从工程预览推断为已完成。
