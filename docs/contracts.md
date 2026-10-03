# 契约与版本

## 庄园预设交互 v1 / 角色原型内存 v2（2026-10-02）

ADR 0008 新增作用域内 InteractionService：register_target(id, handler) 在启用前登记，随后注册表封闭；
refresh_focus/read_focus 提供深拷贝提示，interact(target_id, expected_revision) 重新查询物理目标后执行。
Handler 的 read/execute/dispose 协议用于独立类型；不改变 A1 ExplorationContract 意图 v1。
InteractionProbe.observe 返回 Result({target_id, distance})，表示准星首个无穿墙命中；
DoorClearance.is_clear(from_open, to_open) 为切换前 actor 净空检查。UI 不提供距离/可用性作为执行授权。
禁用、退出、执行重入、错误目标、超距和过期版本均拒绝；失败不提交，成功后通知展示刷新。

PickupInventory.read_pickup(source_id) 返回 {revision, claimed}；claim_pickup(source_id, item_id, quantity, revision)
一次提交背包与来源领取回执。CharacterService 是本轮实现。原型 CharacterState 升为内存 schema_version=2，
新增 pickup_receipts 字典：稳定来源 ID → true，普通事务不可移除，演示重置保留；不成为正式存档 Schema。
消费者与无磁盘迁移说明见 ADR 0008；旧版/未知格式拒绝，原型会话重新构建即可重置。

## 庄园原型接入（2026-10-02）

ADR 0007 将独立庄园与角色原型接入主工程，未变更正式内容、故事状态或存档格式。
`Composition.build(config_path, launcher = null)` 与 `StoryArchiveComposition.build(include_placeholders, launcher = null)`
新增可选 StoryLauncher 注入；现有调用兼容，缺省仍返回 STORY_START_UNAVAILABLE。
主启动入口注入 ManorPreviewLauncher，仅接受 deadlight，同步 Result 表示庄园路由已接管；开发占位故事仍在应用层拒绝。

角色原型沿用 ADR 0006 的独立内存 v1，消费者为 CharacterService 与档案 UI，bootstrap 每次进入创建新实例。
`read_character()` 返回深拷贝；使用/丢弃/演示命令必须携带 expected_revision，失败不变状态，回血与消耗原子提交。
展示文本使用 dossier.*，避免与故事档案 archive.* 冲突；无新增 JSON 外部业务边界或存档迁移。
WalkSession 只处理移动轴；UI 开启时输入适配器停止移动与转向，返回档案时释放鼠标。此接入不代表正式可玩故事。

## 故事档案 v1（2026-09-28）

追加 ADR 0004：开发占位元数据由组装层附加 preview_only=true；
StoryArchiveService.request_start 对其返回 STORY_PREVIEW_ONLY，绝不调用启动端口。
该标记不是 JSON 可执行权限，正式目录 v1 格式未变。app 配置可选字段
story_archive_placeholders 默认为 false，发布构建忽略启用请求。

详见 ADR 0003。新增而不改动 A1 契约：

- `domain/content/story_catalog.gd`：全量校验目录 v1，返回深拷贝元数据列表。
- `StoryArchiveService.list_stories()`：深拷贝列表；`catalog_error()`：稳定目录错误码。
- `StoryArchiveService.request_start(id)`：仅允许已登记 ID，原样委托启动端口。
- `StoryLauncher.start_story(id) -> Result`：同步接受边界；失败无状态副作用，成功由
  端口实现接管后续流程。当前默认 `STORY_START_UNAVAILABLE`；不代表已有可玩故事。
- 目录错误或空目录可返回主菜单；未知美术 key 展示无图提示，不执行数据中的路径或脚本。


## 当前已实现 API

所有路径相对 `game/`。GDScript 通过显式 preload 类型协作，外部 JSON 的 Variant 只在边界校验器中处理。

