# ADR 0013：模型回答缺陷的分类、示例与一次静默重采样

日期：2026-10-04。状态：已实施（本机验证，未推送）。工作包：NPC 对话失败分类与恢复 / 负责人本任务 /
独立对抗复核待分配。依据用户实机观察：**同一套配置下，有些请求成功进入 presenting，有些失败；
Key 错误通常会持续返回 `MODEL_TRANSPORT_ERROR`，不会间歇成功**，因此问题在响应本身而不是凭据。

## 背景

DeepSeek 的 JSON Output 官方说明存在偶发返回空 content 的情况，并建议提供完整 JSON 示例与合理的
`max_tokens`。此前工程：

- 对空内容、字段数不符、动作非法、finish_reason 非 stop 一律折叠成 `MODEL_RESPONSE_INVALID`，
  日志与界面都无法区分是「空响应」「被截断」还是「字段/动作不合法」；
- 请求里没有 JSON 示例（模型只能从 schema 描述猜结构），输出上限此前也未显式设置；
- 任何一次异常都会直接把失败抛给玩家，只能手点重试。

## 决定

1. **分类稳定错误码**（`ModelTransportContract`）：新增
   `MODEL_EMPTY_CONTENT`（完成但内容为空）、`MODEL_FINISH_INCOMPLETE`（缺少可用 stop reason，通常是被
   输出上限截断）、`MODEL_REPLY_INVALID`（内容到达但不符合回复协议：字段、ID 或动作非法）。
   三者都是稳定错误码，并标为可重试。契约的 `completed_response` 负责最先分类，provider 原样透传。
2. **JSON 示例**：共享提示词追加一个完整示例，其中 `speaker_id` 用 `__SPEAKER_ID_JSON__` 占位，
   由请求构建器在每次请求时替换成当前说话人 ID 的 JSON 字符串。示例因此永远与本次请求一致，
   也不会把占位符漏给模型。
3. **输出上限**：传输层默认生成参数固定为 `{"thinking": {"type": "disabled"}, "max_tokens": 1024}`，
   `thinking` 进入允许参数白名单并只接受 enabled/disabled。短 NPC 台词 + 有限选项用 1024 足够，
   目的是避免推理占满预算或答案被截断。
4. **一次静默重采样**：网关对可恢复的答案缺陷（空内容、截断、协议不符、transport 报的响应无效）
   用新的 attempt id 自动重发一次，逻辑请求 id 不变，玩家只看到等待时间略长。第二次仍失败才把
   **分类后的**错误码交给对话层；超时、HTTP 错误、凭据问题不在重采样范围内。
5. **可诊断但不泄露内容**：网关打印 `AIRPG_AI_RECOVERY: retry <code> <detail>` 与
   `AIRPG_MODEL_REPLY_REJECTED: <code> <detail> (retry exhausted)`；`<detail>` 只含类别与我们自己的
   键名/计数（如 `fields:1`、`finish:length`、`envelope:MODEL_EMPTY_CONTENT`），**绝不含回复正文**。
   `ModelReply` 的 issues 同样被限制为键名、计数与分组名。
6. **界面据实说明**：失败状态同时显示本地化解释与稳定码（例如「模型这次返回了空内容（已知偶发）；
   可以重试。(MODEL_EMPTY_CONTENT)」），并把早先只登记在
   `game/presentation/dialogue/localization_keys.md` 的 `dialogue.*` 文本真正并入
   `data/localization/zh_CN.json`——此前对话界面在正式构建里会显示键名而不是中文。

## 兼容性

- 契约新增三个稳定码：`is_stable_error` 接受它们；对话用例把它们标为可重试；
  本地化新增对应 `dialogue.error.*`。旧消费者不受影响（未知码仍回落为 `MODEL_RESPONSE_INVALID`）。
- `completed_response` 对**空内容**与**缺少 finish_reason** 的返回值从 `MODEL_RESPONSE_INVALID`
  变为更具体的码；F1/G1 夹具以非空内容为主，G1 142 项全部保持通过。
- 网关的 attempt 机制（另一会话在本轮先行实现）被保留：一次重采样、逻辑请求 id 不变，
  分类信息叠加在其上，而不是替换它。
- `deepseek_config` 的默认参数只影响未显式配置 `parameters` 的场景；显式配置仍然生效。

## 未决与复核重点

自动重采样固定一次，没有指数退避也没有按分类区分；`thinking: disabled` 对推理型模型的影响、
1024 token 上限在「六个长选项」下的截断概率、以及重采样对成本/延迟的影响都未实测。
复核重点：分类是否会误判（例如内容含空白但语义有效的回复）、重采样是否可能重复触发副作用
（当前动作提案只在成功回复后发出，重采样期间不产生任何动作）、以及日志细节是否始终不含正文。
