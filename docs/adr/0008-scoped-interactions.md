# ADR 0008：有作用域的预设交互与原子拾取

日期：2026-10-02。状态：原型实现。工作包 C-MI1，负责人本任务，独立复核待分配。
依据 PRD §8、12、16–18；用户要求按现有架构实现最简单的开关门、物品拾取，并便于扩展交互。
基线 921556a，分支 codex/manor-interactions，独立目录 .tools/worktrees/manor-interactions。

## 统一命令入口

InteractionService 持有会话内稳定 ID → InteractionHandler 的显式注册表，启动后封闭注册。
它消费 A1 ExplorationContract 的交互意图，不修改该契约的 v1 字段。玩家只提交 target_id 和目标 revision；
服务每次执行重新向 InteractionProbe 查询准星首个命中目标、距离与遮挡，拒绝未知/超距/过期/变化的目标。
禁用、执行中的重入以及退出后的命令均拒绝。注册表不出现在 Autoload、共享目录或全局事件总线。

bootstrap 装配物理观察端口、门处理器、拾取处理器和展示，UI 只消费应用服务的深拷贝视图。
新增交互类型实现 Handler.read/execute/dispose 并在组装处注册；玩家、目标选择和 UI 不增加种类分支。
异步、锁钥、剧情条件或联合规则事务不是当前协议的隐含能力，需另行定义接受/取消/终止语义。

## 门

DoorState 是独立领域状态，只有 open 和 revision。DoorInteraction 在物理 DoorClearance 允许时切换。
导入门的铰链/门扇通过显式清单绑定；旧门扇 StaticBody 关闭并移除，新 AnimatableBody 携带视觉和碰撞同步旋转。
当前是两个离散姿态，没有动画队列；切换前对整个角度区间作 17 次加裕量的 actor 层形状查询，
玩家挡住时不提交状态也不改变门姿态。后续连续动画、NPC 或更小碰撞体须扩展此端口及物理验收。
10 扇门初始关闭；打开姿态沿用模型原姿态，未修改 GLB / Blender 源资产。

## 原子拾取与角色原型内存 v2

分别提交“背包增加”和“世界物品消失”会产生部分成功，所以世界物品可用性直接投影自领取回执。
CharacterState 的原型内存格式升为 v2，新增 pickup_receipts: Dictionary<String, bool>，值只能为 true。
CharacterService 实现 PickupInventory 端口，claim_pickup 校验来源 ID、物品、数量、堆叠上限和 revision，
将回执与背包数量在同一个候选中一次验证提交。成功后再通知展示；失败保留世界物品、数量和 revision。
普通事务不得移除已领取回执；演示重置保留回执，防止重复领取。重新进入场景创建全新会话后才恢复物品。

消费者：bootstrap/character_preview、CharacterService、档案 UI、拾取 Handler/View 与角色/交互套件。
v1 没有磁盘持久化，因此无需磁盘迁移；旧版和未知格式明确拒绝。output 独立项目保留自己的 v1，不是主工程消费者。
正式故事 StateStore、共享内容目录、磁盘存档 Schema 和 PRD 决策均不变。

## 范围与复核

交互键 F，E 保留背包。三个绿色立方体为既有演示物品，放于侧门走廊、接待室和地窖，非正式线索。
同步时发现主工作区另有 NPC 占位交谈，已保留其实现与文案；F 意图延迟到物理帧，门/物品准星命中优先，
无此类目标时沿用 NPC 交谈入口。交谈期间阻断物品/门命令，关闭对话的 F 不执行其他交互。
NPC 仍使用已有协议，本轮不重写它为新 Handler。后续可在独立消费工作包接入统一端口。
物理分层：bit1 世界/门，bit2 原 NPC，bit3 玩家，bit4 拾取；射线查询世界、NPC 与拾取但排除自身。
门净空检查 NPC 与玩家（mask6）；玩家与 NPC 互相碰撞，拾取目标不挡路。
重入、超距/遮挡、重复拾取、溢出、格式/快照隔离、门挡住和退出清理纳入新增套件。
试玩由用户负责；检定、锁门、钥匙消耗、正式掉落、剧情触发、音效、门动画、存档不在本包范围。
物理端口依据 Godot 官方 [射线查询](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html)
与 [AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html)，固定版本实际行为仍需验收。

## 2026-10-03 门碰撞与过渡修订

导入场景的旧门碰撞实际合并在 `ManorWalkCollision` 的凹多边形网格中，并非铰链子树中的独立 StaticBody。
庄园专用物理适配器以显式门叶清单和门叶本地包围盒筛除烘焙的开门三角面；每门匹配数量不在已验证范围时整批拒绝替换，避免误删墙地碰撞。游戏用 GLB 后续重新导出并排除门把手视觉与烘焙碰撞；原始 Blender 文件保留。
应用处理器在提交开关状态后阻止动画期再次提交；展示层在物理帧平滑旋转门体并通知处理器动作完成。
随门叶移动的宽射线 Area 仅用于交互命中，薄的实体门碰撞继续负责阻挡；射线与玩家/NPC 的净空查询仍由各自适配器承担。
该修订不引入新的故事、检定、存档格式或共享契约版本。后续若更换庄园模型，需重新校验门叶清单与烘焙三角面范围。
