# 接续记录

## 模型回答缺陷分类 + 一次静默重采样（2026-10-04）

用户给出实机证据：同一套配置下有些请求成功进入 presenting、有些失败，而 Key 错误会持续返回
`MODEL_TRANSPORT_ERROR`，不会间歇成功——因此问题在响应本身，不在凭据。工作包：对话失败分类与恢复 /
负责人本任务 / 独立对抗复核待分配；分支 `feature/held-inventory-item`，未推送。决策见
[ADR 0013](adr/0013-model-answer-defect-classification.md)。

**协作情况（重要）**：本轮开始前，工作区里已有**另一个会话**未提交的同类改动（网关一次重采样 attempt 机制、
`deepseek_config` 的 `max_tokens: 1024` + `thinking: disabled`、提示词 JSON 示例与
`__SPEAKER_ID_JSON__` 占位符及其测试，时间戳 01:04–01:07）。我先把自己并行改的两个文件回退，避免覆盖它，
随后在其基础上继续完成并统一验证；该会话最后写入时间为 01:07，之后未再改动。**同一批文件请勿再并行双写**。

本轮在其之上完成的部分：契约新增 `MODEL_EMPTY_CONTENT` / `MODEL_FINISH_INCOMPLETE` / `MODEL_REPLY_INVALID`
三个稳定可重试码，`completed_response` 最先分类、provider 原样透传；网关把分类接进它已有的重采样路径
（可恢复码自动重发一次、逻辑请求 id 不变、第二次仍失败才上报分类码），并打印
`AIRPG_AI_RECOVERY: retry <code> <detail>` / `AIRPG_MODEL_REPLY_REJECTED: <code> <detail> (retry exhausted)`，
`<detail>` 只含类别、自有键名与计数（`fields:1`、`finish:length`、`envelope:MODEL_EMPTY_CONTENT`），
**不含回复正文**；`ModelReply` 的 issues 同样只报键名/计数/分组；对话用例把三个新码标为可重试；
失败状态同时显示本地化解释与稳定码。

顺带修掉一个真实缺口：`game/presentation/dialogue/localization_keys.md` 里登记的 16 个界面键与 7 个错误码键
**从未并入** `data/localization/zh_CN.json`，正式构建里对话界面会直接显示键名。现已全部并入（含三个新码），
并同步 I1 用例中「期望显示键名」的断言为「期望显示翻译」。

验证：架构 204 个源/场景文件 + 3 项负向用例；`AIRPG_TESTS: 1098 checks, 0 failures`
（NPC_AI 116→127，其中新增空内容/截断/协议不符的分类与重采样断言、示例说话人替换断言、分类不带正文断言；
G1 142 项保持通过）；导入与启动标记见等价驱动。未使用真实 Key，未发生外部模型调用。

未实现/待复核：重采样固定一次、无退避、未按分类区分；`thinking: disabled` 对推理型模型的影响、
1024 上限在长选项下的截断概率、重采样对成本与延迟的影响均未实测；真实 DeepSeek 联调仍需用户实机复现
以确认空响应频率下降。复核重点：分类是否误判（空白但语义有效的回复）、重采样期间不产生任何动作副作用、
日志细节是否始终不含正文。

## API Key 保存在本机（2026-10-04）

用户要求“把 apikey 保存在本地，不然重启一次配置一次太麻烦”。工作包：AI 凭据本地持久化 / 负责人本任务 /
独立对抗复核待分配；分支 `feature/held-inventory-item`，未推送。决策与风险见
[ADR 0012](adr/0012-local-api-key-storage.md)。

实现：新增 `infrastructure/ai/local_credential_store.gd`（唯一接触凭据文件的适配器，默认
`user://ai_credentials.json`，即 `%APPDATA%\Godot\app_userdata\AIRPG\`——在 res:// 之外、仓库之外、
不进导出包）。读取严格校验（字段精确、类型、长度、拒绝控制字符），不合法失败关闭；写入 best-effort，
失败只影响“下次不用重填”。端口 `ModelConfiguration` 增加 `restore()` 与 `configure_stored()`；
组合根显式注入 store 并调用 `restore()`；设置面板 Key 留空＝沿用已保存密钥，诊断只多一个布尔 `stored`；
“断开”同时删除本机文件。`.gitignore` 增加 `ai_credentials.json` 兜底。

**只有组合根能决定写盘**：`RuntimeModelConfiguration` 不再有隐式默认 store，传 null 即纯内存。
这条是在本轮发现的测试污染后加的：设置面板测试用 `Runtime.new()` 会把合成凭据写进真实的
`user://ai_credentials.json`，既污染玩家密钥又让后续 `restore()` 误判“已配置”（日志里出现
`AIRPG_NPC_AI: ready`）。现在测试运行不再产生该文件，已清掉被写入的合成文件；真实用户目录当时是干净的。

验证：架构 204 个源/场景文件 + 3 项负向用例、导入与启动标记；`AIRPG_TESTS` 见本轮等价驱动结果，
其中 NPC_AI 100→111 新增：缺失文件上报、写入/读回、重启后 `restore` 成功、诊断不含 Key、
Key 留空复用已保存凭据、损坏文件失败关闭、控制字符拒收、断开删除文件。未使用真实 Key（测试用合成字符串）。

未实现/待复核：明文存储的风险取舍（个人原型可接受，分发前必须改服务端转发）、Windows 凭据管理器集成、
多账户/多端点管理、密钥轮换提醒。复核重点：任何新代码路径是否可能在日志、诊断或导出包中出现 Key，
以及 `user://` 与项目目录的边界是否仍成立。

## 问两句就卡住：失败锁死自由输入（2026-10-04）

用户补充“问两句就会卡住”。定位到根因：`DialogueRequestRegistry` 只允许同时一个在途请求，而
`dialogue_chrome.render` 在 `FAILED / PAUSED / CANCELLED` 把输入框设为不可编辑、提交按钮禁用，只留“重试”。
于是**模型回复一旦被拒或超时，玩家就无法再提问**，只能重发同一句或返回——第一次正常、第二次被拒，
就停在失败态，感受即“问两句就卡住”。上一轮新增的按角色输出硬校验把气泡预算设成「2 句 / 每句 40 字」
并按句子计数，中文台词很容易越界，正好频繁触发这条路径。

修复：输入只在 `WAITING`（等待回复）与 `PRESENTING`（播放中）锁定，`FAILED / PAUSED / CANCELLED` 都可继续提问，
“重试”仍在旁边；气泡预算放宽为**3 句 / 每句 60 字**，人格提示词仍按角色卡要求短句，校验器只拦跑飞的长段落；
提交被拒时打印 `AIRPG_DIALOGUE_REJECTED: <code>`。回归：NPC_AI `_multi_turn`（一条必被拒的回复之后，
第二个问题仍被接受并可发布）与 I1 `_failure_keeps_conversation_alive`（失败态输入可用、新问题进入等待、
能拿到第二次回答）。验证 `AIRPG_TESTS: 1068 checks, 0 failures`（I1 254→259，NPC_AI 97→100），
架构 203 文件 + 3 负例、导入与启动通过。本轮验证时 Godot 测试进程又卡死一次（本机既有现象，位置每次不同），
杀掉重跑即通过。

## 对话卡住与“共用一个对话”（2026-10-04）

用户反馈：对话经常卡住、两个 NPC 像共用一个对话，并要求查看游戏日志。工作包：对话可退出性与每角色会话隔离 /
负责人本任务 / 独立对抗复核待分配；分支 `feature/held-inventory-item`，未推送。完整说明见
[docs/dialogue-stuck-and-session-isolation.md](dialogue-stuck-and-session-isolation.md)。

