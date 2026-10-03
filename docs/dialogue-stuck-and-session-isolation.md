# NPC 对话的卡住与“共用一个对话”问题（2026-10-04）

用户反馈：对话经常卡住；两个 NPC 像在用同一个对话；并要求查看游戏日志。
工作包：对话可退出性与每角色会话隔离 / 负责人本任务 / 独立对抗复核待分配。

## 日志说明了什么

本机实际游戏日志在 `%APPDATA%\Godot\app_userdata\AIRPG\logs\`（`godot.log` 与按启动时间的分卷）。
本次排查时最近的 4 次启动只有：

```
AIRPG_BOOT_READY
AIRPG_STRUCTURE_WALK_READY
```

**没有任何 AI 状态、对话状态或错误记录**——因为在此之前，NPC 对话路径一条日志都不写：

- `manor_play.configure_ai` 失败只写内部字段 `ai_error`，不打印；
- 请求、失败、状态迁移只在内存里，不落日志。

因此“卡住”无法从旧日志复盘。本轮补了三条不含敏感信息的标记（见下）。

另一个关键事实：**API Key 只存在于当前进程内存**（`runtime_model_configuration.gd`，按设计不写盘）。
每次重新启动游戏都要在“设置”里重新填写；没配置时 `create_transport` 返回 `AI_NOT_CONFIGURED`，
`configure_ai` 失败，按 F 得到的是**固定问候框**（一句话 + 关闭按钮，没有自由输入），不是 AI 对话。
这本身就容易被感受为“对话卡住/不像对话”。

## 卡住的三个真实原因与修复

1. **对话界面在多数状态下没有可见出口。** `dialogue_chrome.render` 原来只在
   `FAILED / PAUSED / CANCELLED` 显示“返回”按钮；在 `IDLE / WAITING / PRESENTING` 只显示状态文字。
   请求最长要等 60 秒（`request_timeout_seconds`）或 30 秒（`idle_timeout_seconds`），
   等待期间输入被锁、鼠标已释放、移动被阻断，屏幕上却没有可点的退出按钮——只有 F/Esc 能用。
   现在“返回”按钮在所有状态可见（`dialogue_chrome.gd`）。
2. **输入框获得焦点后 F 不再关闭对话。** 这是刻意行为（handoff 记录过“聚焦时 F/E 不误触快捷键”），
   因此保留；修好第 1 条后，鼠标点“返回”成为始终可用的出口。
3. **降级路径不吭声。** 没配置 Key、内容校验失败或 `begin_exchange` 被拒时，玩家只会看到一个静态问候框，
   无法判断原因。现在启动与对话路径会写标记（见下）。

## “共用一个对话”的成因与修复

代码层面确实是**一套会话**：`manor_npc_ai` 只建一个 `DialogueUseCase` 与一个 `dialogue_view`，
`configure()`（内部 `_reset_session`）只在进入庄园时调用一次；`begin_exchange` 虽会切换说话人，
但**表现层没有跟着换**：

- 上一位 NPC 的台词、推荐选项、名牌会留在对话框里，直到新回复到达才被覆盖；
- 历史面板是本会话的整份记录，两位 NPC 的行混在一份流水里，没有任何“换人”标记；
- 模型侧更彻底：`recent_dialogue` 恒为空，所以两边都记不住任何东西（PRD §10.4 未实现）。

修复：

- 新增 `DialogueView.begin_conversation(name_key, portrait_id)`：清空上一位的台词、选项、错误与等待状态，
  立即写上当前 NPC 的名牌与立绘，并在历史面板插入本地化的分隔行（`dialogue.history.divider`）。
  `ManorNpcAi.begin` 在每次开始对话时调用它，所以**换人就有可见的会话边界**。
- 新增 `application/dialogue/dialogue_memory.gd`：**按 NPC 归属**的近期记忆（PRD §10.4 的“近期记忆”子集，
  默认保留最近 6 行，超长截断，重试不重复记录）。`DialogueUseCase` 在组装上下文时只注入当前说话人的记忆，
  因此艾米利亚的对话不会进入玛丽的上下文，玩家的原话仍走 `untrusted`。
  记忆随会话存在（离开庄园即释放），不写存档、不改变状态格式。
- 仍需保留的“共用”：一个会话只能有一个主要对话对象（PRD §9.5），历史面板仍是会话级总记录（现在有分隔行）。

## 新增日志标记（不含任何密钥、提示词或模型原文）

| 标记 | 出现位置 | 含义 |
| --- | --- | --- |
| `AIRPG_NPC_AI: ready` / `AIRPG_NPC_AI: <code>` | 进入庄园装配 AI 时 | 对话走模型，或降级及其原因（如 `AI_NOT_CONFIGURED`） |
| `AIRPG_NPC_DIALOGUE_OPEN: <speaker> @ <topic>` | 开始一次对话 | 说话人与房间话题（决定记忆碎片） |
| `AIRPG_NPC_DIALOGUE_REJECTED: <speaker> <code>` | 开始对话被拒 | 例如上下文未打开、说话人未注册 |
| `AIRPG_NPC_DIALOGUE_CLOSE: <speaker>` | 关闭对话 | 会话结束 |
| `AIRPG_DIALOGUE_STATE: <state> <error_code>` | 对话视图状态变化 | 卡在 `waiting`、还是 `failed MODEL_TIMEOUT` 等一眼可见 |

下一次卡住时，`godot.log` 里应能看到“最后停在哪个状态、错误码是什么”。

## 验证

`AIRPG_TESTS: 1060 checks, 0 failures`。新增覆盖：

- I1：`idle` 与 `waiting` 状态下“返回”按钮可见；`begin_conversation` 清空上一位的台词与选项、
  立即写上新的说话人名牌、历史里出现会话分隔（不再把两位的行读成一次对话）。
- NPC_AI：艾米利亚的回复与玩家原话会作为她自己的近期记忆回到她的下一次请求；
  玛丽的下一次请求**不含**艾米利亚的任何一行。

## 仍未实现 / 复核重点

关键记忆（结构化事件）、关系摘要、跨场景记忆、完整历史导出、对话中途存档仍未实现；
`recent_dialogue` 只覆盖最近 6 行。复核重点：换人时挂起请求的取消是否彻底、
分隔行在长会话中的可读性、以及 60 秒等待期间玩家的可取消体验。