| 契约 | 输入 / 输出 | 不变量 |
| --- | --- | --- |
| `shared/result.gd` | `success(value)` / `failure(code, issues)` | ok 为 false 时调用者不得使用 value；code 为稳定技术标识 |
| `ContentValidator.validate` | pack Variant + 受信 Schema → Result | 全部验证后返回深拷贝；不执行条件或推进状态 |
| `Conditions.matches` | 条件数组 + flags → bool | 全部条件与关系；未知格式/flag 返回 false |
| `StateStore.configure` | Dictionary<String, bool> → Result | 仅可初始化一次；失败不修改状态 |
| `StateStore.snapshot` | → `{revision: int, flags: Dictionary}` | 深拷贝 |
| `StateStore.commit` | 预期版本 + 非空布尔更新 → Result(snapshot) | 仅预声明键；全验证、全提交；版本不匹配拒绝 |
| `SessionService` | `read_state()` / `diagnostics()` | UI 只读入口，尚无剧情用例命令 |
| `ModelProvider.start` | request_id + 已隔离上下文 → Result | 同步失败不会发终止信号；接受后才开始异步信号协议 |
| `ModelProvider` 信号 | raw_delta(id, chunk)、completed(id, Dictionary)、failed(id, code) | 每个已接受请求恰有一个终止信号；raw_delta 不等于已验证台词 |
| `ModelProvider.cancel` | request_id | 后续适配器须实现幂等取消；已完成请求无操作，正在执行者发 failed(id, REQUEST_CANCELLED) 一次 |
| `SaveRepository` | write_snapshot(slot, Dictionary) / read_snapshot(slot) | 本次只有接口与内存测试适配器，无生产保存功能 |
| `RandomSource` | roll(sides)、capture()、restore(checkpoint) | 独立会话源；非法参数/检查点不推进 RNG |
| `SceneRouter` | configure(host, routes)、navigate(id) → Result(Node) | 节点移除后延迟释放；无效路由保留旧视图 |
| `ExplorationContract` | move(axis)、interact(target_id)、investigate()、candidate(...) | 只表达玩家意图和互动候选；不计算检定、不修改剧情状态 |
| `DialogueViewContract` | status(...)、verified_reply(...)、player_text(...)、option_selection(...) | 玩家输入原样保留；只有 `verified_reply` 可作为模型台词进入 UI |
| `ModelTransportContract` | request(id, filtered_context)、is_stable_error(code) | 上下文深拷贝；供应商错误不得越过稳定错误码边界 |
| `ChatCompletionRequestBuilder` | 已隔离上下文 → system/user messages（可选按说话人注入人格） | 事实 key 必须解析为审核正文；人格模板占位符必须在构造期全部有值；权威与 untrusted 分区；请求 JSON 深拷贝 |
| `ChatCompletionGateway` | filtered context → `ModelReply` | 缓存完整 content 后解析；非 stop、无效 JSON 与未知字段失败；不转发 raw delta |
| `ReplyValidator.validate` | reply / speaker / 允许与已知事实 / 动作目录 / 可选角色输出策略 | 结构、说话人、事实与动作先判；角色策略最后判；策略拒绝一律按可重试失败处理 |
| `DialogueConfiguration` | 必需 session/state/provider/context/facts/action_catalog/speakers；可选 action_sink、reply_policies | speakers 仍只有 name_key 与 portrait_id；reply_policies 是按说话人索引的受校验策略信封 |
| `WorldBook.facts_for` | 分层世界书条目 + 本场景说话人列表 → F1 fact 记录 | 只投影有本场受众的条目；hidden/running 层不得携带 NPC 受众；每条条目只产出一条 fact |
| `NpcActionContract` | proposal(session/request/revision/speaker/scene/action) | 只接受精确字段；禁止坐标；动作先经场景 sink 接受才发布回复 |
| `ModelConfiguration` | configure(endpoint, model, key) / clear / diagnostics | HTTPS 与非空值校验；诊断不含 Key；本次运行内存配置，不做持久化 |

Result 的公开属性是值协议，不是强不可变类型。领域状态和内容边界自行深拷贝；不能凭借 Result 自动获得隔离。
当前基类端口返回 NOT_IMPLEMENTED；模型默认适配器返回 AI_NOT_CONFIGURED。不得忽略 ok 并继续当成功使用。
请求和响应业务 DTO 已由 F1 与集成工作包冻结为 v1；它只覆盖工程预览的知识投影、回复校验和语义动作提案，
不代表自然语言语义已被证明安全，也不代表正式剧情、检定或状态提交已经实现。
2026-10-03 起，庄园场景的说话人由 `data/ai/npc_characters.zh_CN.json` 的角色卡绑定（艾米利亚与玛丽），
知识来自 `data/ai/deadlight_worldbook.zh_CN.json` 的分层世界书；两者都先过各自的 JSON Schema，再过领域校验器。
角色卡的输出策略只覆盖可可靠判定的部分（元层暴露、角色禁用句、气泡长度），信任增减、逆鳞状态变更与
失谐波纹 UI 仍未实现。世界书的 hidden/running 层只留给未来的 AI 主持人，不进入任何 NPC 上下文。

## A1 并行接缝

### 探索命令 v1

`application/contracts/exploration_contract.gd` 是 C1 的稳定入口。移动使用长度不超过 1 的 `Vector2` 轴，
互动目标与提示键使用稳定 ID，探查命令不携带概率或结果。C1 可以消费这些命令，但不得据此直接修改
`StateStore`。探查发现内容、骰点与剧情效果留给后续规则/故事用例。

### 对话展示 v1