日志结论：本机实际日志在 `%APPDATA%\Godot\app_userdata\AIRPG\logs\`，最近 4 次启动只有 `AIRPG_BOOT_READY`
与 `AIRPG_STRUCTURE_WALK_READY`——**此前 NPC 对话路径一条日志都不写**（`configure_ai` 失败只写内存字段），
所以无法从旧日志复盘。另有一个关键事实：API Key 只存在于当前进程内存，每次启动都要在“设置”重新填写；
未配置时按 F 得到的是固定问候框（无自由输入），容易被感受为“卡住”。

修复：`dialogue_chrome.render` 之前只在 FAILED/PAUSED/CANCELLED 显示“返回”，等待期间输入被锁、鼠标已释放、
移动被阻断却没有可见出口（请求最长等 60 秒）。现在“返回”在所有状态可见。新增
`DialogueView.begin_conversation(name_key, portrait_id)`：换人时清空上一位的台词、选项与错误状态，
立即写上当前 NPC 名牌与立绘，并在历史面板插入本地化分隔行；`ManorNpcAi.begin` 每次开始对话时调用它。
新增 `application/dialogue/dialogue_memory.gd`：按 NPC 归属的近期记忆（默认最近 6 行、超长截断、重试不重复），
`DialogueUseCase` 只注入当前说话人的记忆，因此艾米利亚的对话不会进入玛丽的上下文，玩家原话仍走 `untrusted`。
仍需共用的部分：一个会话只有一个主要对话对象（PRD §9.5），历史面板仍是会话级总记录（现在有分隔行）。

新增日志标记（不含密钥/提示词/模型原文）：`AIRPG_NPC_AI: ready|<code>`、`AIRPG_NPC_DIALOGUE_OPEN: <speaker> @ <topic>`、
`AIRPG_NPC_DIALOGUE_REJECTED`、`AIRPG_NPC_DIALOGUE_CLOSE`、`AIRPG_DIALOGUE_STATE: <state> <error_code>`。
测试日志里出现 `AIRPG_NPC_AI: AI_NOT_CONFIGURED` 属预期：它证明生产装配已成功加载并校验世界书与角色卡，
只是没有配置 Key（`create_transport` 在内容校验之后）。

验证：`& ./artifacts/verify_equivalent.ps1` 三步通过；架构 203 个源/场景文件 + 3 项负向用例；
`AIRPG_TESTS: 1060 checks, 0 failures`（I1 246→254，NPC_AI 94→97）。新增覆盖：idle/waiting 状态“返回”可见、
`begin_conversation` 清空上一位台词与选项并立即换名牌、历史出现会话分隔、艾米利亚的近期记忆回到她自己的下一次请求
而玛丽的下一次请求不含她的任何一行。一次 Godot 测试进程再次卡死（本机既有现象），杀掉重跑即通过。

未实现/待复核：关键记忆（结构化事件）、关系摘要、跨场景记忆、完整历史导出、对话中途存档；
`recent_dialogue` 只覆盖最近 6 行。复核重点：换人时挂起请求取消是否彻底、分隔行在长会话中的可读性、
60 秒等待期间的可取消体验、以及状态日志在正式构建中的噪声量。

## 庄园 NPC 接入角色卡与世界书（2026-10-03）

用户交付 `死光_角色卡_艾米利亚与玛丽_AI接入版.md`（微信临时目录）与 `《死光》AIRPG世界书整理版.docx`
（Downloads），要求把两个角色接进书房与接待室 NPC，并把世界书接入。用户确认：艾米利亚→书房、玛丽→接待室；
范围为“内容 + 提示词 + 知识白名单”，信任增减、逆鳞强制断对话、失谐波纹 UI、行为树、检定公式留作后续。
工作包：NPC 角色卡 + 世界书接入 / 负责人本任务 / 独立对抗复核待分配；分支 `feature/held-inventory-item`，
未推送。完整说明见 [docs/npc-characters.md](npc-characters.md) 与
[ADR 0011](adr/0011-npc-character-cards-and-worldbook.md)。

数据：`data/ai/npc_characters.zh_CN.json`（两张角色卡：人格模板、状态枚举与初值、信任/恐惧上限、禁用句、
气泡预算、立绘 ID）与 `data/ai/deadlight_worldbook.zh_CN.json`（13 节世界书条目，保留来源文档的
公开/调查/隐藏/运行分层与受众），各自配 JSON Schema，再经领域校验器。事实正文与 text_key 同处
受校验数据文件；玩家可见文本（两个名字、问候、兜底台词、现场观察）仍在 `zh_CN.json`。

实现：`CharacterCard` / `WorldBook` / `ReplyPolicy` 三个新领域模块；世界书派生 F1 fact 时取
“受众 ∩ 本场景说话人”，每条条目只产出一条 fact；`hidden`/`running` 层禁止携带 NPC 受众（构造期拒绝，
测试固化），因此叙事者层不可能被误接给 NPC。请求构建器新增可选人格注入，占位符在构造期校验；
`ReplyValidator` 新增可选角色输出策略（禁元层暴露、玛丽禁可证伪否定句、艾米利亚禁顺从式自我标签、
最多两句且每句 ≤40 字，动作描写用圆括号单独成行），拒绝一律按可重试失败处理。话题 ID 取玩家当前房间
（`manor.room.<room>`）以过滤记忆碎片；现场观察（玩家在场、谁在附近）由注入的 observer 提供。

站位与译名：玛丽在庄园接待室对应她潜入销毁证据的场景 B（她本章初始岗位仍在加油站），已在文档显式记录；
世界书写“韦伯”、角色卡写“韦布”，工程统一用**韦伯**；孙女“艾米利亚”与祖母“艾米莉亚”未合并。
说话人 ID 由 `preview_*` 改为 `mary` / `emilia`（F1 要求小写 ID），本地化键、测试与截图脚本同步更新。

验证：等价三步（架构、导入、聚合测试与启动标记）`& ./artifacts/verify_equivalent.ps1`。
架构检查 202 个源/场景文件 + 3 项负向用例通过；`AIRPG_TESTS: 1049 checks, 0 failures`
（BASE 95 / G1 138 / F1 174 / NPC_AI 94 / I1 246 / ARCHIVE 62 / MANOR 118 / NPC_RIG 15 / CHARACTER 38 /
INTERACTION 69）；启动标记 `AIRPG_BOOT_READY` 通过。NPC_AI 由 35 升到 94，新增内容专项覆盖：
角色卡 Schema 与领域校验、占位符缺失被拒、世界书分层与受众、narrator 层安全不变量、跨 NPC 知识不串、
披露门开合、房间碎片过滤、禁用句与允许句、气泡预算、人格渲染与事实同请求、端到端“禁用句回复不进入视图”。
未使用真实 API Key，未发生外部模型调用；本机既有环境噪声（根证书读取、沙箱下编辑器设置写入）按既有做法登记。

未实现/待复核：信任与恐惧增减、逆鳞强制结束对话与沉默、`LIE_TELL` 失谐波纹、玛丽的自主行为树与
可见位置变化、比利指认/枪口对峙等缺失对话节点、立绘资源、AI 主持人（叙事者层已作为数据保存但无消费者）、
开场动画与加油站场景。输出校验是字符串启发式而非语义证明；玛丽的提示词按角色卡包含真相（演出“只说真话
只回避”所必需），风险由事实目录不含真相 + 禁用句校验 + 未实现的坦白门共同承担。
对抗复核重点：跨 NPC 知识是否真的不串、被追问“匣子里是什么”时她是否只说不知道、
披露门被误开后是否会泄露、禁用句是否被改写绕过、以及 40 字/两句预算对实际气泡的适配。

## 预览 NPC 换成基础绑定模型（2026-10-03）

用户给出 `output/npc_basic_rig/mujer_sexy_rigged.glb`，要求用它替换游戏书房 NPC 建模；在被明确告知
`docs/npc-rig-preview.md` 记录的许可见解（该资产标 Sketchfab Standard，原先只留在本机、不进公开仓库）后，
用户选择「直接提交进仓库」并把范围扩到两个预览 NPC。工作包：庄园 NPC 视觉替换 / 负责人本任务 /
独立对抗复核待分配；分支仍为主工作区当前的 `feature/held-inventory-item`，未推送。

资产：`game/presentation/manor/npc_preview_basic_rig.glb`，与交付文件逐字节一致（SHA-256
`905fb38d…08e3`，2 478 900 字节，23 骨、六段动作），Godot 抽取出的贴图 `npc_preview_basic_rig_Image_0.jpg`
（500 448 字节，SHA-256 `65cb23dc…f479`）与两个 `.import` 一并入库。上游网格/贴图来自
`mujer_sexy.glb`（SHA-256 `78ae294f…4ad2`）。

实现：`NpcActor` 的视觉、骨架路径、骨数与「状态→动作」映射集中为常量；`talk` 映射到 `idle`，因为绑定包
没有交谈动作，交谈时保持站姿循环并转向玩家（不假装有交谈演出）。`_play_clip` 不再对已经在播的同一个
动作重新调用 `play()`。移除了按装配数据给外套上色的代码与名单里的 `color` 字段：新模型只有一张带贴图的
整体材质，改色会连皮肤和头发一起染色，身份区分继续由悬浮名牌承担。原来的程序几何占位模型
`npc_preview_public.glb` 与生成脚本保留在仓库但不被引用，可作回退视觉。

本轮发现并规避的引擎问题：真实图形窗口下按 F 触发问候后，若该演员刚刚「重复播放了当前正在播的动作」
再释放场景，Godot 4.7.2 会 `CrashHandlerException: signal 11` 退出（退出码 -1073740771）。排除过程：
同一条截图命令换成旧的 17 骨占位模型不崩；`talk` 临时映射到另一个动作不崩；保留映射但跳过「重播已在
播的动作」不崩；不释放场景只 `quit()` 也不崩。无头测试套件未复现该崩溃，因此守卫落在行为断言上
（「共用动作的状态不重播该循环」），复现命令保留在 `docs/npc-rig-preview.md`。崩溃发生在截图落盘之后，
不影响产物，但属于同一场景释放路径，故按真实缺陷处理。

验证：`scripts/verify.ps1` 在本机仍被既有环境问题挡在导入步骤（Godot 读不到 Windows 根证书库；
沙箱下无法写 `%APPDATA%\Godot` 的编辑器设置）。按本文件既有做法改用逻辑等价驱动
`artifacts/verify_equivalent.ps1`（同参数、同错误正则、同完成标记与套件标记，只登记这两行环境噪声，
`APPDATA` 指向 `artifacts/godot-appdata`）：架构检查 197 个源/场景文件、3 项负向用例、资源导入、
启动标记通过；`AIRPG_TESTS: 990 checks, 0 failures`（BASE 95 / G1 138 / F1 174 / NPC_AI 35 / I1 246 /
ARCHIVE 62 / MANOR 118 / NPC_RIG 15 / CHARACTER 38 / INTERACTION 69）。改动前基线为 987 项零失败，
NPC_RIG 由 12 升到 15。真实图形窗口 RTX 4060 截图 `artifacts/npc_study.png`、
`artifacts/npc_study_greeting.png` 已核对：书房 NPC 站位、身高 1.75 米、贴图、名牌、按 F 后的固定问候
与面对玩家朝向均正常；`capture_main.gd` 新增 `study` / `study_talk` 两个模式用于复查。

未实现/待复核：绑定包的 `run`、`sit_down`、`sit_idle`、`stand_up` 四段动作未使用，坐姿需要椅面锚点与
就座行为；没有交谈动作、面部、手指或 IK；50k 三角面加入后的绘制开销、多 NPC 同屏、导出包内的蒙皮与
贴图、以及许可取舍在上架前是否必须换回经批准的角色美术均未验收；独立对抗复核待分配。工作区里另有
其他任务留下的未跟踪草稿 `game/presentation/manor/mujer_sexy.glb`、`npc_preview_rigged.glb`（17 骨旧
绑定尝试）与 `scripts/assets/build_npc_preview.py`，本轮未改动、未提交，已由本资产取代，可由其负责人
清理。本轮未推送、未发布、未变更 PRD。

## NPC AI 输入 API 合入桌面主工程（2026-10-03）

用户要求把 `codex/npc-ai-input-api` 合入 `C:/Users/31286/Desktop/AIRPG/game` 并一同推送。
目标分支为桌面主工程当前的 `feature/held-inventory-item`；远端同名分支同步前仍停在基线 e41553fb，
没有并发提交。先把工作区中已完成且直接相关的撬棍拾取/持有/丢弃展示提交为 8d210a40，随后以
3d7b9ba5 合并 NPC AI 分支（包含 7544e975 功能提交与 78891f47 API 面板自适应修复）。

合并自动保留 `manor_play.gd` 的两侧改动：运行时掉落物仍使用稳定交互 ID，节点名使用合法下划线；
同一庄园场景同时装配 AI 对话、语义锚点动作和现有物品交互。未引用的 `mujer_sexy`、
`npc_preview_rigged` 模型、`output/` 草稿、`docs/worktree-cleanup.md` 与资产构建草稿未纳入提交或推送。

合并后原样运行 `./scripts/verify.ps1 -Godot D:/Godot/Godot_v4.7.2-stable_win64_console.exe`：
架构检查 197 个源/场景文件与 3 个负向用例通过，资源导入和启动检查通过，聚合
`AIRPG_TESTS: 987 checks, 0 failures`；其中 NPC-AI 35、G1 138、F1 174、I1 246、交互 69。
未使用真实 API Key 或外部模型调用，真实 DeepSeek 联调边界不变。

## 输入 API 模式的 NPC AI 纵向切片（2026-10-03）

用户选择在游戏内输入 API 配置并要求开始实现。工作包 AFGCI-NPC-AI / 负责人本任务 / 独立对抗复核待分配；
分支 `codex/npc-ai-input-api`，managed worktree `C:/Users/31286/.codex/worktrees/npc-ai-input-api/AIRPG`，
基线 e41553fb。主工作区已有用户改动，未写入、覆盖或暂存；本工作树整合 F1、G1、I1 已完成提交后完成纵向接线。

实现：开始界面“设置”新增 API 地址、模型 ID、API Key 输入与断开入口；Key 提交后清空输入框，只保存在
本次进程内的运行时凭据，不进入诊断/资源/存档/日志。`ChatCompletionRequestBuilder` 把 F1 过滤上下文编译为
system/user messages，权威 fact key 在发送前解析为审核正文；`ChatCompletionGateway` 适配 G1 完成信封、缓存并
解析严格 JSON，拒绝非 stop 结束且不把 raw delta 连接 UI。版本化 prompt 和 Schema 位于 `data/ai/`、
`data/schemas/`。G1 同时修正 `HTTPClient.request_raw`、忽略暂停/时间缩放的超时、同步回调登记顺序、release 取消、
endpoint 控制字符和生成参数白名单。

NPC 动作：F1 每个回复最多接受一个动作；`NpcActionContract` 绑定 session/request/revision/speaker/scene，禁止坐标。
庄园场景只接受 `npc.stay`、`npc.face_player`、`npc.move_to_anchor(anchor_id)`；`NpcActionDriver` 把该 NPC 的白名单
锚点映射成 Vector3 后交给 `NpcActor`。陌生锚点、跨 NPC 锚点、额外字段、动作拒绝、取消和过期结果均不显示回复。
移动到达/卡住由角色控制器处理，提示词禁止把移动意图说成已经抵达。对话输入聚焦时 F/E 不再误触游戏快捷键。

范围边界：`preview_reception`、`preview_study`、观察文本、锚点和回复夹具均为合成工程预览，不是正式人物或剧情；
未实现正式角色卡/知识包、自然语言语义证明、真实服务商调用、长期记忆、语音、路径规划、动作完成回调对话、
额度/计费 UI、剧情/检定/物品提交或存档恢复。设置中的“已配置”只代表本地校验通过，首次对话才实际请求。

验证：`./scripts/verify.ps1 -Godot D:/Godot/Godot_v4.7.2-stable_win64_console.exe` 原样通过；架构 195 文件与
3 个负向用例通过，资源导入、启动标记均通过；API 面板自适应修复后的聚合为
`AIRPG_TESTS: 972 checks, 0 failures`，其中 G1 138、F1 174、NPC-AI 35、I1 246。NPC-AI 离线用例覆盖 Key 不进诊断、控制字符 URL、原始流隔离、截断响应、取消、事实正文解析、精确动作合同、
错误类型、会话/场景/版本门槛、同步完成竞态、坐标注入、锚点白名单和完整回复/动作流水线。没有使用真实 Key 或网络请求。

对抗复核重点：恶意玩家文本能否诱导模型泄露未投影事实；回复正文是否暗含未列 fact ID 的新增事实；供应商
返回 JSON mode 差异、SSE 断流与限流行为；Key 在崩溃转储/系统内存中的威胁；NPC 卡住、玩家阻挡和场景退出时
动作生命周期；正式内容接入时每个 NPC 的事实/锚点最小权限。完整决策和试玩说明见 ADR 0009 与
`docs/npc-ai-input-api.md`。

后续实机反馈与修复：用户在 1530×1110 窗口截图中发现设置内容继承大字号后超出固定居中面板，模型与
API Key 字段落到屏幕下方。面板现改为视口内四边留白布局，正文、标签、输入框和按钮使用明确字号与高度，
内容置于纵向 `ScrollContainer` 并跟随键盘焦点；同分辨率图形渲染截图
`artifacts/ai-settings-responsive.png` 已确认三个输入框与断开/返回/连接按钮同时可见。截图只作本机验证，
位于忽略目录；测试捕获脚本新增 `settings` 模式以便复查。

## F1 对话安全边界（2026-09-26）

分支 `feature/f1-dialogue-boundary`，worktree 在仓外独立目录，基线 `integration/slice-wiring@34ff473`。只新增 `game/domain/dialogue/`、`game/application/dialogue/`、`game/tests/f1/`，未改 Composition、公共契约/端口、G1 适配器、I1 视图、StateStore、Schema、本地化和测试聚合入口。

F1 现在是 G1 与 I1 之间的应用边界：按 NPC/场景/话题/透露条件投影权威事实，把玩家原话、笔记和传闻放进显式 `untrusted` 字段后交给 `ModelProvider`；模型完成回复必须通过结构、说话者、事实和动作目录校验，才转换成 `DialogueViewContract.verified_reply`。取消、过期版本、重复完成、错误 request/speaker 的结果一律不显示；失败不写状态、不消耗物品、不提交骰点、不连接 `raw_delta`。

验证：`AIRPG_F1_TESTS`（`tests/f1/run_f1_tests.gd`）174 项 0 失败；架构检查 104 个源文件通过；`./scripts/verify.ps1` 既有 663 项聚合 0 失败且真实主场景启动通过。F1 套件尚未登记进 `tests/run_tests.gd`（禁止功能分支修改），需集成负责人登记。

对抗复核修复：AIRPG-F1-001（非权威事实绕过受众过滤）：`knowledge_facts.untrusted_for` 现已对玩家陈述/传闻应用与权威事实相同的 speaker/scene/topic/透露条件过滤，仅改变信任级别；AIRPG-F1-002（可伪造验证标记）：`ReplyValidator` 返回密封的 `ValidatedReply` 类型，`DialoguePublication.build` 只接受该类型，普通字典（含手写 `validated` 字段）与未密封实例一律拒绝。QA 的 4 项断言全部保留并通过。

未实现：真实 DeepSeek 调用、正式《死光》事实与台词、G1 `completed.content` 到回复 DTO 的解析接线、Composition 装配、I1 生产接线、剧情状态结算/笔记写入、长期记忆摘要。事实文本目前只带 `text_key`，未接本地化解析。

下一步接线：集成负责人登记 F1 套件；Composition 用显式配置构造 `DialogueUseCase`（session、StateStore 只读快照、provider、上下文源、事实目录、动作目录、speaker 档案），I1 用 `configure(use_case)` 连接；G1 侧需在 `completed` 后用 F1 回复 DTO 解析/校验 `content`，prompt/messages 组装与事实文本解析仍需单独评审。

## 庄园模型换成 V4 修复版（2026-10-03）

用户给出 `output/manor_v4`，要求用这个模型替换原有模型。工作包 A-MANOR（模型线）/
负责人本任务 / 独立对抗复核待分配；仍在 `feature/manor-v3-scene` 分支与同一 worktree 上实施，
用户明确选择「用新的模型」，即游戏常量一起对齐 V4；主工作区未动。

不能直接换文件：V4 交付的 `manor_repaired_v4.glb`（79.8 MiB）没有
`ManorWalkCollision-colonly`，直接替换会让 `ImportedDoorCollision.strip` 返回
`MANOR_COLLISION_MISSING`、整个交互装配失败（门、拾取、提示全部消失）。V4 自带的
`validate_import.gd` 是自己搭 trimesh 碰撞的独立校验，不代表游戏契约满足。因此改为从
`manor_repaired_v4.blend` 用 `scripts/assets/export_manor.py`（由 `export_manor_v3.py` 改名并
扩展）重新导出游戏用 GLB。

导出改动：V4 新增集合 `V4_EmptyCellar`、`V4_ConcealedEntrance` 进入视觉；地窖坡道改用交付包
的 `V4_CellarRamp-colonly`；可撬地板（17 板 + 3 托条）不进入走行网格，改由独立的
`V4_PryFloorCollision-colonly` 承担碰撞，走行网格在该处留洞，对应 V4 元数据的 `on_open`
约定；移除 V3 遗留的地窖坡道常量。修掉一个自造缺陷：这块地板碰撞盒的面片绕序反了，
ConcavePolygonShape 单面碰撞导致角色从顶面掉进去卡在底面，重新导出后正常。

游戏侧同步：`manor_interactions._door` 改为按模型自述姿态绑定——V4 把十扇门叶做成“关闭”
姿态并携带 `angle_open_deg`（76°/82°），V3 则是“已打开”姿态，因此按元数据是否存在分支，
开门方向仍由 `_open_yaw_for_player` 按玩家所在侧选择（保留紧贴门可开门的修复）；
`MAX_FACES_PER_DOOR` 550 → 900（V4 把关闭门叶与内嵌门板一起烘进走行网格，实测每扇
540–726 面，`MIN` 仍 200）；`CELLAR_SPAWN` → `(-3.6,-3.19,-7.4)`、地窖补给点 →
`(-2.9,-2.99,-9.5)`、`manor_room_map` 增加按高度判定的坡道区；撬棍世界物品从
`(-4.3,0.24,0.0)` 移到 `(-3.5,0.24,-1.6)`，因为 V4 的接待室门现在是关闭姿态，原位置会嵌在门叶里
（该值与其主工作区未提交改动一致）。测试：走行用例先在测试夹具里调用生产剔除适配器，
再跑穿门与地窖路线；地窖改为「关闭地板挡住楼梯 → 释放地板碰撞 → 坡道上下行 → 新地面承重」。

验证（固定引擎 4.7.2，worktree 内）：架构检查 131 文件 + 3 项负向用例通过（删掉临时诊断后
128）；`--editor --import` 退出码 0，`manor.glb` 82.1 MiB / 5251 对象 / 130.7 万三角面 /
61 材质 / 34 贴图 / 69 204 走行碰撞面；`AIRPG_TESTS: 379 checks, 0 failures`
（BASE 95 / ARCHIVE 62 / MANOR 118 / NPC_RIG 12 / CHARACTER 38 / INTERACTION 54）；
`--quit-after 5` 出现 `AIRPG_BOOT_READY`；真实窗口截图
`artifacts/manor_v4/game_hall_v4.png`。抽取贴图按 V4 的 34 张同步，删除 copper 的 2 张残留。
`./scripts/verify.ps1` 仍只被本机既有的根证书读取失败挡住，未放宽其他判定。

未实现/待复核：**可撬地板只有资产与碰撞，没有撬棍交互**，所以运行时地窖、地窖补给与线索
暂时不可达（只能 B 键捷径进入），需要独立工作包新增交互类型与失败路径测试；走行网格是
单一凹多边形，撬开后无法局部还原，将来若要“重新盖上”需要可开关碰撞体；未做 LOD、合批、
显存与帧率验收，5253 节点与 130 万三角面的绘制调用仍是主要风险；未做导出包、低配与不同
DPI 验收；独立对抗复核待分配。复核重点：门姿态绑定在 V3/V4 两种模型上的分支、地板碰撞
开关前后的走行、以及地窖坡道与楼梯净空。

## 紧贴门开不了门：门净空只挡新增接触（2026-10-03）

用户试玩反馈「紧贴门开不了门」。工作包 C-MI2 / 负责人本任务 / 独立对抗复核待分配，
仍在 `feature/manor-v3-scene` 分支与同一 worktree 上实施，主工作区未动。

复现与定位（无界面物理诊断，逐门双面）：站在门叶前 0.259–0.260 米（胶囊半径 0.23 + 门叶半厚
0.0275 + `safe_margin`）时，准星能命中门体并显示提示，但按 F 全部返回 `DOOR_BLOCKED`：
十扇门、两个方向 20 个用例无一例外。根因在 `infrastructure/exploration/physics_door_clearance.gd`：
扫掠在 17 个角度上采样门叶，**包含起始（关闭）姿态**，而查询带 `margin = 0.045`；
角色靠住门叶后间隙只有约 0.002 米，于是「本来已经贴在门上的人」被判成阻挡。
这是净空规则的问题，不是射线、遮挡或模型问题（射线同时命中的门体会被绑定，聚焦正常）。

改动只落在净空适配器与测试，未改契约：`is_clear` / `is_clear_pose` 签名不变。
新规则：开启方向先记录起始姿态的接触体，扫掠中只把「新增接触」算作阻挡；若门叶停下时
仍压在这些接触体上，或该姿态出现任何接触，仍然 `DOOR_BLOCKED`。关闭方向不启用容忍，
与改动前逐字一致，因此「站在门扇将要经过的位置不能关闭」的既有行为与用例不受影响。

回归：`tests/manor/test_manor.gd` 新增 21 项检查——十扇门紧贴开门（瞄准 + 实际按 F 均须成功）
以及「有人站在开启弧内仍然阻挡」。全量 `res://tests/run_tests.gd` 为
`AIRPG_TESTS: 375 checks, 0 failures`（MANOR 93 → 114，INTERACTION 54 保持不变，
其中「actor in swept volume blocks closing」继续通过）。文档 `docs/interactions.md`
已补该规则与限制。

