--[[
游戏架构设计文档
版本: V4.2
最后更新: 2026-01-21
]]
游戏架构设计 V4.2

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
- Config/FigurineConfig（手办配置，ModelResource支持路径）
- Config/FigurinePoolConfig（手办卡池配置）
- Config/FigurineRateConfig（手办产速系数）
- Config/QualityConfig（品质图标配置）
- Config/ProgressionConfig（养成/成就配置）
- OpenProgresTemplate（盲盒开启进度UI模板）
- CapsuleInfo（盲盒信息BillboardGui模板）
- Modules/FormatHelper（数值格式化）
- Modules/AudioManager（音频管理）
- Modules/ButtonPressEffect（按钮按下缩放效果）
- Modules/BackpackVisibility（背包隐藏计数与显示状态）
- Modules/GuiResolver（UI路径容错查找）
- Events/LabubuEvents（具体见 RemoteEvent列表.lua）
- Capsule（盲盒模型资源）
- LBB（手办模型资源）
- Util/RNG, Time, TableUtil, IdUtil

ServerScriptService/
- Server/Bootstrap: 玩家进入/离开流程串联
- Server/DataService: 会话缓存、节流存档、离线收益、统一数据更新
- Server/GMCommands: GM命令管理（金币增减/清零/命令列表）
- Server/HomeService: 生成基地、绑定Owner、缓存关键引用
- Server/ConveyorService: 按OutputSpeed解锁刷新池，抽品质并做稀有度突变，产蛋与生命周期管理
- Server/EggService: 盲盒购买/背包/放置/倒计时
- Server/FigurineService: 盲盒开盒随机手办/展台摆放/待领取产币与领取触发
- Server/ClaimService: 领取全部/十倍领取/自动领取/付费买币
- Server/ProgressionService: 养成/成就进度计算、钻石奖励领取、养成加成生效与同步
- Server/LeaderboardService: 服务器内排行榜（总产速/总游戏时间）
- Server/FriendBonusService: 同服好友加成统计与属性同步
- Server/GlobalLeaderboardService: 全局排行榜数据维护与刷新推送
- Server/PetService: 图鉴状态、产币、升级与品阶更新
- Server/NetService: 统一RemoteEvent校验与分发

StarterPlayer/StarterPlayerScripts/
- Client/UIController: 货币、背包、孵化、图鉴UI刷新
- UI/CoinDisplay: 金币数值显示(MainGui/CoinNum)
- UI/CoinAddDisplay: CoinAdd按钮显示/数值刷新/购买请求
- UI/DoubleForeverDisplay: DoubleForever倍率显示/购买请求
- UI/BackpackDisplay: 自定义背包UI显示与装备交互
- UI/BagDisplay: 盲盒背包总览界面显示与筛选
- UI/IndexDisplay: 手办索引界面显示与筛选/检视入口
- UI/ProgressionDisplay: 养成成就界面显示/领奖动画/红点提示
- UI/TestInfoDisplay: 统计测试UI显示
- UI/ErrorHint: 统一错误提示显示
- UI/GachaResult: 抽卡结果表现与升级进度动画
- UI/HomeButton: 主界面Home按钮回基地请求
- UI/ButtonPressEffect: 全局按钮按下缩放效果绑定
- UI/GuiBootstrap: 兜底补齐PlayerGui中的UI
- UI/InviteButton: 邀请好友按钮弹出系统邀请界面
- UI/FriendBonusDisplay: 好友加成文本显示
- UI/OptionsDisplay: 设置界面(BGM/音效开关)与音效播放监听
- UI/GlobalLeaderboardDisplay: 全局排行榜界面展示与刷新倒计时
- UI/AssetPreload: 进入游戏前预加载所有图片资源
- Client/CameraFocus: 新手办升台镜头聚焦
- Client/InteractionController: 点击交互、放置操作、开蛋请求
- Client/HomeController: 本地展示与提示
- Client/NetClient: 与服务端通信与数据接收