`application/contracts/dialogue_view_contract.gd` 区分状态事件、已验证回复、玩家原文和选项选择。
第一阶段发布顺序固定为“完整缓存 → 完整校验 → UI 渐进播放”。`ModelProvider.raw_delta` 仅供传输和诊断，
不得包装成 `verified_reply` 或直接连接玩家 UI。推荐选项当前携带稳定 ID 与显示文本；正式内容接入后显示文本
应由已验证的对话用例提供，固定界面文本仍从本地化资源读取。

### 模型传输 v1

`application/contracts/model_transport_contract.gd` 冻结供应商无关请求信封和以下稳定失败代码：

- `AI_NOT_CONFIGURED`
- `MODEL_TIMEOUT`
- `MODEL_TRANSPORT_ERROR`
- `MODEL_RESPONSE_INVALID`
- `KNOWLEDGE_SCOPE_VIOLATION`
- `REQUEST_CANCELLED`
- `REQUEST_STALE`

每个被接受的请求必须恰有一个终止信号；取消幂等；重试使用新的 request ID。G1 只负责传输，不能选择 NPC
知识、认可事实、结算规则或提交状态。当前完整响应 DTO 与动作提案见下节；正式事实内容格式仍需 B/F 会审。

### NPC 对话与语义动作 v1

`DialogueUseCase` 的模型输入必须是经知识目录投影的 `filtered_context`；玩家文字、笔记、传闻、其他角色陈述
保持在 `untrusted` 分区。`ChatCompletionGateway` 只在完整响应通过 `ModelReply` 结构解析后发出 completed，
F1 再检查 speaker、used_fact_ids 和 `AllowedActions`。当前每个回复最多一个动作。

动作目录只描述 command ID 与参数 Schema。生产接线允许 `npc.stay`、`npc.face_player` 和
`npc.move_to_anchor({anchor_id})`；`NpcActionContract` 不允许任意位置字段。场景 sink 必须验证 session、scene、
speaker、revision 与 NPC 专属锚点，再调用场景角色控制。动作拒绝视为整个回复失败，不能只显示台词而忽略动作。

版本化 prompt 是受校验的数据资源，不是正式故事内容。当前庄园上下文、NPC 名称和锚点均明确标注为合成预览。

### 测试替身

`tests/doubles` 提供探索、对话和可编程模型替身。它们只服务于测试与并行开发，不是生产功能。
可编程模型替身的 `force_*` 方法允许故意发出违规序列，用于取消、迟到、重复终止和原始流泄漏测试。
功能分支在自己的测试目录新增套件；`tests/run_tests.gd` 只由集成负责人登记套件。

## JSON Schema 子集

运行时支持：`type`、`required`、`properties`、`additionalProperties`（布尔或 Schema）、`items`、`enum`、`const`、`minLength`、`pattern`、`minimum`、`maximum`、`maxItems`、`maxProperties`。
`$schema`、`title`、`description` 仅元数据。最多递归 32 层。Schema 文件由代码评审管理，不能由模型或外部第三方提供。
JSON 数字的整数校验接受有限、无小数的浮点解析结果，拒绝布尔值冒充整数。
该校验器不是完整 JSON Schema 2020-12 实现；使用新关键字必须先增加验证器和测试，或换成明确锁定版本的完整实现。

## 内容目录 v1

`data/schemas/content_pack.schema.json` 是机器契约。根对象必须包含：

- `schema_version`：当前 1。
- `pack_id`：稳定命名空间 ID；`content_version`：作者定义的内容修订号。
- `locale`：当前仅 zh_CN。
- `flags`：预声明布尔标记与初始值。
- `localization`：供定义引用的文本表。
- `definitions`：带 id、kind、text_key、references、conditions 的元数据目录。

kind 覆盖角色、场景、节点、线索、话题、规则和事实。它目前只表示目录类型，不意味着已经实现该种业务定义。
所有 ID 在单个包中唯一，引用限于当前包。多包组合、按种类强类型引用、角色权限等需要后续契约，不能假定当前已支持。
条件只支持 `{flag, equals}` 的布尔合取。后续数值技能条件要新增明确操作类型，禁止自由表达式。
界面固定文本位于 `data/localization/zh_CN.json`；内容文本目录与界面文本分开维护，当前内容包为空。

## 后续契约的评审顺序

1. 内容团队先确认被授权的内容输入；数据/架构岗位确定专用定义和 ID。
2. 规则岗位依据已确认公式定义 check 请求/结果与 RNG 事务检查点。
3. 对话/AI 岗位一起定义上下文 DTO、请求生命周期、响应 DTO、验证片段、取消/重试语义。
4. 状态与存档岗位定义完整会话快照、保存资格、版本迁移、内容版本绑定。
5. 消费者使用独立假实现并行开发；真实适配器通过同一契约测试后接入。

所有契约变更都应列出消费者、兼容方式、测试夹具和迁移策略。没有实现的端口不能作为“功能已完成”的证据。