未做：只验证了玩家与合成 NPC 两类 actor；未做连续扫掠、门叶推开角色、多人重叠、
低帧率下的重复触发验收；独立对抗复核待分配。复核重点：靠门连按 F 的开合抖动、
门叶停下压人时必须仍然报阻挡、以及贴门时反向开门的观感。

顺带发现（本轮未修，属 presentation/character 工作包）：不经启动层、直接实例化
`manor_play.tscn` 时，`presentation/character/character_hud.gd:138` 会用没有占位符的
`tr("ui.item_count")` 做 `%` 格式化，报 `not all arguments converted during string formatting`。
正式启动路径先加载本地化，因此不触发；但裸场景测试会往日志里写 SCRIPT ERROR。

## 庄园 V3 模型替换主场景（2026-10-03）

用户交付《死光庄园_完整建模包_V3_20261003》的 `manor_furnished_v3.blend`，要求把该模型导入
游戏、替换原有庄园建模场景，并明确先不影响主 game 工作区。工作包 A-MANOR-V3 / 负责人本任务 /
独立对抗复核待分配；分支 `feature/manor-v3-scene`，独立 worktree `.tools/worktrees/manor-v3`，
基线 `8b22604c`（与 main 相同）。主工作区本轮零写入，未推送。

改动：新增 `scripts/assets/export_manor_v3.py`（读交付 .blend 导出游戏 GLB，只读源文件并校验
sha256；V4 起改名 `export_manor.py`，见后一条记录）；`game/presentation/manor/manor.glb` 由新导出替换（86 058 980 字节，5329 视觉对象、
133 万三角面、77 材质、36 内嵌贴图、60 756 走行碰撞三角面）；Godot 按既有
`embedded_image_handling=1` 抽取出 36 张 `manor_*_{basecolor,normal}.png` 并入库；删除旧 GLB
抽取出的 11 张 `manor_Godot_MS_*.png` 及 `.import`（无场景引用）。新增
`docs/manor-model-import.md` 记录来源、导出取舍、契约与限制。`world.tscn`、走行、交互、
`imported_door_collision`、房间识别、NPC、物品与本地化均未改动。