StarterGui/
- BackpackGui（自定义背包界面）
- Bag（盲盒背包总览界面）
- Index（手办索引界面）
- Check（手办检视界面）
- GachaResult（抽卡结果界面）

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
- Diamonds: number
- TotalPlayTime: number
- CapsuleOpenTotal: number
- CapsuleOpenById: { [CapsuleId] = number }
- OutputSpeed: number
- OutputMultiplier: number
- AutoCollect: boolean
- MusicEnabled: boolean
- SfxEnabled: boolean
- ProgressionClaimed: { [AchievementId] = true }
- Eggs: { {Uid, EggId} }  -- 背包内的蛋
- PlacedEggs: { {Uid, EggId, HatchEndTime, Position, Rotation, IsLocal} } -- Position/Rotation为相对IdleFloor的本地坐标
- Figurines: { [FigurineId] = true }
- FigurineStates: { [FigurineId] = {LastCollectTime, Level, Exp, Rarity} }
- Pets: { [PetId] = {Unlocked, Level, Rank, Count, LastCollectTime, PendingCoins} }
- LastLogoutTime: unix

说明
- PendingCoins 为未收取累计，LastCollectTime 用于结算增量，在线/离线共用避免双算
- V2.0 启用 FigurineStates.Level/Exp 升级字段，其它字段预留给后续阶段

运行时缓存（不持久化）
- DataVersion: number  -- 每次数据变更自增，用于增量同步
- HomeCache: { [UserId] = HomeInstance }
- EggUidIndex: { [EggUid] = {Instance, OwnerUserId} }
- PlacedEggUidIndex: { [PlacedEggUid] = {Instance, OwnerUserId} }
- SaveDirty, LastSaveTime

运行时实例属性（用于校验与同步）
- ConveyorEgg: EggId, Price, OwnerUserId, Uid, SpawnTime
- PetBoard: PetId, OwnerUserId
- FigurineOwned: Folder<BoolValue> 客户端索引界面读取玩家手办拥有状态
- FriendBonusCount: number
- FriendBonusPercent: number
- OutputMultiplier: number
- Diamonds: number

4. 核心系统职责
- DataService：会话缓存 + Dirty 标记 + 间隔保存 + BindToClose 兜底，UpdateAsync 持久化，离线结算，统计(在线时长/盲盒开启/总产出速度)，手办升级数据管理
- GMCommands：GM命令处理（加金币/清金币/命令列表）
- HomeService：玩家进入创建基地，设置OwnerUserId并缓存节点，维护地板范围/格位信息，更新基地PlayerInfo展示，出生朝向对准ClaimAll
- ConveyorService：按OutputSpeed选择最高解锁刷新池，抽品质与稀有度突变，按配置间隔产蛋，服务端生成 EggUid，维护索引/最大蛋数/过期清理
- EggService：盲盒购买校验、背包管理、放置、倒计时、付费开盒与开盒触发
- FigurineService：开盒随机手办、展台放置、金币待领取/触碰领取、展台信息UI，升级展示
- ClaimService：领取全部/十倍领取/自动领取通行证/付费买币/产速倍率购买、UI状态切换与自动结算
- FriendBonusService：同服好友数量统计与加成属性同步，变更时调整产币结算基准
- GlobalLeaderboardService：全局排行榜数据维护，按分钟刷新并推送榜单
- PetService：图鉴解锁、PendingCoins 累积、产币结算、升级条件与品阶更新
- NetService：所有RemoteEvent统一入口，频率限制/归属/距离/状态/版本校验与重同步

