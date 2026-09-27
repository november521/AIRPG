# AIRPG

把 AI 接入一个简单的跑团 RPG：规则引擎管世界，大模型管一部分角色（NPC/GM）的行为。
Windows 单人项目，当前完成阶段 A 的架构基础，尚不是可玩的《死光》切片。
产品范围以 [PRD](AIRPG_PRD_v0.1.md) 为准。

## 启动与验证

需要 Godot **4.7.2 Stable**（官方构建 `ed1daf0bf`）、PowerShell 7 和 Git。
Godot 工程位于 **`game/project.godot`**，不是仓库根目录。

```powershell
# 使用当前工作区已有的引擎
./scripts/verify.ps1

# 或使用自备的精确版本引擎
./scripts/verify.ps1 -Godot 'D:/Tools/Godot_v4.7.2-stable_win64_console.exe'

# 全新开发机 / CI：安装经 SHA-256 锁定的 Windows 引擎
$engine = ./scripts/install_engine.ps1
./scripts/verify.ps1 -Godot $engine

# 打开编辑器；也可以从 Godot 项目管理器导入 game/project.godot
& './.tools/godot/Godot_v4.7.2-stable_win64.exe' --editor --path game
```

运行后显示工程就绪页；按钮切换到场景容器；开发构建可按 F3 查看诊断。
WASD / E / Q 的动作绑定已加载，角色移动和交互功能尚未实现。
无 API 密钥也能启动和运行全部测试；不会发送模型请求。

质量入口依次检查依赖方向/循环、引擎导入、行为测试、真实启动。
日志在 `artifacts/`，不进入版本库。`.gd.uid` 是源文件的一部分，需要提交。

## 从哪里开始读

| 文件 | 用途 |
| --- | --- |
| [架构](docs/architecture.md) | 模块边界、依赖、状态与 AI 约束、演进原则 |
| [协作分工](docs/workstreams.md) | 岗位、目录所有权、可并行工作包与验收 |
| [接口契约](docs/contracts.md) | 当前真实 API、数据格式与未来接入约束 |
| [决策记录](docs/adr/0001-foundation.md) | 选型理由、代价与复审条件 |
| [测试说明](docs/testing.md) | 验证入口、覆盖范围、对抗风险 |
| [接续记录](docs/handoff.md) | 完成情况、待办、下一步与恢复方式 |
| [协作规则](AGENTS.md) | 人与 Agent 共同遵守的工程约定 |

## 当前边界

已实现启动装配、内容目录基础校验、本地化、输入注册、场景路由、诊断视图、布尔状态原子提交、随机源与可替换端口。
尚未实现正式剧情、人物、移动、检定公式、模型网络接入/语义校验、磁盘存档、完整日志系统与发布导出。
`bootstrap.json` 是空内容包；测试数据不是授权剧情。内容格式 v1 仅为目录与引用信封，业务字段应随下一工作包通过契约评审逐步加入。

已有 `scripts/setup_local_mcp.ps1` 是本机工具配置脚本，由原工作区保留，不是构建或 CI 的前置条件。
工具安装目录 `.tools/` 位于 Godot 工程之外，避免工具代码或依赖进入游戏资源扫描与未来导出包。