契约保持：十个门铰链名、`ManorWalkCollision-colonly`、`-colonly` 走行网格与三条坡道、
Blender `(x,y,z) -> Godot (x,z,-y)` 坐标映射、门把手不进视觉与走行网格（ADR 0008）。
作者灯光、相机、平面标注、屋顶源集合未进入游戏 GLB。

验证（固定引擎 4.7.2.stable.official.ed1daf0bf，均在 worktree 内）：架构检查 128 个源/场景
文件通过、3 项负向用例通过；`--editor --import` 退出码 0（12.5 s，39.8 MiB
`manor.glb-*.scn`）；`res://tests/run_tests.gd` 为 `AIRPG_TESTS: 354 checks, 0 failures`
（BASE 95 / ARCHIVE 62 / MANOR 93 / NPC_RIG 12 / CHARACTER 38 / INTERACTION 54），
MANOR 与 INTERACTION 套件实例化真实 `manor_play.tscn` 并打印 `AIRPG_STRUCTURE_WALK_READY`；
`--quit-after 5` 出现 `AIRPG_BOOT_READY`。真实窗口（RTX 4060 / OpenGL 兼容）用
`tests/manor/capture_main.gd` 截取走廊视图，模型、光照、HUD、房门与提示均正常；
导出的 GLB 回导 Blender 渲染与交付包 `preview_overview.png` 外观一致。

`./scripts/verify.ps1` 未原样跑通：import 步骤因本机既有的
`ERROR: Failed to read the root certificate store.`（`os_windows.cpp:2582`）触发其错误输出
判定而中止。该行与本仓库内容无关——只有 `project.godot` 的空工程跑同样的导入会复现同一行；
本轮按既有做法用逻辑等价驱动执行三步（相同参数、错误正则与完成标记，仅登记该环境行），
未放宽其他判定。另需记录一次事故：第一轮验证时 import 曾出现一个 Godot 进程卡死
（单线程空转、日志被独占、15 分钟无写入）；会话中断未终止后台作业，残留进程被强制结束后
删除 `game/.godot` 重新导入即恢复正常，可重复。重跑前请先确认无残留 Godot 进程。