5. 核心流程
- 玩家进入：随机分配空闲 Home 槽位 -> 绑定 SpawnLocation -> 读取数据(默认 Coins=GameConfig.StartCoins)
- V1.3 流程：传送带按刷新池权重生成盲盒 -> 玩家交互购买 -> 盲盒进背包 -> 放置地面 -> 倒计时结束
- 传送带产蛋：每个Home独立计时 -> 按OutputSpeed解锁刷新池 -> 权重抽基础品质 -> 稀有度突变确定稀有度 -> 用品质+稀有度映射 CapsuleId -> 建立 EggUid 索引 -> 移动至末端 -> 自动销毁/过期清理
- 购买蛋：客户端点击 -> 服务端校验(归属/距离/金币/冷却) -> 扣费 -> 入背包 -> 移除蛋
- 放置蛋：客户端请求 -> 校验位置(在自家地板内/格位) -> 数量上限(MaxPlacedCapsules) -> 占用检测 -> 生成模型 -> 设置HatchEndTime
- 付费开盲盒：倒计时阶段触发开发者商品购买，完成后直接开盒；若倒计时已结束则改走普通开盒交互
- 开蛋：校验孵化完成 -> 按卡池权重随机手办 -> 下发OpenEggResult -> 客户端抽卡表现 -> NotifyGachaFinished -> 新卡升台与镜头聚焦 -> 开始产币
- Home按钮：客户端请求GoHome -> 服务端校验归属 -> 传送回基地出生点
- 产币与收取：服务端按 LastCollectTime 结算，触碰领取按钮收取并清零累计
- 领取全部/十倍领取：触碰触发开发者道具购买 -> 统一结算未领取金币 -> 更新各手办 LastCollectTime
- 自动领取通行证：购买后 AutoCollect=true，隐藏ClaimAll/ClaimAllTen，按间隔自动结算
- 付费买币：CoinAdd按钮请求购买 -> 回执按购买时OutputSpeed * Seconds发放金币
- 产速倍率购买：DoubleForever按钮请求购买 -> 回执更新OutputMultiplier并刷新产速
- 升级：获得同ID手办累积经验达到 UpgradeConfig 阈值自动升级，达到最高级停止
- 离线收益：依据离线时长与上限秒数结算，登录时写入 PendingCoins
- 版本不同步：客户端检测版本缺口 -> RequestResync -> 服务端下发全量快照

6. 产币计算与限制（可调）
 - rate = baseRate * RarityCoeff * (1 + (Level - 1) * QualityCoeff) * (1 + ProgressionBonus) * OutputMultiplier * (1 + 0.1 * FriendCount)
 - OfflineCapSeconds = GameConfig.OfflineCapSeconds + 养成离线上限加成分钟*60
- FigurineCoinCapSeconds 控制单个手办未领取累计上限时长
- 在线收取：按 now - LastCollectTime 结算，不受离线封顶
- 离线结算：按 min(离线时长, OfflineCapSeconds) 结算并写入 PendingCoins

7. 客户端表现
- 所有交互仅发送请求，不自行修改核心数据
- UI使用服务端数据驱动，动画/特效纯客户端
- Options设置界面控制BGM/音效开关，状态从玩家属性同步，音效由PlaySfx事件触发
- CoinBuff显示同服好友加成，文本随 FriendBonusPercent 更新，+xx%高亮
- Invite按钮触发系统默认邀请好友界面
- 全局排行榜界面通过 PushGlobalLeaderboard 刷新榜单与倒计时
- CoinAdd按钮在产速>=20/s显示，Number随产速实时刷新
- DoubleForever按钮显示下一档倍率与价格，购买后刷新至更高倍率
- 传送带盲盒刷新时挂载 CapsuleInfo BillboardGui，显示名称/价格/稀有度/品质颜色
- 手办模型展示时按稀有度切换Seat1~Seat5透明度，并在PartLbb挂载稀有度特效
- 开盲盒结果通过OpenEggResult驱动抽卡界面与升级进度动画
- 抽卡动画结束后通知 NotifyGachaFinished，服务端再触发新卡升台与镜头聚焦
- 抽卡结果播放前等待 AssetsPreloaded，并预加载本次盲盒/手办图标
- Index列表的CheckIcon进入Check检视界面，ViewportFrame展示手办并支持拖拽旋转（+/-30）
- Progression按钮打开养成界面，红点提示可领取奖励，ClaimTipsGui播放钻石领取动画
- 禁用系统背包，背包UI基于工具列表渲染，点击条目装备盲盒
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

