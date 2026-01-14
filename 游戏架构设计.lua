--[[
游戏架构设计文档
版本: V1.9
最后更新: 2026-01-12
]]
游戏架构设计 V1.9

1. 设计原则
- 服务端权威：货币、随机、产出、升级、存档都在服务端
- 玩家隔离：基地、传送带、蛋、宠物、数据都绑定OwnerUserId，仅处理玩家自身数据
- 客户端只做表现与交互，所有请求都要服务端校验
- 配置驱动：蛋/卡池/宠物/升级/离线上限全部配置化
- 轻量通信：事件+数据增量，不频繁全量同步
- 性能优先：限制实例数量，及时清理，避免无效 Tick
- 时间统一：孵化/产币/离线结算全部使用服务端时间戳
- 数据一致：在线收取与离线结算共用时间戳/累积字段，结算即更新避免双算
- 存档节流：会话缓存 + Dirty 标记 + 间隔保存 + 退出/关服兜底

2. 目录与模块（建议）
说明：本地文件平铺在 D:\RobloxGame\Labubu，脚本头部“脚本位置”指 Roblox Studio 内路径

ReplicatedStorage/
- Config/GameConfig, EggConfig, CardPoolConfig, PetConfig, UpgradeConfig, EconomyConfig
- Config/CapsuleConfig（盲盒配置）
- Config/CapsuleSpawnPoolConfig（盲盒刷新池）
- Config/FigurineConfig（手办配置）
- Config/FigurinePoolConfig（手办卡池配置）
- Modules/FormatHelper（数值格式化）
- Events/LabubuEvents（具体见 RemoteEvent列表.lua）
- Capsule（盲盒模型资源）
- LBB（手办模型资源）
- Util/RNG, Time, TableUtil, IdUtil

ServerScriptService/
- Server/Bootstrap: 玩家进入/离开流程串联
- Server/DataService: 会话缓存、节流存档、离线收益、统一数据更新
- Server/GMCommands: GM命令管理（金币增减/清零/命令列表）
- Server/HomeService: 生成基地、绑定Owner、缓存关键引用
- Server/ConveyorService: 按刷新池权重产蛋与生命周期管理
- Server/EggService: 盲盒购买/背包/放置/倒计时
- Server/FigurineService: 盲盒开盒随机手办/展台摆放/待领取产币与领取触发
- Server/PetService: 图鉴状态、产币、升级与品阶更新
- Server/NetService: 统一RemoteEvent校验与分发

StarterPlayer/StarterPlayerScripts/
- Client/UIController: 货币、背包、孵化、图鉴UI刷新
- UI/CoinDisplay: 金币数值显示(MainGui/CoinNum)
- UI/TestInfoDisplay: 统计测试UI显示
- Client/CameraFocus: 新手办升台镜头聚焦
- Client/InteractionController: 点击交互、放置操作、开蛋请求
- Client/HomeController: 本地展示与提示
- Client/NetClient: 与服务端通信与数据接收

ServerStorage/
- HomeTemplate（基地模板）
- EggModels / PetModels（模型资源）

Workspace/
- Home（固定家园槽位，V1.1）

家园预置结构（V1.1）
- Workspace/Home/Player01~Player08 作为固定家园槽位
- 每个家园内包含 SpawnLocation 作为玩家出生点
- 每个家园内包含 ConveyorBelt/Start 与 ConveyorBelt/End

3. 关键数据结构（服务端持久化）
PlayerData
- Coins: number
- TotalPlayTime: number
- CapsuleOpenTotal: number
- CapsuleOpenById: { [CapsuleId] = number }
- OutputSpeed: number
- Eggs: { {Uid, EggId} }  -- 背包内的蛋
- PlacedEggs: { {Uid, EggId, HatchEndTime, Position, Rotation, IsLocal} } -- Position/Rotation为相对IdleFloor的本地坐标
- Figurines: { [FigurineId] = true }
- FigurineStates: { [FigurineId] = {LastCollectTime} }
- Pets: { [PetId] = {Unlocked, Level, Rank, Count, LastCollectTime, PendingCoins} }
- LastLogoutTime: unix

说明
- PendingCoins 为未收取累计，LastCollectTime 用于结算增量，在线/离线共用避免双算
- V1.7 启用 Coins + Figurines + FigurineStates + 统计字段，其它字段预留给后续阶段