未实现/待复核：未做 LOD、合批、显存与帧率验收，5244 个网格实例的绘制调用是本轮导入的
主要性能风险；家具、道具、墙面与庭院装饰无碰撞，室外新增石路不在走行网格内；未做导出包、
低配机器与不同 DPI 验收；独立对抗复核待分配。复核重点：门净空与楼梯净空在新家具布局下是否
仍然成立、侧门出生点到门廊的实际走行、以及 5000+ 节点场景的加载与帧率。

## 死光 UI 合并 PR：轻量 HUD + 调查员手记（2026-10-03）

用户要求把本地已完成的《死光》UI 工作适配到最新主仓库，并提取一个合并 PR：一是 `D:\AIRPG\AIRPG` 中未提交的探索 HUD 与 E 键手记实现（基于 921556a），二是评审稿提交 `455fe93`（`docs/ui-design/`），三是同一目录随后完成的开始界面封面改版（见下一节记录；该节由封面工作本身撰写，其中的验证数字属于其自身基线）。工作包 U-DEADLIGHT-UI / 负责人本任务 / 独立对抗复核待分配；分支 `feature/deadlight-ui`，基线 `88c9ef0`。

适配取舍：`character_hud.gd` 以新手记版式为准，同时保留 main 的物品系统能力——`item_dropped` 信号、拿在手上/收回/使用手持物品，以及「丢弃一个」走 `drop_item` 并在成功后发出稳定 ID（保持丢弃生成世界物品的闭环）；旧档案页的演示预览按钮随旧版式移除，service 层 `preview_action` 保留。`walk_hud.gd` 以房间式 HUD 为准并补回 main 需要的 `show_ui_state()`，`walk_hud.tscn` 新增 `Status` 标签承载交谈/手记状态。两侧本地化键与 handoff 记录全部保留，`walk.help`/`walk.note` 合并为同时描述 F 交互与 E 手记。为满足单脚本 300 行约定，手记版式构建拆到新文件 `presentation/character/notebook_view.gd`（224 行），`character_hud.gd` 由 354 行降至 163 行。

验证：架构检查通过（128 个源/场景文件），3 项架构负向用例通过；Godot 导入、`res://tests/run_tests.gd` 聚合 354 项检查 0 失败（BASE 95 / ARCHIVE 62 / MANOR 93 / CHARACTER 38 / NPC_RIG 12 / INTERACTION 54）、启动标记 `AIRPG_BOOT_READY` 通过。本机只有 Windows PowerShell 5.1、未安装 PowerShell 7（`scripts/verify.ps1` 使用 `[IO.Path]::GetRelativePath`），统一 verify 无法原样执行，改用逻辑等价驱动：架构门禁为仓外逐字副本、仅改写该 PS7 调用，Godot 三步的退出码、错误正则与成功标记与 verify 一致；Windows 根证书库读取失败为本机既有环境问题（本文件已多次记录），仅在报告中显式豁免并计数，未放宽其他检查。

未实现/待复核：手记线索与人物页仍为明确空态；未做真实键鼠与不同 DPI 人工走查、无导出包验证；独立对抗复核待分配。

## 封面换成整幅雨夜庄园图（2026-10-03）

用户给出新的封面效果图，要求把封面页变成该图并保持原有交互不变。范围限
`game/presentation/menu/**` 与开始界面文档；未改 PRD、路由、本地化、共享契约或引擎版本。

改动：`start_screen.tscn` 删除 Smoke / Atmosphere / FateSigil / 三条轨道 / Logo /
CelestialLights，改为 `Artwork/Cover`（整幅 `art/cover_night_gate.png`）与
`Artwork/LogoShine`（`art/cover_logo_shine.png` + 原 `foil_shine.gdshader`）；
菜单容器移到 (399,588)–(639,854)、间距 25、`menu_entry.tscn` 最小宽度 480→240，
使三行文字中心落在效果图对应位置（x≈519，y≈624/721/818），柔光细线与菱形也对齐图内原有装饰线。
`start_screen.gd` 只删掉 `%Smoke` 引用，焦点链、开场淡入、离场、导航与退出信号一律未改。

效果图本体在图内自带 AIRPG 字标与三个菜单文字，已用局部背景估计把文字、细线、
菱形和文字下方光带从底图抹除，再由真实菜单在同一位置绘制；未抹除区域与原图一致。
字标区域另裁出带 alpha 的扫光层以保留原有金属反光动效。旧图层素材与
`fate_sigil.gd` 保留在 art/ 目录，可整体回退。

验证：固定引擎资源导入通过；`--headless --script res://tests/run_tests.gd` 为
`AIRPG_TESTS: 273 checks, 0 failures`（BASE 95 / ARCHIVE 62 / MANOR 78 / CHARACTER 38）；
`--quit-after 5` 含 `AIRPG_BOOT_READY` 且无脚本错误。真实图形窗口 1920×1080
（OpenGL 兼容 / Intel Iris Xe）截图与效果图 50% 叠加核对：背景完全重合无重影，
菜单三行误差 ≤3 px；另截图确认焦点移到「退出游戏」时柔光与菱形随之移动，交互未变。
截图见 `artifacts/start_before.png`、`start_after42.png`、`blend_ref_42.png`、`start_focus_exit.png`。

未做：本机只有 Windows PowerShell 5.1，没有 PowerShell 7，`./scripts/verify.ps1`
（要求 pwsh 7，且 `check_architecture.ps1` 用到 .NET Core 的
`[IO.Path]::GetRelativePath`）无法运行，架构静态检查未执行；本轮改动只新增
presentation→presentation 引用、未新增 .gd/.tscn/.tres，文件数不变。日志仍报
本机既有的 `user://logs` 写入失败与根证书读取失败。未做不同 DPI/宽高比、
导出包字体与纹理、手柄导航复核，也未提交或推送。

## 主工程庄园与角色原型整合（2026-10-02）

用户要求把 output/manor_structure_playtest 与本任务 E 档案/角色背包合并到主工作，替换雨夜汽车部分；随后确认已自行测试，要求停止测试并直接推送主仓库。工作包 A-MANOR / 负责人本任务 / 独立复核待分配；基线 ae866cd。主 game/ 现可从主菜单进入故事档案，再由 deadlight 的「进入庄园原型」按钮进入第一人称结构场景；封面/简介已替换为庄园预览与原型说明。

完整结构模型、屋顶/天花板、侧门三阶、室内门口、地窖楼梯来自结构原型；角色领域/应用用例与 E 四页 UI 来自 greenapple 原型。bootstrap 显式注入本地启动端口，每次进入新建演示角色服务；SceneHost 在庄园模式忽略鼠标事件，E 阻断移动/转向，F1 返回并释放鼠标。R/B 只复位位置。原始 output 与源 Blender 文件保留，主工程只引用 game 内资源。目录 v1、正式故事状态、存档格式、PRD 和引擎版本不变；说明与契约更新见 ADR0007、manor-integration.md。

用户要求停止测试前已完成统一 verify：94 文件架构检查、3 项负向用例、导入/启动通过；BASE95、ARCHIVE62、MANOR36、CHARACTER38，合计231项零失败。主工程三张 RTX4060 渲染图已核对。此后只补齐交付文档与提交推送，不再追加测试。独立对抗复核、不同 DPI、导出包与长期性能待验收；正式剧情、AI、检定、真实拾取、门互动及存档未实现。

本次提交范围是主工程整合代码、所需资源、测试入口与文档。已有 .idea 暂存、project.godot 的格式变化、旧图导入变化及 output 源原型不随本次提交，保留在工作区。推送目标 origin/main；提交哈希以 Git 日志为准。

## E 键档案四页界面（2026-10-02）

用户参考图仅作为分区依据，要求 E 打开对应 UI、把数据显示在对应位置；“继续”后完成。工作包 I-GA4 / 负责人本任务 / 独立复核待分配；范围限 output/greenapple_manor_playtest 与文档。全屏调查员档案包含总览、技能、随身物品、背景与经历四页。总览左身份/生命理智、中属性/背景、右技能/物品摘要，头像与图标使用色块占位。E 开关、Esc 关闭，不占用 Tab 焦点遍历；打开时释放鼠标并阻断移动/转向。

profile 从统一数值扩为 attributes/skills 字典及可空年龄/背景键，bootstrap 合成夹具注入；维持原数值（血量70/100、理智60/100、六属性50、侦查心理学40），不复制参考图里的数字。未导入技能、年龄及背景显示“待导入”。领域状态格式不变；UI 仍只调用应用用例，多页共享深拷贝视图、物品操作同时刷新血量和数量且不切换当前页。新展示脚本 archive_widgets/overview 与新 .gd.uid 已保留。ADR0006 已同步扩展和消费者说明。

验证：原型 verify.ps1 全通过，21文件依赖检查、70项零失败（含38项角色边界/失败回滚）；E开关/按住、四页、字段映射、跨页更新、关键物品操作与输入阻断已检查。主工程 scripts/verify.ps1 全通过，156项零失败、3项负向检查。四页真实 Godot RTX4060 截图已核对，见 preview_archive*.png。未做不同 DPI/真实外部设备/独立对抗复核；正式数据、存档与正式美术未实现。README 顶部为当前说明，旧 Tab/I 说明属历史。

保留原有未提交改动（包括其他任务新增的模型及接续记录）；未改正式 game/、源 .blend、PRD 或共享状态格式，无提交/推送/发布/PR。

## 庄园走廊侧门与三节台阶修订（2026-10-02）

用户要求把走廊位于艾米莉亚卧室与接待室之间的部分改为一扇门，经三节楼梯进入；按原结构图左侧蓝线的位置实施。通过现有 Blender MCP 实时场景把 `Hall_W` 窗改为 `SideEntry` 内开侧门（净宽 1.10 米），移除窗下墙并重建两侧墙垛 / 门楣；门外三节实体石台阶，宽 1.30 米、深 320 mm、每级约 153.3 mm，从室外 −0.46 米衔接走廊 0 米，未调整室内房间标高或增加陈设。

修改前完整当前实时模型备份为 `output/manor_structure_v2/manor_structure_before_side_entry.blend`，保留手动改动；更新同目录 `manor_structure_final.blend`、GLB、资产报告及各预览，新增 `preview_side_entry.png` 入口特写。修订后 737 对象 / 704 网格、10 门 / 12 窗；51 项入口位置、所有门口 56 cm 射线抽样、三节踏步实体支承 / 连续衔接 / 等高检查通过，预览已视觉核对。独立复核待分配，Godot 玩家体积碰撞与楼梯净空仍待接入复核。

再次运行 `./scripts/verify.ps1`：75 文件架构检查和 3 项负向检查通过，导入仍因 Windows 根证书及 Godot 用户配置保存错误失败，未放宽检查。仅改独立美术目录和接续记录，未修改正式 game/、PRD 或共享契约，无提交 / 推送 / 发布。

## 参考图庄园结构 Blender MCP（2026-10-02）

用户要求按第一张结构图和第二张风格图建模，后收敛为只做房屋结构，并要求实时监督。工作包 I-MANOR2，负责人本任务，独立复核待分配；基线 ae866cd4cdbdf3c967c4ae2e19ebed29f0735780。独立目录 `output/manor_structure_v2/`，未覆盖旧庄园或接入正式 game/。按原图保留艾米利亚书房 / 卧室、卫生间、医生卧室 / 书房、接待室、厨房、右下门廊、折形走廊和接待室左下凹口；无家具、人物、剧情物件或新故事事实。

本轮实际使用已缓存 MCP for Blender 2.1.0、插件 1.7 / protocol 11，通过 stdio MCP ClientSession 在 Blender 5.2.2 LTS 实时 GUI 场景中分阶段搭建、保存、渲染和导出；安全模式开启、遥测禁用，没有安装插件或修改全局配置。用户可直接监督同一窗口；另开磁盘文件不自动同步。在独立重开检查期间检测到原磁盘文件被再次保存，因此保留 `manor_structure.blend` 原样，把 MCP 窗口最终状态另存为 `manor_structure_final.blend`，不覆盖可能的手动操作。

最终 `.blend`：745 对象 / 714 网格，米制尺度，字体已打包；灰泥墙、砖勒脚、分格木窗、实木门、深灰交叉坡屋顶、两处烟囱、木地板 / 奶油内墙和简单空地窖。图中无尺寸、门窗和屋顶设计，以 25 图像像素 / 米保持相对比例，最大轮廓 16.84×20.6 米、层高 2.95 米；9 门 / 13 窗、地窖 −2.72 米、16 级 170 mm / 210 mm 木楼梯。这些尺寸和开口是可调整的美术假设。屋顶、天花板、上半墙、标注、屋顶源体块分集合保留；默认隐藏屋顶 / 天花板作俯视查看。

交付最终原文件、基础色 GLB、外观 / 最终中文俯视 / 剖视 PNG、README、asset_report.json。GLB 不烘焙 Blender 程序纹理。42 项构件 / 尺度 / 56 cm 门口中心线抽样射线 / 地窖开口检查通过；独立 Blender 进程重新打开最终文件、核对打包字体、GLB 二进制头和重新导入通过（705 网格、9 个门铰链）。渲染与 MCP 视口已视觉检查。复核重点：门扇 / 玩家胶囊碰撞、楼梯头顶净空、导航和性能，当前未在 Godot 实装或验证；独立对抗复核未完成，模型不是正式可玩功能。

已按约定运行 `./scripts/verify.ps1`：75 文件架构检查和 3 项负向检查通过，导入被 Windows 根证书读取与 Godot 用户配置目录保存错误阻断，统一验证未通过；未放宽检查或改引擎。原用户未提交改动保留，本轮只新增独立资产目录及本接续段；未提交、推送、发布或创建 PR。

## 庄园背包与角色原型（2026-10-02）

用户要求先在现有庄园制作背包/血量/角色信息，UI 仅占位。本轮 C-GA3，负责人本任务，独立复核待分配；沿用 output/greenapple_manor_playtest 独立目录。新增 domain/character 原子状态、application/character 只读用例、presentation/character 占位 HUD、bootstrap 合成夹具；输入适配器负责背包开关期间阻断移动/转向及释放/恢复鼠标。Tab/I 开关，Esc 关闭，头像为矩形占位。

常驻血量/理智、角色身份/属性/技能占位、三类物品、数量/说明、使用/丢弃与演示受伤/理智/补给/数据重置。消耗与回血原子提交，满血不消耗、关键物品不可丢弃，过期 revision 与坏候选拒绝且不变状态。深拷贝视图、每次独立会话；R/B 不影响角色数据。没有存档、死亡/疯狂后果、真实拾取、正式人物/规则/道具；重启恢复初始演示数据。ADR 0006 记录仅限原型的内存 v1 格式，不扩展正式 StateStore 或存档 Schema。生产脚本在 300 行内，未放宽依赖规则。

验证：原型 verify.ps1 通过（19 文件依赖检查；60 项零失败，包含 37 项角色/物品边界以及原庄园/第一人称/面板阻断/按钮联动；导入和启动标记通过）；主工程 scripts/verify.ps1 通过，156 项零失败、3 项架构负向检查。preview_inventory.png 为 RTX4060 实际游戏渲染，已核对中文占位面板与血条。新增 .gd.uid 保留。独立对抗复核与真实键鼠/不同 DPI/导出包未验收，重点是重复/过期命令、满血不消耗、失败回滚与焦点返回。

原用户未提交改动保留；未改正式 game/、源 .blend、PRD 或共享契约，无提交/推送/发布/PR。运行仍为该目录 game/project.godot 后 F5。

## 庄园第一人称试验（2026-10-02）

用户要求改为第一人称并测试。仅改 output/greenapple_manor_playtest：相机绑定玩家、眼高 1.5 米、透视 FOV75、鼠标 yaw/pitch（±80°），WASD 按 yaw 移动、隐藏自身精灵，取消墙体和楼层剖视。输入适配器处理 Esc/左键恢复、失焦释放鼠标与停止移动，退出释放鼠标。R/B 保留测试复位与楼层传送。原 .blend 和正式 game/ 未改。

模板 verify.ps1 通过：13 文件架构、17 项物理与第一人称行为零失败、导入与启动标记通过。主工程 scripts/verify.ps1 通过：156 项零失败、3 项负向检查。RTX4060 实际截图 preview_first_person.png 已检查。源模型没有天花板，抬头可见背景；完整家具/门口人工走查、真实鼠标捕获交互、性能和导出包尚未验收。README 顶部为当前版本说明，旧剖视与跟随描述只作历史记录。

## 庄园镜头跟随调整（2026-10-02）

用户要求拉近摄像机并跟随玩家，并明确测试由用户执行、本轮仅编辑。修改 output/greenapple_manor_playtest：正交 size 从 22.5 调为 12，保持 50° 俯角；bootstrap 注入既有相机并按帧率无关的指数平滑跟随角色上身及楼层高度。R 复位/B 切层立即同步镜头，移除固定楼层相机 Y 值。camera_view_size 与 camera_follow_speed 可在根节点脚本属性调整。同步截图工具及 README，但未运行引擎、测试或生成新截图；此前截图和验证数字不代表本次修改已通过。未改正式 game/ 或源 .blend。

## 绿苹果庄园 Blender 美术地图（2026-10-02）

用户要求通过 BlenderMCP 制作《死光》绿苹果庄园，室内探索优先。本轮工作包 I-GA1，负责人为当前任务，独立复核待分配；依赖提交 `ae866cd4cdbdf3c967c4ae2e19ebed29f0735780`。独立交付目录 `output/greenapple_manor_v1/`，未接入正式 `game/`、PRD 或内容包。主屋 18×12 米（墙体轴线）、层高 2.8 米，走廊净宽 1.44 米；入口/接待室、医生书房/卧室、艾米利亚卧室兼书房、厨房餐厅、卫生间、16 级地下楼梯、后接谷仓车库齐全。地下室实际标高 −2.8 米，设备/工具为视觉模型，没有电力陷阱或剧情逻辑。完整屋顶、上半墙、天气、定位空对象分集合保留；默认室内剖视。

交付 `.blend`、主体与屋顶两个 `.glb`、室内/俯视/地下室渲染、中文平面图、资产检查报告与 README。原文件 2479 个场景对象；主体 GLB 约 10.7 MB、2348 网格、30 材质、13 内嵌纹理。原生简化三维美术原型，非最终半写实插画、非已可玩的正式场景。只采用用户给定场景信息；参考图未复制人物、尸体、超自然实体或剧情线索。几何/小型贴图为本轮原创，没有外部素材依赖。初始建模脚本仅用于搭建，手工编辑 `.blend` 后不要重跑覆盖。

验证：44 项尺度/楼梯/门口抽样射线检查通过；修正工具架浮在地面层、台灯遮光、车库中柱和厨房橱柜挡后门。新 Blender 进程重新打开 `.blend`、重新导入 GLB 和检查二进制文件成功，所有生成纹理已打包，无默认 Cube/屋顶/雨丝误入主体。三张渲染及中文平面图已视觉检查。独立对抗复核、Godot 材质/玩家胶囊/楼梯头顶净空/导航/触发器/性能/导出包未验证。