运行时缓存（不持久化）
- DataVersion: number  -- 每次数据变更自增，用于增量同步
- HomeCache: { [UserId] = HomeInstance }
- EggUidIndex: { [EggUid] = {Instance, OwnerUserId} }
- PlacedEggUidIndex: { [PlacedEggUid] = {Instance, OwnerUserId} }
- SaveDirty, LastSaveTime

运行时实例属性（用于校验与同步）
- ConveyorEgg: EggId, Price, OwnerUserId, Uid, SpawnTime
- PetBoard: PetId, OwnerUserId

4. 核心系统职责
- DataService：会话缓存 + Dirty 标记 + 间隔保存 + BindToClose 兜底，UpdateAsync 持久化，离线结算，统计(在线时长/盲盒开启/总产出速度)
- GMCommands：GM命令处理（加金币/清金币/命令列表）
- HomeService：玩家进入创建基地，设置OwnerUserId并缓存节点，维护地板范围/格位信息，更新基地PlayerInfo展示，出生朝向对准ClaimAll
- ConveyorService：按配置间隔产蛋，服务端生成 EggUid，维护索引/最大蛋数/过期清理
- EggService：盲盒购买校验、背包管理、放置、倒计时与开盒触发
- FigurineService：开盒随机手办、展台放置、金币待领取/触碰领取、展台信息UI
- PetService：图鉴解锁、PendingCoins 累积、产币结算、升级条件与品阶更新
- NetService：所有RemoteEvent统一入口，频率限制/归属/距离/状态/版本校验与重同步

5. 核心流程
- 玩家进入：随机分配空闲 Home 槽位 -> 绑定 SpawnLocation -> 读取数据(默认 Coins=GameConfig.StartCoins)
- V1.3 流程：传送带按刷新池权重生成盲盒 -> 玩家交互购买 -> 盲盒进背包 -> 放置地面 -> 倒计时结束
- 传送带产蛋：每个Home独立计时 -> 按刷新池权重生成蛋模型 -> 建立 EggUid 索引 -> 移动至末端 -> 自动销毁/过期清理
- 购买蛋：客户端点击 -> 服务端校验(归属/距离/金币/冷却) -> 扣费 -> 入背包 -> 移除蛋
- 放置蛋：客户端请求 -> 校验位置(在自家地板内/格位) -> 占用检测 -> 生成模型 -> 设置HatchEndTime
- 开蛋：校验孵化完成 -> 按卡池权重随机手办 -> 摆放展台 -> 开始产币
- 产币与收取：服务端按 LastCollectTime 结算，触碰领取按钮收取并清零累计
- 升级：获得同ID宠物累计Count达到阈值自动升级
- 离线收益：依据离线时长与上限秒数结算，登录时写入 PendingCoins
- 版本不同步：客户端检测版本缺口 -> RequestResync -> 服务端下发全量快照

6. 产币计算与限制（可调）
- rate = baseRate * (1 + (Level - 1) * QualityCoeff) * RankCoeff
- OfflineCapSeconds 由配置控制，超出部分不计
- FigurineCoinCapSeconds 控制单个手办未领取累计上限时长
- 在线收取：按 now - LastCollectTime 结算，不受离线封顶
- 离线结算：按 min(离线时长, OfflineCapSeconds) 结算并写入 PendingCoins

7. 客户端表现
- 所有交互仅发送请求，不自行修改核心数据
- UI使用服务端数据驱动，动画/特效纯客户端
- 币数展示可基于 ServerTime + PendingCoins 推算，仅作表现
- CoinNum 从玩家属性 Coins 同步显示，格式遵循 FormatHelper 大数值规则

8. 性能与安全
- 传送带最大蛋数限制，避免堆积
- 所有随机与价格计算只在服务端
- RemoteEvent 做频率、归属、距离、状态、版本校验
- 数据同步尽量走增量，避免高频全量
- UpdateAsync 节流，保存合批，避免触发预算上限

9. 数据同步与版本控制
- 每个玩家维护 DataVersion 自增，DataDelta 携带 BaseVersion/NewVersion
- 客户端版本不一致时走 RequestResync，服务端下发全量快照
- 全量快照包含 ServerTime 与关键数据字段

10. 扩展点
- 新蛋/卡池/宠物仅改配置，不改核心逻辑
- HomeTemplate可扩展装饰/交互点
- PetService支持新增收益规则或被动技能