BlenderMCP 初始连通后断线；已请求用户重新启动服务，但未恢复。本轮实际模型通过同版本本机 Blender 5.2.2 后台完成，不能宣称已在 MCP 实时视口验收。用户重连后先读当前场景，保留其未保存改动，再载入本轮原文件检查。

按约定运行 `./scripts/verify.ps1`，75 文件架构检查及 3 项负向检查通过；统一验证因 Windows 根证书库读取错误失败于导入阶段。首次用户配置目录保存错误经临时 APPDATA 目录消除，但证书错误仍在，没有修改检查脚本或放宽错误匹配。另行执行固定 Godot，156 项行为检查零失败，聚合与 `AIRPG_BOOT_READY` 标记出现；由于证书错误，统一验证仍为未通过。详见 `artifacts/greenapple-main-tests.log`、`greenapple-main-boot.log` 和资产 README。

原工作区未提交改动保留；没有提交、推送、发布或 PR。后续优先做碰撞/楼梯净空与门口测试、俯视墙体隐藏、网格合批和授权正文场景对照，不能直接将定位空对象升级为正式线索或事件。

## 2.5D 场景模板（2026-10-02）

用户要求搜索 GitHub 可借鉴开源项目并搭建 Godot 模板。本轮交付独立 `output/scene_25d_template/game/project.godot`，固定 Godot 4.7.2；未修改主工程接线、PRD、共享契约或正式内容。调研官方 godot-demo-projects 的 misc/2.5d、crystal-bit/platform-3d、tbh272/2.5D-Platformer；第三方仅做技术思路参考，未复制代码或资产，亦未下载运行这些项目。

模板是原生 3D 可编辑几何 + 45° 正交镜头 + 平面 AnimatedSprite3D，复用本机 investigator_noir_v4 图集和收步控制器。含道路、建筑/车辆/箱子占位、前景深度遮挡、冷暖灯光、WASD 移动、碰撞与 R 复位。输入适配器由 bootstrap 装配；固定提示走 CSV 本地化。无正式剧情、探查、互动、规则、存档、雨雾或联网能力。生成工具仅用于初始搭建，编辑 world.tscn 后勿重跑。README 与 ADR 0005 记录方向、来源和接入边界。

验证：模板依赖检查 10 个源/场景文件；8 项实际物理帧移动/停止/碰撞/边界/复位/镜头检查零失败，导入与 AIRPG_25D_READY 标记通过。主工程 ./scripts/verify.ps1 通过，156 项零失败、3 项架构负向检查，真实启动标记完整。RTX 4060 / OpenGL Compatibility 实际渲染自动截图 preview.png 成功，已检查几何、角色和中文提示可见。独立对抗复核、不同 DPI/宽高比、导出包和正式玩法接入未完成。

原有未提交文件未清理或覆盖。无提交、推送、发布或 PR。模板 .gd.uid 随交付保留，.godot 忽略。

## 调查员动作 demo v4（2026-10-01）

用户决定沿用此前黑色电影调查员动作 demo，并要求细化帧率、增加停止走动动画。本轮未改 `game/` 正式工程；在 `output/investigator_noir_v4/` 新建独立交付包，沿用 v3 的 16 张透明原画，将步行节奏从 6 fps 调整为 8 fps，并增加展示层动画控制器。松开移动时，控制器按当前 0–3 脚步相位播放 1–3 帧收步序列，再落到对应方向待机；重新移动会立即取消收步。

内置图像编辑服务对新增中间帧请求返回 `invalid_image_request`，所以本轮没有宣称生成新的逐帧原画。真正的每方向 8 张步行帧和独立停止原画仍待后续补绘。验证与限制见 `output/investigator_noir_v4/README.md`。工作区原有 `.idea/.gitignore`、`game/project.godot` 和 `output/` 状态未擅自清理或覆盖。

## 最新协作与验收（2026-09-28）

用户已亲自检查侧栏式档案改版并表示“没问题”，并明确表示以后测试和验收由助手负责，
本人不再主动运行测试或操作游戏窗口；窗口自动操作已按用户 Escape 中断停止。
此后每轮交付由助手跑 `./scripts/verify.ps1` 并说明实际结果，不再要求用户代跑。

本轮将档案页改为左侧固定档案栏、右侧全幅场景，移除列表序号。标题/标签/简介
拆成独立组件；当前开发配置可见三个有明确标识、不可启动的占位选项。
占位开关和发布隔离见 ADR 0004。正式《死光》目录未修改，主菜单美术未改。

## 故事档案合入（2026-09-28）

本轮来源为 `feature/story-archive` 的两个提交 `2f2a18a`、`0328457`。该分支是从
开始界面 `fb2272c` 长出来的，底下压着 I1 对话视图、G1 DeepSeek 传输和灰盒探索接线；
直接合并会把这些无关模块带进 main。因此没有合并分支，而是在 `main` 上新建
`feature/story-archive-isolated` 只 cherry-pick 这两个提交，丢掉继承历史。

主菜单 Start 接 story_archive，默认 deadlight；档案列表、插画、简介、标签和启动边界，
以及进入、切换、返回动画都已在。主菜单美术与布局未改，返回时跳过长开场。
故事元数据、本地化和原生美术资源表可扩展，雨夜道路插画已在项目内。
实际游戏启动仍未实现：端口明确拒绝、恢复档案页，不跳灰盒也不走假流程。
天气与音频按本次范围不实现。文件清单、资源来源与边界见 `docs/story-archive.md`。

冲突解决只保留本功能需要的东西：`main.gd` 不引入 exploration/GreyboxComposition 路由，
路由表加 `story_archive`；`run_tests.gd` 保留本机已修好的启动断言（开始界面为启动路由），
只追加档案套件与 `AIRPG_ARCHIVE_TESTS` 标记；`verify.ps1` 的套件断言只列本分支存在的
`BASE_TESTS`、`ARCHIVE_TESTS`，没有照抄 C1/I1/G1/INTEGRATION 那几项。

隔离后的实测结果：`./scripts/verify.ps1` 通过，行为检查共 156 项 0 失败
（`AIRPG_BASE_TESTS` 95 + `AIRPG_ARCHIVE_TESTS` 61）；架构检查 75 个源/场景文件、
3 项负向、引擎导入与真实启动通过。另用真实图形窗口渲染档案页并截图核对：
左侧固定档案栏、右侧全幅插画、标题/标签/简介分区、无序号，三个预览项带
「预览占位」标识，页脚「共 4 项」与 `catalog.json`（1 个正式目录项）加
`preview_catalog.json`（3 个占位）一致。来源分支记录的 724 checks / 61 项档案数字
属于含 I1/G1 的旧分支，与隔离后的 main 不可比，故在此只记隔离后的数字。

## 开始界面合入（2026-09-27）

用户确认美术检查无问题后，把 `feature/start-screen` 的开始界面部分合入当前开发分支。
只带界面本体，不带同一分支上游的波次 2 接线，因此本轮没有引入 I1 对话视图、
G1 DeepSeek 适配器和灰盒探索路由；那些仍只在 `integration/slice-wiring` 上。

来源提交 `fb2272c`；合入文件：`game/presentation/menu/**`（场景、脚本、着色器、素材）、
`game/data/localization/zh_CN.json` 的 `menu.*` 三条、`scripts/start_game.ps1`，
以及 `docs/start-screen.md`、`docs/start-screen-art.md`。手工改写的只有
`game/bootstrap/main.gd`：`home` 路由从 `presentation/shell/home.tscn` 换成开始界面，
并接上 `quit_requested`，在切换视图和释放旧视图时断开。

`home.tscn` 与 `shell_view.gd` 未改动，仍由 `workspace.tscn` 使用。
没有把对话/探索接线、`verify.ps1` 的套件数断言和波次 2 文档段落一并带入。

本机合入提交 `b721f3c`。验证：`./scripts/verify.ps1` 通过 —— 架构检查 52 个源/场景文件、
3 项负向检查、引擎导入（三个新纹理重新导入）、行为测试 95 项 0 失败、真实启动含
`AIRPG_BOOT_READY`。另做一次非 headless 图形启动（RTX 4060 / OpenGL 3.3.0 兼容模式），
日志 `artifacts/start-screen-gpu.engine.log` 无脚本、纹理、着色器错误并含启动标记；
截图确认 Logo、烟雾、轨道和文字菜单正常绘制。

`run_tests.gd` 的启动断言原先跟着 `shell_view` 走，换成开始界面后会抛脚本错误并让进程
永久挂起。现改为断言开始界面为启动路由、导航到 workspace、返回后再次显示开始界面，
并加 300 秒预算，超时判失败而不是挂住。离场淡出（0.3 秒）的时序没有断言语义：
`--script` 运行下 `process_frame` 推进远慢于真实时间，已如实留作展示层测试。

未做：菜单淡出/重复点击的手工时序复核、不同 DPI 与宽高比、导出包字体与纹理、
手柄连续导航、性能预算。开始界面合入路径本身尚未做独立对抗复核。

更新：2026-09-26。任务：建立 AIRPG 工程架构骨架并完成并行开发前置门槛。

## 已完成

- 已读 PRD v0.1；本地引擎实测 `4.7.2.stable.official.ed1daf0bf`。
- Godot 工程在 `game/`，纯业务层、应用端口、基础设施、UI 和组装入口分离。
- 已实现内容目录校验、布尔条件、状态原子提交、随机检查点、默认禁用模型和内存存储测试适配器。
- 启动配置、本地化、输入绑定、场景路由、只读诊断已接入真实主场景。
- 架构/契约/岗位工作包/ADR/协作规则与测试说明已落盘。
- 提供统一质量命令和 GitHub Actions 工作流；新引擎下载流程校验 SHA-256 与版本。
- 已建立首次 Git 基线提交 `2cbf399`，后续可以从共同基线创建独立 worktree。
- A1 已冻结探索命令、对话安全展示和模型传输错误/生命周期的最小接缝。
- J0 已明确独立测试套件/替身目录和单一聚合入口规则；新增 A1 契约回归测试。

## 验证结果

`./scripts/verify.ps1`：94 项 Godot 行为/集成检查，0 失败；3 项架构负向检查；导入、依赖检查与真实启动通过。
全新下载 `.tools/ci-godot/` 中的固定引擎后可重复同一流程。
验证日志保留在 `artifacts/`，不提交。GitHub 云端工作流尚未运行；没有图形窗口人工视觉验收或发布导出。

## 代码与 Git 状态

用户指定远程为私有 `git@github.com:november521/AIRPG.git`；上一阶段已确认 SSH 可读。仓库已有本地基线提交，尚未推送。
PRD 与已有 `scripts/setup_local_mcp.ps1` 未改动。后续按工作包创建独立分支/worktree；不要从以前错误关联的
MCphone 引用开始开发。
`.tools/`、缓存、测试日志都在忽略范围；不要把工具、外部凭据或授权原始资料无差别加入 Git。

## 尚未实现

真实场景/角色/移动/检定、AI 网络与知识/语义校验、磁盘存档、完整会话日志、美术声音、导出与性能预算。
内容 Schema 是元数据目录信封，没有正式剧情业务字段。StateStore 目前只覆盖布尔标记，不是完整游戏状态模型。
角色、公式、具体剧情与线索、模型协议/预算、重试策略、保存节点继续遵循 PRD 待确认项。

## 下一步入口

先读 `docs/workstreams.md`、`docs/contracts.md`、`docs/parallel-development-plan.md` 和 ADR 0002。
A1 已完成；下一步从最新 A1 提交分别建立 C1 灰盒、I1 对话 UI、G1 传输 worktree，并让 J 对抗侧跟随复核。
不要让功能分支修改 Composition、公共端口、全局 Schema、本地化和测试聚合入口。正式《死光》内容仍等待
授权正文和调查员选择。
新的工作开始前检查 `git status` 与文件修改时间，保留其他任务的改动，然后运行统一验证建立基线。

## 额度与中断

本轮交付前最后一次用量检查显示五小时剩余 4%、周剩余 76%，另有 3 次可用重置额度，未使用重置。
记录的是检查当时数值，不代表后续实时余额。需要继续时先从本记录恢复，再查询最新额度；若达到重置条件，使用每次重置前的明确用户确认流程。
不可承诺自动购买、自动无限续额或在额度耗尽后无条件继续运行。




# COC 参考人物卡设计（2026-10-02）

用户要求依据 Downloads/COC7空白卡CY23Final.xlsx 设计项目属性并给出图片。本次只读提取工作簿，以 PRD 六属性为边界，交付 `output/character_card_design_v1/属性与人物卡设计建议.md` 和 `调查员档案概念图-v1.png`。使用内置 imagegen 生成，已视觉核对六属性、五技能、生命/理智、页签与演示标记；图片为 16:9 概念稿，实际字体、布局与交互需在 Godot 重新实现。生成提示词随目录保存。

力量/敏捷/体质/智力/感知/魅力保持 PRD；建议将教育放入背景与学识，意志先作为背景/专长的待评审方向。未冻结点数、概率、生命/理智公式，未改正式角色/状态契约、PRD 或已有庄园原型。图片人物、物品与数值为演示，不代表正式内容。复核重点：属性技能重复计益、技能值被当成概率、感知/心理学泄露秘密、合成数据误入正式配置；独立对抗复核待分配。

已尝试 `./scripts/verify.ps1`，默认引擎返回版本字符串为空，在版本检查阶段失败，未放宽检查；本次工程验证未通过。未提交、推送、发布或创建 PR。保留此前未提交改动，接续时从设计说明评审属性职责与规则决策，再启动 D1/UI 工作包。



## 新参考布局庄园接入 Godot（2026-10-02）

用户要求将第一张结构图、第二张英式乡村风格参考建成的结构模型接入 Godot，并亲自体验。本轮新建 `output/manor_structure_playtest/game/project.godot` 独立第一人称结构原型，来源为 `output/manor_structure_v2/manor_structure_final.blend`，只读转换，源模型 SHA-256 记录于 `export_report.json`。保留完整屋顶、天花板、10 扇打开的门、12 扇分格窗、用户修订的侧门与三节台阶以及地窖。707 个导出可见对象，59020 个碰撞三角形，3 处连续楼梯碰撞坡面；补简化砖木贴图、室内照明、胶囊角色与鼠标视角，出生点在新侧门外。

操作：WASD、鼠标、Shift 慢走；Esc 释放鼠标，单击继续；R 回侧门，B 到地窖。`开始体验.cmd` 和 `start.ps1` 可再次启动。Godot 固定版本实测为 `4.7.2.stable.official.ed1daf0bf`。真实图形启动日志 `artifacts/manor-structure-playtest/interactive.engine.log` 含 NVIDIA RTX 4060 / OpenGL 兼容渲染和 `AIRPG_STRUCTURE_WALK_READY`，当前启动日志无资源或脚本错误。

按用户最新指示“测试我来做就行”，本轮仅处理资源导入和启动问题，未运行新增通行测试或根工程 `scripts/verify.ps1`；`game/tests/run_tests.gd` 与独立 `verify.ps1` 已准备，未宣称通过。初次导入缺失中文翻译资源，随后已由 Godot 生成并保留原生 `.translation` 与 CSV 源，正常启动已确认。通行、楼梯头部空间、室内视野由用户实际体验，独立对抗复核待分配。

范围只含房屋结构体验；没有家具、正式剧情、存档或开关门交互，未接入正式菜单。未改写原 Blender 文件、正式 `game/`、PRD 或共享契约；未提交、推送、发布。保留原有未提交改动。后续入口为新试玩目录 README，重点复核侧门三阶双向通行、地窖上下楼与底部转身、各门洞及实体墙阻挡。

## 工作树整理（2026-10-02）
已删除根目录10个递归无文件且无链接的乱码空目录。全部源码、未提交成果、output、分支及工作目录保留。6个干净工作目录待用户批准移除checkout（保留分支），详见 docs/worktree-cleanup.md。verify.ps1 在引擎版本检查阶段失败，--version返回空；未放宽检查。后续先取得批准，再逐个复查状态并移除；禁止强制删除有改动工作目录。


## 庄园 UI：轻量 HUD + 调查员手记（2026-10-03）

按已评审方向实现探索 HUD 与 E 键双页手记。探索时左上地点、右上生命/理智、右下随身物品入口；打开后遮暗场景、释放鼠标并阻断移动和视角，E/Esc/关闭按钮返回。手记左页为物品列表与类别，右页为选中物品的描述、数量和原有使用/丢弃用例。未接入的线索与人物类别明确显示空态。所有新增可见文本在 zh_CN.json；角色与物品仍为现有演示数据。运行 `--headless --script res://tests/run_tests.gd` 覆盖打开、关闭、切页、移动阻断及使用物品状态更新。正式线索、人物记录与道具美术仍待内容和资源接入。

## 庄园房间提示与旧式手记细化（2026-10-03）

按用户结构图从 manor.glb 的地板网格边界实现房间识别：接待室、厨房、带屋檐的门廊、走廊、艾米莉亚卧室/书房、韦伯医生卧室/书房、卫生间、地窖楼梯和地窖；室外另有退路。进入区域时左上显示房名，左下显示一条悬疑氛围文案，文案都在 zh_CN.json，未写入正式剧情事实。右上生命/理智蒙版 alpha 从 0.78 降至 0.59，圆角 12；右下更名“调查笔记”，用原生线绘书本图标。

手记用 notebook_paper.gdshader 绘制纸纤维、横线、红色页边、书脊与皮革边；正文改用系统楷体回退，演示物品有原生墨线小图。用户参考图仅作设计参考，未把带示例剧情/物品的截图作为游戏资产。1280×720 的 OpenGL 兼容渲染已检查，截图在工作区临时集成目录中；并通过 273 项 Godot 回归测试及 97 文件架构检查。原型数据仍是演示内容，线索和人物页仍为明确空态。

## 房间定稿文案与手记纸张调整（2026-10-03）

按用户给定的 12 个编号和既定房间顺序，替换了庄园外、门廊、接待室、厨房、走廊、两位人物的卧室/书房、卫生间、地窖楼梯与地窖的左下提示文案。文案仅描述空间观察，不新增剧情事实。手记改为独立圆角叠页、暖色旧纸纹理与皮革封面；物品列表增加缩略墨线速写、类别和独立数量栏，右页速写卡片增加旧纸纹理，操作按钮改深棕色。仍复用原来的使用/丢弃用例及演示数据。1280×720 实机 OpenGL 截图在集成目录 `notebook_preview.png`；Godot 回归 273 项全通过，架构检查覆盖 98 个源文件/场景。

## 手记版面可读性修订（2026-10-03）

根据用户反馈放大了手记标题、页签、物品条目、类别、数量、描述和操作文字；左页内容从过大的内边距向外展开，同时将纸张页边线与正文重新对齐。上下内边距加大，避免标题和底部提示贴近纸边。右页物品速写卡片限定宽度、在书页内水平居中，右页正文两侧留白也更均衡。1280×720 的实际 Godot 渲染已复查；临时截图脚本未纳入工程。
