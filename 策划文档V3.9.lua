策划案V1.0 整体游戏玩法介绍

概述：
1.这是一款基于roblox开发的游戏，核心玩法是：一个服务器房间有多个玩家，每个玩家有自己的基地，玩家可以在自己的基地游玩自己的游戏内容
2.每个玩家都有一个Home，每个Home下都有一个传送带，传送带上每X秒都会自动产出一个蛋，蛋有不同的Id，每个蛋都会配置一个出现权重，每次生成蛋时，根据权重值，随机一个概率，确定本次生成的蛋的Id
3.不同的蛋有对应的金币价格，蛋刷新出现在传送蛋上后，从头随着传送带被传送至末端，到了末端后自动消失，就这样源源不断地不断产出蛋
4.蛋在传送带上时，玩家可以花费金币购买蛋，注意：玩家只能购买自己家传送带上产出地蛋，不能购买其他玩家地传送带地蛋
5.玩家购买蛋后蛋出现在背包中，玩家将蛋放置在自家地地板上，蛋进入孵化倒计时，每个蛋都有自己地孵化倒计时，蛋孵化倒计时结束后进入可开启状态，玩家可选择与蛋交互，从而触发打开蛋地过程
6.每个蛋都会对应一个卡池，这个蛋打开后只会产出对应卡池里面地宠物，这个卡池下的不同宠物都有对应的权重，每次打开蛋时，根据卡池中不同的蛋的权重，来决定本地开启这个蛋获得的宠物是什么
7.游戏设定中，有不同品质的宠物，每个品质下又有多个不同ID的宠物。
8.每个玩家的家中，都有一套图鉴系统，也就是多个展示牌，每个牌子对应一个特定id的宠物，当玩家未获得过这个宠物时，对应的牌子是“未开启”状态，如果玩家获得过这个宠物了，那这个牌子变成“已开启”状态
9.每个宠物都会配置一个基础的金币产出速度，每秒产出一次，比如某个宠物金币产出速度是10金币每秒，也就是每秒会产出10点金币，当这个宠物变成已开启状态后，就会不断自动产出金币，玩家可以点击这个宠物对应的牌子，来收取已经产出的金币，收取后金币清零重新开始积累
10.宠物有等级概念，消耗多个同id的宠物，可以给该宠物进行升级，比如1级的A宠物玩家获得后，又开启多个蛋，获得了多个A宠物，那么当数量达到A宠物1级升2级的数量时，宠物就会升级成功
11.宠物有品阶概念，比如初级品阶/中级品阶/高级品阶，当玩家获得了A宠物的初级品阶，后面又通过打开蛋获得了一个中级品阶的A宠物，那这个牌子的宠物的品阶就变为当前最高的品阶
12，一个卡牌的金币产出速度是跟等级和品质以及品阶相关的，大概公式可能是：金币产出速度=基础产速*（1+（当前等级 - 1）*品质系数）*品阶系数，这个公式只是在做框架设计时供理解，实际公式需要在后续的具体需求中去实现
13.只要玩家在线，这个卡牌产出的金币就可以一直累加，如果玩家离线，那么上线时，需要判断玩家的离线时间，如果超出了最高的产出累计时间，那最多只给最高累计时间的金币，比如每秒产速100金币，最多积累5分钟，玩家离线了3小时，那么上线后玩家最多获得30000金币


术语统一：盲盒=蛋=Capsule，手办=Figurine/宠物

正式需求：

策划案V1.1 玩家家园分配与玩家数据架构

家园分配：

1.我的游戏中，设定服务器人数上限为8人，也就是同服务器最多同时容纳8个玩家
2.每个玩家都有一个家园，每个玩家只能和自己家园中的各种道具或者交互物进行交互
3.在我的Workspace下，有个叫Home的文件夹，其下分别有Player01到Player08共8个文件夹，每个文件夹就代表一个家园的内容
4.以Player01举例，玩家加入游戏时，如果把玩家分配到了Player01这个家园，那么在Player01下有个SpawnLocation，这就是这个玩家的基础出生点
5.每次进入游戏系统分配玩家的家园是家园几，然后去家园文件夹下找玩家的出生点然后出生，并加载玩家的数据

基础数据：
1.金币：目前玩家的基础数据只设定金币这个维度
2.每个新玩家进入游戏时，都有一个基础金币，目前设定基础金币数值为500，这个需要创建一个GameConfig，在GameConfig中进行配置
3.金币数值是玩家的永久数值，需要保存在服务器

需求文档V1.2  金币数值显示与GM增减以及清零金币数值

1.在StarterGui - MainGui - CoinNum，这个textlabel，用于显示玩家当前的金币数值，格式默认为$xxxx,xxxx是金币数值
2.需要几个gm命令：增加指定数值金币/清除当前玩家的金币（注意只清除自己的而不是所有玩家，一定要注意！）
3.我希望后续的所有gm都放在一个脚本中，能够快速查询所有后续可用的gm命令


策划文档V1.3  盲盒（其实就是上面说的蛋，我们游戏中包装是盲盒）

概述：
传送带上会根据概率，不断生成盲盒，玩家可以购买盲盒来开启获得自己的手办（就是宠物，我们的游戏中包装上叫做手办）

盲盒的品质定义：
1.我们游戏中有多种盲盒，盲盒有品质定义，我们目前定义7种品质：
        a.品质1:Leaf
        b.品质2:Water
        c.品质3:Lunar
        d.品质4:Solar
        e.品质5:Flame
        f.品质6:Heart
        g.品质7:Celestial
我们在配置中就用1到5来表达从Leaf到Celestial


盲盒的稀有度定义：
1.每个盲盒还有稀有度定义，目前我们的稀有度分为：
    a.Common
    b.Light
    c.Gold
    d.Diamond
    e.Rainbow
我们在配置中就用1到5来表达从common到Rainbow

所以说：每个盲盒均有两个维度：品质与稀有度，比如某个盲盒，可能是品质leaf，稀有度Gold，也有可能是品质Lunar，稀有度Common

我的所有的盲盒模型全部放在ReplicatedStorage - Capsule下，在生成盲盒模型时，根据配置的盲盒名字去路径下找对应名字的盲盒即可

盲盒价格：
1.每个盲盒在传送带上出现时，玩家可花费金币去购买这个盲盒，所以每个盲盒有自己对应的金币价格
2.如果金币不足，则购买盲盒会失败，如果金币数量充足，则扣除对应数量的金币，移除盲盒，将盲盒移除出

盲盒购买：
玩家靠近盲盒，要在盲盒上出现游戏默认的交互键，文本内容为Buy，就系统默认的那个“E”键交互的格式，交互时间是0.1秒即可完成交互，玩家按E键或者点击按钮即可完成购买，要在交互键上显示出这个盲盒的价格，格式是$xxx


盲盒购买完成：
1.盲盒购买成功后，会出现在玩家默认的背包中（暂时使用默认的背包即可）

盲盒拿起：
1.玩家可以点击背包中的盲盒，把盲盒放置在地上。
2.放在地上的盲盒无法再被拿起来

盲盒开启倒计时：
1.每个盲盒均会配置一个开启倒计时，当盲盒被放置在地上后，会立刻开始开启倒计时，倒计时结束后，玩家与盲盒交互，可打开盲盒
2.这个版本我们只做到倒计时结束即可，与盲盒交互的逻辑以及具体的倒计时ui逻辑都下个版本再做
3，我们在配置表中的开启时间配置填的是秒

盲盒出现：
1.每个玩家家园中，都有一个叫ConveyorBelt的文件夹，这是我们的传送带的文件夹
2.ConveyorBelt文件夹下有个叫Start的Part，以Player01举例，每次蛋出现时，就在这里出现，然后被传送走；文件夹下也有个叫End的Part，每次盲盒移动到End的位置，就移除盲盒（与End发生碰撞即视为到达）
3.在传送带上，每1秒刷新一个盲盒，每次刷新时根据权重概率确定本次刷新的盲盒是什么即可

我们的盲盒初始开发版本的配置是：
Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）
1001	Leaf	1	1	Leaf	120	10
1002	Water	2	2	Water	140	15
1003	Lunar	3	1	Lunar	160	20
1004	Solar	4	2	Solar	180	25
1005	Flame	5	1	Flame	200	30
1006	Heart	6	2	Heart	220	35
1007	Celestial	7	1	Celestial	240	40


策划案V1.3.1 需求补充

需求补充：关于刷新盲盒的概率的

1.我们需要新启动一张配置表，里面会配置多套盲盒的刷新池子，在不同阶段，根据玩家的状态决定刷新盲盒时，从哪套刷新池子中去刷新盲盒
2.当前阶段开发默认使用1号刷新池的刷新方案即可

配置表初版是：
Id	刷新池编号	盲盒id	权重
10001	1	1001	30
10002	1	1002	20
10003	1	1003	8
10004	1	1004	6
10005	1	1005	4
10006	1	1006	2
10007	1	1007	1

策划案V1.4 关于盲盒的打开逻辑

1.每个盲盒都都提前配置的打开时间倒计时
2.当盲盒放在地上后，会自动进入打开倒计时，等倒计时结束后，盲盒变成可打开状态
3.可打开的盲盒，需要在盲盒上继续出现交互按钮，文本是Open，点击需要长按，点击即可打开盲盒
4.打开成功后，盲盒从地上消失

注意：这个版本只先做到打开盲盒成功这一步，具体打开获得什么的逻辑，后面版本做

策划文档V1.5  关于手办

概述
1.我们的游戏中，打开盲盒，可以获得手办，获得的手办是随机的，从对应的池子中根据权重确定获得的结果
2.每个盲盒对应不同的池子，都走单独的配置，所以我会给盲盒的配置表中加入对应的池子的id配置

关于手办：
1.有多种不同的手办，每个手办均有自己的独立id
2.每个手办均有其基础的金币产出速度，按秒来进行计算
3.每个手办均有其名字，在配置表中会进行配置
4.每个手办均有其模型资源形象，所有的模型路径都会放在ReplicatedStorage - LBB这个文件夹下，我会在配置表中配置手办对应的模型名字，直接去这个路径下找即可
5.每个品质都有其品质，和盲盒品质分类一样：
        a.品质1:Leaf
        b.品质2:Water
        c.品质3:Lunar
        d.品质4:Solar
        e.品质5:Flame
        f.品质6:Heart
        g.品质7:Celestial
6.每个手办也有其稀有度，和盲盒的稀有度对应：
    a.Common
    b.Light
    c.Gold
    d.Diamond
    e.Rainbow
7.每个布布都有对应的展台路径，这里我们会进行配置，对应下方的布布获得后出现在家园的哪个展台上


以上是一些关于手办的基础定义，这个版本我们主要是要配合盲盒来做手办的获得，以下是具体逻辑：

1.新增一张手办表，用来定义基础的手办信息：
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径
10001	绿叶布布1	10	1	1	LBB01	ShowCase/Green/Position1
10002	绿叶布布2	12	1	1	LBB01	ShowCase/Green/Position2
10003	绿叶布布3	14	1	1	LBB01	ShowCase/Green/Position3
10004	绿叶布布4	16	1	1	LBB01	ShowCase/Green/Position4
10005	绿叶布布5	18	1	1	LBB01	ShowCase/Green/Position5
10006	绿叶布布6	20	1	1	LBB01	ShowCase/Green/Position6
10007	绿叶布布7	22	1	1	LBB01	ShowCase/Green/Position7
10008	绿叶布布8	24	1	1	LBB01	ShowCase/Green/Position8
10009	绿叶布布9	26	1	1	LBB01	ShowCase/Green/Position9
20001	水布布1	50	2	1	LBB01	ShowCase/Blue/Position1
20002	水布布2	55	2	1	LBB01	ShowCase/Blue/Position2
20003	水布布3	60	2	1	LBB01	ShowCase/Blue/Position3
20004	水布布4	65	2	1	LBB01	ShowCase/Blue/Position4
20005	水布布5	70	2	1	LBB01	ShowCase/Blue/Position5
20006	水布布6	75	2	1	LBB01	ShowCase/Blue/Position6
20007	水布布7	80	2	1	LBB01	ShowCase/Blue/Position7
20008	水布布8	85	2	1	LBB01	ShowCase/Blue/Position8
20009	水布布9	90	2	1	LBB01	ShowCase/Blue/Position9



2.新增一张卡池表，所有的卡池汇总在这里，盲盒开启时根据自己对应的卡池id来这里寻找卡池

卡池id	手办id	刷新权重
卡池id	手办id	刷新权重
9001	10001	20
9001	10002	20
9001	10003	20
9001	10004	20
9001	10005	20
9001	10006	20
9001	10007	20
9001	10008	20
9001	10009	20
9002	20001	20
9002	20002	20
9002	20003	20
9002	20004	20
9002	20005	20
9002	20006	20
9002	20007	20
9002	20008	20
9002	20009	20



3.修改盲盒表，加入了盲盒对应卡池id的配置

Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）		盲盒对应卡池
1001	Leaf	1	1	Leaf	120	10		9001
1002	Water	2	2	Water	140	15		9002
1003	Lunar	3	1	Lunar	160	20		9001
1004	Solar	4	2	Solar	180	25		9002
1005	Flame	5	1	Flame	200	30		9001
1006	Heart	6	2	Heart	220	35		9002
1007	Celestial	7	1	Celestial	240	40		9002


4.关于手办获得：

    a.手办获得后，会在玩家家园的对应展台上出现手办模型，我们下面是以家园1举例，其他家园一样的逻辑
    b.Workspace - Home - Player01是家园1，在Player01下有个叫ShowCase的文件夹，下面有多个文件夹，每个文件夹下放着我们的展台，比如ShowCase - Green - Position1就是一个展台
    c.当一个手办玩家以前没有，现在拥有之后，就让这个手办模型放在对应的展台模型上，手办表有配置的展台模型路径

5.手办获得后，立刻开始不断产出金币

这个版本目前只开发到上述内容即可，剩下的内容我们下个版本继续做，抽出相同的bubu先不处理，后续我们做升级逻辑，这个版本先不处理


策划文档V1.6 关于金币产出/金币获取/金币产出上限

概述：现在的金币产出都是自动增加到玩家账户的，我希望的是，玩家能够通过手动操作领取金币而不是自动发放

详细规则：

1.手办获得后，产出的金币，积累在自身上，不是直接添加的玩家的账户
2.玩家需要通过碰撞手办对应的领取按钮模型，才能领取金币完成。每个手办都有一个单独对应的领取按钮，在手办表中配置路径即可
3.金币产出上限按时间累计，默认最多累计3小时（10800秒），超过3小时不领取就暂停产出，领取后重新开始累计

举例：某个手办产出速度是10金币每秒，那么1分钟累计产出了600金币，这些金币都是待领取状态，玩家触碰这个手办对应的领取按钮，才立刻把待领取的金币领取到自己账户

关于领取按钮的路径：

1.我的每个家园中，都有一套领取按钮模型，我们接下来以Player01的家园为例来进行需求讲解：
    a.Workspace - Home - Player01 - ClaimButton - ButtonBlue - Button1这是其中一个按钮的路径，Button1是一个Part，玩家触碰这个part即可触发对应手办的金币领取。注意这里要做触碰限制，比如0.5秒内最多触发一次领取，并且持续触碰的情况下只算触碰了一次，比如玩家站在这个part上，就算只触发1次，必须离开再过来，才算触碰第二次
    b.我在每个手办的触碰按钮字段下配置对应的领取按钮的路径，我的配置路径会配置到ClaimButton下的路径，比如我配置：ButtonBlue/Button1这个按钮就是去按Workspace - Home - Player01 - ClaimButton - ButtonBlue - Button1这个路径去找这个按钮

更新我的手办配置表为：

id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径
10001	绿叶布布1	10	1	1	LBB01	ShowCase/Green/Position1	ButtonGreen/Button1
10002	绿叶布布2	12	1	1	LBB01	ShowCase/Green/Position2	ButtonGreen/Button2
10003	绿叶布布3	14	1	1	LBB01	ShowCase/Green/Position3	ButtonGreen/Button3
10004	绿叶布布4	16	1	1	LBB01	ShowCase/Green/Position4	ButtonGreen/Button4
10005	绿叶布布5	18	1	1	LBB01	ShowCase/Green/Position5	ButtonGreen/Button5
10006	绿叶布布6	20	1	1	LBB01	ShowCase/Green/Position6	ButtonGreen/Button6
10007	绿叶布布7	22	1	1	LBB01	ShowCase/Green/Position7	ButtonGreen/Button7
10008	绿叶布布8	24	1	1	LBB01	ShowCase/Green/Position8	ButtonGreen/Button8
10009	绿叶布布9	26	1	1	LBB01	ShowCase/Green/Position9	ButtonGreen/Button9
20001	水布布1	50	2	1	LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1
20002	水布布2	55	2	1	LBB01	ShowCase/Blue/Position2	ButtonBlue/Button2
20003	水布布3	60	2	1	LBB01	ShowCase/Blue/Position3	ButtonBlue/Button3
20004	水布布4	65	2	1	LBB01	ShowCase/Blue/Position4	ButtonBlue/Button4
20005	水布布5	70	2	1	LBB01	ShowCase/Blue/Position5	ButtonBlue/Button5
20006	水布布6	75	2	1	LBB01	ShowCase/Blue/Position6	ButtonBlue/Button6
20007	水布布7	80	2	1	LBB01	ShowCase/Blue/Position7	ButtonBlue/Button7
20008	水布布8	85	2	1	LBB01	ShowCase/Blue/Position8	ButtonBlue/Button8
20009	水布布9	90	2	1	LBB01	ShowCase/Blue/Position9	ButtonBlue/Button9


关于手办信息的显示：

我们之前配置了每个手办对应的展台模型路径，在每个展台模型路径下，均有一个叫Platform的Part，初始手办未获得时，设定Platform的Size为7, 1, 7，当手办获得后，需要在展台上出现时，需要把Platform的Size设定为：7, 5, 7
在手办出现的过程中，Platform的Size变化时，我们需要一个变化过程，2秒内，size 的Y轴尺寸从1变到5

关于ui信息的展示：
当Platform尺寸变化结束后，需要在Platform的上复制一份手办信息，具体逻辑是，去ReplicatedStorage - InfoPart下寻找一个叫Info的SurfaceGui并复制，复制到Platform上，出现的Face是Front

Info - Name是一个textlabel，用于展示手办的名字，Info - Money是一个Textlabel，用于展示手办的金币相关信息，具体格式是：$xxx/（$yyy/S），XXX是已经积累的金币数值，要实时变化，领取后清零，yyy是当前的金币产出速度数值，也要随着手办的升级来实时变化（升级逻辑后面做这里先留好接口）

我们游戏中的所有的金币数值显示，都需要遵循一套大数值显示规则，具体规则可以在我另一个项目中参考，项目路径是：D:\RobloxGame\Prison\prisongame，使用一样的规则即可


策划文档V1.7  关于一些数据统计

我们需要新增多个统计数据维度：

1.玩家历史总共的游戏时间，只要玩家在线，就自动增加这个时间，实时更新，玩家多次游玩后，数据都是不断增加的，需要作为玩家的永久数据去储存
2.玩家总共开启过的盲盒数量：玩家每开一个盲盒，就自动数值+1
3.玩家每个Id的盲盒的总开启数量也需要记录，上面一条是总数，这里的是每个ID盲盒的开启数量
4.玩家的当前总的金币产出速度，就是所有的手办的当前的产出速度总和

我们需要把以上部分信息进行展示，暂时我做了个测试ui，用来暂时性的承载这些信息的显示，后面我会做正式的ui来显示界面

StarterGui -  TestInfo - Frame - CapsuleTotal，这是个textlabel，用于显示玩家的总共历史开启的盲盒总数
StarterGui -  TestInfo - Frame - OutoutSpeed，这是个textlabel，用于显示玩家当前的总产出速度，格式是：$xxx/S ，xxx是速度
StarterGui -  TestInfo - Frame - TimeTotal，这是个textlabel，用于显示玩家的总的游戏时间，格式xx:YY:ZZ,分别代表小时/分钟/秒

以上多个数据均是需要进行记录的数据，作为永久数据进行储存


策划文档V1.8 关于玩家信息显示

我们需要在玩家的基地显示出来玩家的信息，下面以Player01的家园为例子进行需求说明

1.Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg - PlayerIcon是一个imagelabel，用于显示这个基地所属玩家的头像
2.Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg - PlayerName是一个textlabel，用于显示玩家的名字
3.Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg - Speed是一个textlabel，用于显示玩家的当前总产出速度，这个我们已经在上一版做好了功能，显示数值即可，格式是$xxx/S,xxx是产出速度

当玩家离线这个基地释放后，需要将Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg的Visible属性改成False
只有有玩家的时候才把Workspace - Home - Player01 - Base - PlayerInfo - BillboardGui - Bg的Visible属性改成true


策划文档 V1.9 关于镜头聚焦

我希望在玩家开到一个新的手办，触发手办台子升起的时候，有个具体的镜头效果

详细规则：

1.玩家触发新手办升起台子时，需要快速将玩家的镜头移动到正好对准这个台子，此时玩家无法操纵镜头
2.镜头对准台子等待台子升起完成后，停顿0.5秒，然后将镜头快速重置回玩家的常规镜头视角并解除锁定
3.镜头从玩家身上移动到目标点时，要快速移动过去，并且有缓动效果，不要硬切，把各个参数都留出来让我调整，并做好参数作用的说明


策划文档V2.0  手办升级

1.手办可以通过消耗同Id的手办来进行升级
2.一个同id 的手办相当于1点经验值，每级升至下一级所需要消耗的经验点数不同，走经验表进行配置
3.所有的手办都使用同一套升级表

我的升级表配置如下

等级	升至下级所需经验值
1	2
2	4
3	8
4	16
5	32
6	64
7	128
8	256
9	512
10	1024
11	2048
12	4096
13	8192
14	16384
15	32768
16	65536

当某个卡片到达最高级时，就算达到了升级所需要的经验值，也不再升级，就保持在最高级

具体的客户端逻辑是：

手办出现时会去复制ReplicatedStorage - InfoPart - Info，这里存放了信息模板
其中Info - Level - LevelText是一个textlabel，用于显示手办当前的等级信息，格式是：LV.xxx,其中xxx是等级数值
其中Info - Level - ProgressBar是一个imagelabel，用于显示升级进度，用ProgressBar的Size中的X轴的大小来控制进度条变化，大小是用的Scale，当Size是0就代表进度条为0，Size为1就表示进度条满了


策划文档V2.1  增加部分正式数值的配置

1.我们的盲盒表配置修改，改成：
Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池
1001	Leaf	1	1	LeafCommon	50 	8	99001
1002	Water	2	1	WaterCommon	1500 	40	99001
1003	Lunar	3	1	LunarCommon	20000 	140	99001
1004	Solar	4	1	SolarCommon	180000 	480	99001
1005	Flame	5	1	FlameCommon	1200000 	1800	99001
1006	Heart	6	1	HeartCommon	5000000 	6600	99001
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001
2001	Leaf	1	2	LeafLight	100 	9	99001
2002	Water	2	2	WaterLight	3000 	44	99001
2003	Lunar	3	2	LunarLight	40000 	154	99001
2004	Solar	4	2	SolarLight	360000 	528	99001
2005	Flame	5	2	FlameLight	2400000 	1980	99001
2006	Heart	6	2	HeartLight	10000000 	7260	99001
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001
3001	Leaf	1	3	LeafGold	300 	10	99001
3002	Water	2	3	WaterGold	9000 	50	99001
3003	Lunar	3	3	LunarGold	120000 	175	99001
3004	Solar	4	3	SolarGold	1080000 	600	99001
3005	Flame	5	3	FlameGold	7200000 	2250	99001
3006	Heart	6	3	HeartGold	30000000 	8250	99001
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001
4001	Leaf	1	4	LeafDiamond	750 	12	99001
4002	Water	2	4	WaterDiamond	22500 	58	99001
4003	Lunar	3	4	LunarDiamond	300000 	203	99001
4004	Solar	4	4	SolarDiamond	2700000 	696	99001
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001
5001	Leaf	1	5	LeafRainbow	2500 	14	99001
5002	Water	2	5	WaterRainbow	75000 	68	99001
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001
5004	Solar	4	5	SolarRainbow	9000000 	816	99001
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001


我们的盲盒刷新卡池修改为：

Id	刷新池编号	盲盒id	权重
10001	1	1001	20
10002	1	1002	20
10003	1	1003	20
10004	1	1004	20
10005	1	1005	20
10006	1	1006	20
10007	1	1007	20
10008	1	2001	20
10009	1	2002	20
10010	1	2003	20
10011	1	2004	20
10012	1	2005	20
10013	1	2006	20
10014	1	2007	20
10015	1	3001	20
10016	1	3002	20
10017	1	3003	20
10018	1	3004	20
10019	1	3005	20
10020	1	3006	20
10021	1	3007	20
10022	1	4001	20
10023	1	4002	20
10024	1	4003	20
10025	1	4004	20
10026	1	4005	20
10027	1	4006	20
10028	1	4007	20
10029	1	5001	20
10030	1	5002	20
10031	1	5003	20
10032	1	5004	20
10033	1	5005	20
10034	1	5006	20
10035	1	5007	20


我们的手办表修改为：
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径
10001	绿叶布布1	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1
10002	绿叶布布2	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2
10003	绿叶布布3	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3
10004	绿叶布布4	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4
10005	绿叶布布5	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5
10006	绿叶布布6	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6
10007	绿叶布布7	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7
10008	绿叶布布8	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8
10009	绿叶布布9	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9
20001	水布布1	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1
20002	水布布2	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2
20003	水布布3	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3
20004	水布布4	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4
20005	水布布5	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5
20006	水布布6	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6
20007	水布布7	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7
20008	水布布8	116	2	1	Water/LBB07	ShowCase/Blue/Position8	ButtonBlue/Button8
20009	水布布9	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9
30001	月球布布1	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1
30002	月球布布2	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2
30003	月球布布3	285	3	1	Lunar/LBB02	ShowCase/Purple/Position3	ButtonPurple/Button3
30004	月球布布4	325	3	1	Lunar/LBB02	ShowCase/Purple/Position4	ButtonPurple/Button4
30005	月球布布5	370	3	1	Lunar/LBB02	ShowCase/Purple/Position5	ButtonPurple/Button5
30006	月球布布6	420	3	1	Lunar/LBB02	ShowCase/Purple/Position6	ButtonPurple/Button6
30007	月球布布7	480	3	1	Lunar/LBB02	ShowCase/Purple/Position7	ButtonPurple/Button7
30008	月球布布8	550	3	1	Lunar/LBB02	ShowCase/Purple/Position8	ButtonPurple/Button8
30009	月球布布9	630	3	1	Lunar/LBB02	ShowCase/Purple/Position9	ButtonPurple/Button9
40001	太阳布布1	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1
40002	太阳布布2	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2
40003	太阳布布3	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3
40004	太阳布布4	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4
40005	太阳布布5	1600	4	1	Solar/LBB04	ShowCase/Orange/Position5	ButtonOrange/Button5
40006	太阳布布6	1830	4	1	Solar/LBB04	ShowCase/Orange/Position6	ButtonOrange/Button6
40007	太阳布布7	2100	4	1	Solar/LBB04	ShowCase/Orange/Position7	ButtonOrange/Button7
40008	太阳布布8	2400	4	1	Solar/LBB04	ShowCase/Orange/Position8	ButtonOrange/Button8
40009	太阳布布9	2750	4	1	Solar/LBB04	ShowCase/Orange/Position9	ButtonOrange/Button9
50001	火焰布布1	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1
50002	火焰布布2	3400	5	1	Flame/LBB01	ShowCase/Red/Position2	ButtonRed/Button2
50003	火焰布布3	3850	5	1	Flame/LBB01	ShowCase/Red/Position3	ButtonRed/Button3
50004	火焰布布4	4350	5	1	Flame/LBB01	ShowCase/Red/Position4	ButtonRed/Button4
50005	火焰布布5	4900	5	1	Flame/LBB01	ShowCase/Red/Position5	ButtonRed/Button5
50006	火焰布布6	5550	5	1	Flame/LBB01	ShowCase/Red/Position6	ButtonRed/Button6
50007	火焰布布7	6300	5	1	Flame/LBB01	ShowCase/Red/Position7	ButtonRed/Button7
60001	心脏布布1	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1
60002	心脏布布2	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2
60003	心脏布布3	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3
60004	心脏布布4	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4
60005	心脏布布5	18000	6	1	Heart/LBB04	ShowCase/Yellow/Position5	ButtonYellow/Button5
60006	心脏布布6	20000	6	1	Heart/LBB04	ShowCase/Yellow/Position6	ButtonYellow/Button6
60007	心脏布布7	22300	6	1	Heart/LBB04	ShowCase/Yellow/Position7	ButtonYellow/Button7
70001	虚空布布1	33000	7	1	Heart/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1
70002	虚空布布2	38000	7	1	Heart/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2
70003	虚空布布3	44000	7	1	Heart/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3
70004	虚空布布4	51000	7	1	Heart/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4
70005	虚空布布5	59000	7	1	Heart/LBB04	ShowCase/Blue/Position5	ButtonBlue/Button5

关于手办表，你需要做的改动是：我们的手办模型之前是只填了名字，现在我改成了：路径/名字，比如填：Leaf/LBB01，就是去ReplicatedStorage - LBB - Leaf下找LBB01，这个规则要改动，最好把字段名字从ModelName改成ModelResource或者你定个其他名字

我们的手办卡池表改成：
卡池id	手办id	刷新权重
99001	10001	20
99001	10002	20
99001	10003	20
99001	10004	20
99001	10005	20
99001	10006	20
99001	10007	20
99001	10008	20
99001	10009	20
99001	20001	20
99001	20002	20
99001	20003	20
99001	20004	20
99001	20005	20
99001	20006	20
99001	20007	20
99001	20008	20
99001	20009	20
99001	30001	20
99001	30002	20
99001	30003	20
99001	30004	20
99001	30005	20
99001	30006	20
99001	30007	20
99001	30008	20
99001	30009	20
99001	40001	20
99001	40002	20
99001	40003	20
99001	40004	20
99001	40005	20
99001	40006	20
99001	40007	20
99001	40008	20
99001	40009	20
99001	50001	20
99001	50002	20
99001	50003	20
99001	50004	20
99001	50005	20
99001	50006	20
99001	50007	20
99001	60001	20
99001	60002	20
99001	60003	20
99001	60004	20
99001	60005	20
99001	60006	20
99001	60007	20
99001	70001	20
99001	70002	20
99001	70003	20
99001	70004	20
99001	70005	20


我们的升级经验消耗表改成：
等级	升至下级所需经验值
1	2
2	3
3	5
4	8
5	12
6	18
7	26
8	38
9	55
10	80
11	115
12	165
13	235
14	335
15	455


策划文档V2.2 手办产速计算

概述：我们的手办存在等级/品质/稀有度三个维度，每个手办有自己的基础产速，我们设定一个公式来确定一个手办的最终产速

最终一个手办的产速公式是：最终金币产速=基础产速*稀有度系数*（1+（等级-1）*品质系数）

我们的不同品质的手办的品质系数是：

品质	升级系数 
1	0.05
2	0.08
3	0.12
4	0.18
5	0.25
6	0.35
7	0.5

不同稀有度的系数是：
稀有度	系数
1	1
2	1.25
3	1.8
4	2.6
5	4.6

我们的每个手办都有其品质是固定的，这个属性直接读表即可

关于稀有度的规则是这样的：
我们有不同稀有度的盲盒，比如有稀有度1品质1的盲盒，稀有度2品质1的盲盒，稀有度3品质1的盲盒，或者稀有度1品质3，或者稀有度4品质3的盲盒

相同品质的盲盒，开出的手办id是永远固定的，比如稀有度1品质1和稀有度3品质1的盲盒，都只能开出品质1的手办，卡池是固定的
但是稀有度1品质1的盲盒开出的手办稀有度都是1，稀有度2品质1的盲盒开出的手办稀有度都是2
当一个手办有更高稀有度出现时，将这个手办的稀有度改成更高的稀有度
比如10001这个手办，之前都是稀有度1里面开出来的，那这个手办当前的稀有度就是1，按稀有度1的参数计算，如果在稀有度3的盒子里开出了这个10001的手办，那我的这个手办的稀有度就变成3，产速计算时也按稀有度3的参数算


策划文档V2.3 盲盒开启进度条

每个盲盒都有开启倒计时，被放在地上后会开始倒计时，玩家需要看到倒计时进度

具体规则是：
1.盲盒被放到地上后，立刻去ReplicatedStorage下复制OpenProgresTemplate，挂载给地上这个盲盒模型，直接做盲盒的子节点
2.OpenProgresTemplate - Bg - Progressbar的Size（用scale大小）变化来表达进度变化。Size的X轴大小是0就代表倒计时刚开始，Size的X轴大小是1就代表倒计时结束
3.OpenProgresTemplate - Bg - Text是一个文本，倒计时在倒计时过程中，需要把文本内容改成：xx:yy，xx是分钟，yy是秒，根据我们的倒计时去转换成分秒即可，但是如果时间大于1小时，xx就是小时，yy就是分钟
4.如果倒计时完成后，需要把Text的文本改成Ready!


策划文档V2.4 完善一下数据表，给盲盒和手办加图标

这是修改后的手办表：
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径	手办icon
10001	绿叶布布1	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1	rbxassetid://17449975508
10002	绿叶布布2	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2	rbxassetid://17449975508
10003	绿叶布布3	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3	rbxassetid://17449975508
10004	绿叶布布4	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4	rbxassetid://17449975508
10005	绿叶布布5	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5	rbxassetid://17449975508
10006	绿叶布布6	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6	rbxassetid://17449975508
10007	绿叶布布7	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7	rbxassetid://17449975508
10008	绿叶布布8	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8	rbxassetid://17449975508
10009	绿叶布布9	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9	rbxassetid://17449975508
20001	水布布1	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://17449975508
20002	水布布2	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://17449975508
20003	水布布3	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://17449975508
20004	水布布4	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://17449975508
20005	水布布5	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://17449975508
20006	水布布6	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6	rbxassetid://17449975508
20007	水布布7	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7	rbxassetid://17449975508
20008	水布布8	116	2	1	Water/LBB07	ShowCase/Blue/Position8	ButtonBlue/Button8	rbxassetid://17449975508
20009	水布布9	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9	rbxassetid://17449975508
30001	月球布布1	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1	rbxassetid://17449975508
30002	月球布布2	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2	rbxassetid://17449975508
30003	月球布布3	285	3	1	Lunar/LBB02	ShowCase/Purple/Position3	ButtonPurple/Button3	rbxassetid://17449975508
30004	月球布布4	325	3	1	Lunar/LBB02	ShowCase/Purple/Position4	ButtonPurple/Button4	rbxassetid://17449975508
30005	月球布布5	370	3	1	Lunar/LBB02	ShowCase/Purple/Position5	ButtonPurple/Button5	rbxassetid://17449975508
30006	月球布布6	420	3	1	Lunar/LBB02	ShowCase/Purple/Position6	ButtonPurple/Button6	rbxassetid://17449975508
30007	月球布布7	480	3	1	Lunar/LBB02	ShowCase/Purple/Position7	ButtonPurple/Button7	rbxassetid://17449975508
30008	月球布布8	550	3	1	Lunar/LBB02	ShowCase/Purple/Position8	ButtonPurple/Button8	rbxassetid://17449975508
30009	月球布布9	630	3	1	Lunar/LBB02	ShowCase/Purple/Position9	ButtonPurple/Button9	rbxassetid://17449975508
40001	太阳布布1	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1	rbxassetid://17449975508
40002	太阳布布2	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2	rbxassetid://17449975508
40003	太阳布布3	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3	rbxassetid://17449975508
40004	太阳布布4	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4	rbxassetid://17449975508
40005	太阳布布5	1600	4	1	Solar/LBB04	ShowCase/Orange/Position5	ButtonOrange/Button5	rbxassetid://17449975508
40006	太阳布布6	1830	4	1	Solar/LBB04	ShowCase/Orange/Position6	ButtonOrange/Button6	rbxassetid://17449975508
40007	太阳布布7	2100	4	1	Solar/LBB04	ShowCase/Orange/Position7	ButtonOrange/Button7	rbxassetid://17449975508
40008	太阳布布8	2400	4	1	Solar/LBB04	ShowCase/Orange/Position8	ButtonOrange/Button8	rbxassetid://17449975508
40009	太阳布布9	2750	4	1	Solar/LBB04	ShowCase/Orange/Position9	ButtonOrange/Button9	rbxassetid://17449975508
50001	火焰布布1	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1	rbxassetid://17449975508
50002	火焰布布2	3400	5	1	Flame/LBB01	ShowCase/Red/Position2	ButtonRed/Button2	rbxassetid://17449975508
50003	火焰布布3	3850	5	1	Flame/LBB01	ShowCase/Red/Position3	ButtonRed/Button3	rbxassetid://17449975508
50004	火焰布布4	4350	5	1	Flame/LBB01	ShowCase/Red/Position4	ButtonRed/Button4	rbxassetid://17449975508
50005	火焰布布5	4900	5	1	Flame/LBB01	ShowCase/Red/Position5	ButtonRed/Button5	rbxassetid://17449975508
50006	火焰布布6	5550	5	1	Flame/LBB01	ShowCase/Red/Position6	ButtonRed/Button6	rbxassetid://17449975508
50007	火焰布布7	6300	5	1	Flame/LBB01	ShowCase/Red/Position7	ButtonRed/Button7	rbxassetid://17449975508
60001	心脏布布1	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1	rbxassetid://17449975508
60002	心脏布布2	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2	rbxassetid://17449975508
60003	心脏布布3	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3	rbxassetid://17449975508
60004	心脏布布4	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4	rbxassetid://17449975508
60005	心脏布布5	18000	6	1	Heart/LBB04	ShowCase/Yellow/Position5	ButtonYellow/Button5	rbxassetid://17449975508
60006	心脏布布6	20000	6	1	Heart/LBB04	ShowCase/Yellow/Position6	ButtonYellow/Button6	rbxassetid://17449975508
60007	心脏布布7	22300	6	1	Heart/LBB04	ShowCase/Yellow/Position7	ButtonYellow/Button7	rbxassetid://17449975508
70001	虚空布布1	33000	7	1	Heart/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://17449975508
70002	虚空布布2	38000	7	1	Heart/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://17449975508
70003	虚空布布3	44000	7	1	Heart/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://17449975508
70004	虚空布布4	51000	7	1	Heart/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://17449975508
70005	虚空布布5	59000	7	1	Heart/LBB04	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://17449975508


这是修改后的盲盒表：

Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon
1001	Leaf	1	1	LeafCommon	50 	8	99001	rbxassetid://98616255072587
1002	Water	2	1	WaterCommon	1500 	40	99001	rbxassetid://98616255072587
1003	Lunar	3	1	LunarCommon	20000 	140	99001	rbxassetid://98616255072587
1004	Solar	4	1	SolarCommon	180000 	480	99001	rbxassetid://98616255072587
1005	Flame	5	1	FlameCommon	1200000 	1800	99001	rbxassetid://98616255072587
1006	Heart	6	1	HeartCommon	5000000 	6600	99001	rbxassetid://98616255072587
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001	rbxassetid://98616255072587
2001	Leaf	1	2	LeafLight	100 	9	99001	rbxassetid://98616255072587
2002	Water	2	2	WaterLight	3000 	44	99001	rbxassetid://98616255072587
2003	Lunar	3	2	LunarLight	40000 	154	99001	rbxassetid://98616255072587
2004	Solar	4	2	SolarLight	360000 	528	99001	rbxassetid://98616255072587
2005	Flame	5	2	FlameLight	2400000 	1980	99001	rbxassetid://98616255072587
2006	Heart	6	2	HeartLight	10000000 	7260	99001	rbxassetid://98616255072587
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001	rbxassetid://98616255072587
3001	Leaf	1	3	LeafGold	300 	10	99001	rbxassetid://98616255072587
3002	Water	2	3	WaterGold	9000 	50	99001	rbxassetid://98616255072587
3003	Lunar	3	3	LunarGold	120000 	175	99001	rbxassetid://98616255072587
3004	Solar	4	3	SolarGold	1080000 	600	99001	rbxassetid://98616255072587
3005	Flame	5	3	FlameGold	7200000 	2250	99001	rbxassetid://98616255072587
3006	Heart	6	3	HeartGold	30000000 	8250	99001	rbxassetid://98616255072587
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001	rbxassetid://98616255072587
4001	Leaf	1	4	LeafDiamond	750 	12	99001	rbxassetid://98616255072587
4002	Water	2	4	WaterDiamond	22500 	58	99001	rbxassetid://98616255072587
4003	Lunar	3	4	LunarDiamond	300000 	203	99001	rbxassetid://98616255072587
4004	Solar	4	4	SolarDiamond	2700000 	696	99001	rbxassetid://98616255072587
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001	rbxassetid://98616255072587
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001	rbxassetid://98616255072587
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001	rbxassetid://98616255072587
5001	Leaf	1	5	LeafRainbow	2500 	14	99001	rbxassetid://98616255072587
5002	Water	2	5	WaterRainbow	75000 	68	99001	rbxassetid://98616255072587
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001	rbxassetid://98616255072587
5004	Solar	4	5	SolarRainbow	9000000 	816	99001	rbxassetid://98616255072587
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001	rbxassetid://98616255072587
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001	rbxassetid://98616255072587
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001	rbxassetid://98616255072587


策划文档V2.5 新的背包

概述：现在的背包用的是系统默认的背包，我们要改成我自制的背包ui

详细规则：
1.StarterGui - BackpackGui - BackpackFrame是我的背包页面，当玩家背包中的盲盒数大于等于1时，就显示出来（visible属性改成true），如果没有盲盒就改成false
2.BackpackGui - BackpackFrame - ItemListFrame - ArmyTemplate是盲盒信息模板，需要生成时，就复制一份出来，把visible属性改成True，并且更正对应的信息
3.ArmyTemplate - Icon是盲盒图标，用于显示盲盒的图标
4.ArmyTemplate - Number是textlabel，用于显示盲盒的数量，格式固定是：*x，x是该盲盒拥有的数量
5.点击背包中的任意一个盲盒，也可以触发拿到手里，这个逻辑和默认背包是一样的
6.新的背包系统不限制盲盒的拥有数量


策划文档V2.6 盲盒背包界面

我们的玩家购买了很多盲盒后，需要有一个统一查看的地方，现在是在背包中展示，但是我希望做一个ui，在ui中展示所有的盲盒

详细规则：

1.玩家点击StarterGui - MainGui - Bag这个按钮，打开盲盒背包界面（把StarterGui - Bag - BagBg的Visible属性改成True）
2.点击StarterGui - Bag - BagBg - Title - CloseButton按钮，关闭盲盒界面（把StarterGui - Bag - BagBg的Visible属性改成false）
3.StarterGui - Bag - BagBg - ScrollingFrame 是用来容纳所有我有的盲盒的列表，其中ScrollingFrame - CapsuleTemplate是盲盒信息模板，要生成盲盒信息时去复制CapsuleTemplate，并更改其信息，生成一个盲盒信息
4.CapsuleTemplate - Icon是盲盒的图标，CapsuleTemplate - Name是盲盒的名字，CapsuleTemplate - Number是盲盒的拥有数量
5.盲盒的排序按盲盒表中的id，Id越大，越排在前面


关于盲盒列表的筛选：

1.StarterGui - Bag - BagBg - TabList - ScrollingFrame下放了一些按钮，这些按钮主要是用来对盲盒的筛选
2.点击 TabList - ScrollingFrame - Leaf按钮，只显示所有品质1的盲盒
3.点击 TabList - ScrollingFrame - Water按钮，只显示所有品质2的盲盒
4.点击 TabList - ScrollingFrame - Lunar按钮，只显示所有品质3的盲盒
5.点击 TabList - ScrollingFrame - Solar按钮，只显示所有品质4的盲盒
6.点击 TabList - ScrollingFrame - Flame按钮，只显示所有品质5的盲盒
7.点击 TabList - ScrollingFrame - Heart按钮，只显示所有品质6的盲盒
8.点击 TabList - ScrollingFrame - Celestial按钮，只显示所有品质7的盲盒
9.点击 TabList - ScrollingFrame - Total按钮，显示所有盲盒
10.每次打开界面，默认是显示所有盲盒


策划文档V2.7 索引功能需求

概述：我们要做一个索引功能，类似于图鉴一样的逻辑，具体规则见下面

详细规则：

1.玩家点击StarterGui - MainGui - Index这个按钮，打开Index索引界面（把StarterGui - Index - IndexBg的Visible属性改成True）
2.玩家点击StarterGui - Index - IndexBg - Title - CloseButton按钮，关闭Index索引界面（把StarterGui - Index - IndexBg的Visible属性改成False）
3.我们的手办是分品质的，所以我们的索引界面，是要按品质来进行显示的，每个品质列表下只显示该品质的手办

4.StarterGui - Index - IndexBg - TabList - ScrollingFrame下有多个按钮，每个按钮分别对应各自品质的手办筛选，具体的逻辑是：

    a.ScrollingFrame - Leaf,对应品质1
    b.ScrollingFrame - Water,对应品质2
    c.ScrollingFrame - Lunar,对应品质3
    d.ScrollingFrame - Solar,对应品质4
    e.ScrollingFrame - Flame,对应品质5
    f.ScrollingFrame - Heart,对应品质6
    g.ScrollingFrame - Celestial,对应品质7

5.下面是详细的单个手办展示的信息规则：
    a.StarterGui - Index - IndexBg - InfoBg - ScrollingFrame是用于承载每个品质下所有手办信息的列表容器
    b.ScrollingFrame - FigurineTemplate是手办信息模板，要生成手办信息时，去复制一份FigurineTemplate，然后更改信息，即成为一个手办信息
    c.FigurineTemplate - Icon是手办图标，FigurineTemplate - Name是手办名字，根据手办数据生成对应信息即可
    d.这个Index列表中展示的是所有的手办，所以每次我更新了新的手办，列表里也要对应生成新的手办的信息，每次登录游戏后更新一轮数据即可，不用每次打开界面都去更新
    e.某个手办如果玩家已经获得了，就保持默认状态即可
    f.某个手办如果玩家没有获得，则需要把：FigurineTemplate - Name隐藏，把FigurineTemplate - Icon的ImageColor3的颜色改成纯黑（注意一定是ImageColor3属性），同时把FigurineTemplate - QuestionMark的Visible属性改成True

6.手办列表按表中的顺序从上到下排列即可
7.StarterGui - Index - IndexBg - InfoBg - CurrentNum是一个textlabel，用于显示当前这个品质玩家获得的手办数量，比如这个品质共9个手办，玩家获得了3个，就显示为3/9
8.StarterGui - Index - IndexBg - InfoBg - TotalNum是一个textlabel，用于所有手办玩家获情况，比如所有品质手办加起来共20个手办，玩家获得了3个，就显示为3/20
9.以上两个信息玩家每次打开界面时都需要实时更新数值状态


策划文档V2.8 检视功能

我们需要对我们的手办进行检视，具体的逻辑是

1.在Index界面，每个手办信息界面下，都有个按钮叫CheckIcon，比如InfoBg - ScrollingFrame - FigurineTemplate - CheckIcon
2.未解锁的手办，需要把CheckIcon的Visible属性设定为False，已经解锁的手办才设定为True
3.玩家点击CheckIcon按钮，触发对这个手办的检视，具体表现是：
    1）.关闭Index界面与Backpack界面
    2）.将StarterGui - Check - CheckBg的Visible属性改成True
    3）.在Check - CheckBg - ViewportFrame中加载我们的手办模型，每个手办模型都有配置的具体的模型名字
    4）.玩家点击Check - CheckBg - Exit按钮可以关闭检视界面，并再次自动打开Index界面，并且要回到刚才检视这个手办的那个定位位置
    5）.模型在界面上加载出来后，我们可以对模型进行检视，具体的检视的逻辑是：
        a.加载的模型需要确保能够正好显示在ViewportFrame中
        b.模型需要正对屏幕中心
        c.玩家可以通过拖动鼠标或者在手机屏幕上来回滑动触发对模型的检视
        d.比如我鼠标向右移动，模型就向右旋转，向左移动就向左旋转，向下移动就向下旋转
        e.但是注意：每个模型的检视都有旋转限制，比如朝某个方向最多旋转30度。
        f.具体的旋转跟随鼠标或者手指的效果我也不懂具体逻辑，你可以看下面这些图片，是竞品的检视效果，我们做成一样即可：
        图片分别是："D:\RobloxGame\Labubu\Labubu\默认状态.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向右滑动到极限.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向左滑动到极限.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向下滑动到极限.png"
        "D:\RobloxGame\Labubu\Labubu\鼠标向上滑动到极限.png"

策划文档V2.9  领取全部/自动领取与十倍领取

概述：我们需要在游戏内加入一些付费功能，分别是：一次性全部领取/一次性十倍领取所有金币/自动领取功能

接下来我们按Player01的家园举例，来进行需求说明

详细规则之领取全部：
1.玩家触碰自家家园下的Workspace - Home - Player01 - Base - ClaimAll - Touch这个Part，触发对开发者道具：3514031081的购买
2.玩家购买成功后，领取当前所有的未领取的金币，注意是玩家基地中属于玩家的所有手办产出的未领取的金币，一次性全部领取
3.玩家进入游戏后，需要把Workspace - Home - Player01 - Base - ClaimAll - ClaimAll - CashNum的文本改成当前总共积累的未领取的金币总值，格式是$xxx，xxx是金币数值，这里也要用大数值逻辑来做
4.注意不要连续触发多次，玩家触碰后，一定要离开后再次触碰，才触发这个购买

详细规则之十倍全部领取：
1.玩家触碰自家家园下的Workspace - Home - Player01 - Base - ClaimAllTen - Touch这个Part，触发对开发者道具：3514031237的购买
2.玩家购买成功后，领取当前所有的未领取的金币数值的十倍，注意是玩家基地中属于玩家的所有手办产出的未领取的金币的十倍，一次性全部领取，比如当前积累了100点金币，那领取的就是1000
3.玩家进入游戏后，需要把Workspace - Home - Player01 - Base - ClaimAllTen - CollectTen - Bg - CashNum文本改成当前总共积累的未领取的金币总值的10倍数值，格式是$xxx，xxx是金币数值，这里也要用大数值逻辑来做
4.注意不要连续触发多次，玩家触碰后，一定要离开后再次触碰，才触发这个购买

详细规则之自动领取：

1.玩家触碰自家家园下的Workspace - Home - Player01 - Base - Auto - Touch这个Part，触发对通行证：1673138854的购买
2.玩家购买成功这个通行证后，会获得自动收集功能
3.在获得这个通行证后，需要把玩家家园内的ClaimAll和ClaimAllTen这两个Part都移除，让玩家无法再触发这俩开发者道具的购买
4.再获得这个通行证后，需要把玩家家园内的Workspace - Home - Player01 - Base - Auto - AutoCollect - Inactive的Visible属性改成False，将Workspace - Home - Player01 - Base - Auto - AutoCollect - Active的Visible属性改成True
5.注意：Workspace - Home - Player01 - Base - Auto - AutoCollect - Active - Collecting是一个班textlabel，当显示出来后，需要设定文本内容为Collecting，然后每0.7秒在文本后多加一个.，当达到三个点时，下一次清零重新从0个点开始，这样做出一个1/2/3个点来回循环的动态效果。
6.具体动态效果可以看这个项目：D:\RobloxGame\Prison\prisongame中关于自动挑战部分，在开战后的文本表现形式，也是在后面三个点不断循环

需要加的GM：加一个命令，让我能获得自动功能，也要能重置我的自动功能。当我获得了自动功能后要视为我购买成功了这个通行证。重置后视为我未购买

补充规则：盲盒放置数量限制
1.每个玩家家园内，地面最多可放置12个盲盒
2.倒计时中的盲盒，以及倒计时结束但未打开的盲盒，都占用名额
3.超过限制后无法放置到地上，并提示系统消息：Placement limit reached


策划文档V3.0  开盲盒结果表现

概述：我们需要在玩家开启盲盒后，给一个开盲盒过程表现，让玩家知道这次开的盲盒的结果是什么

详细规则：

1.玩家与盲盒交互开启盲盒后，需要先立刻弹出抽卡结果界面：
    a.将StarterGui - GachaResult - Result显示出来（之前的默认Visible属性是false，显示出来就是改成True）
    b.显示出来时，需要把StarterGui - GachaResult - Result - Cover的图片资源换成盲盒对应的展示图片（在盲盒表中会有配置）
    c.出现时，需要有从屏幕外面滑进来到目标位置，快速滑进来，可以从屏幕下方滑动出来。
    
    以上是开启动画的第一步：弹出盲盒背面
    下面是开启动画第二步：展示开启结果：
    a.StarterGui - GachaResult - Result滑动到目标位置后，停留0.5秒，然后做一个翻转动画（注意这个翻转是朝屏幕里翻转那种翻转，不是上下翻转，比如一个图片，以中轴线为中心，然后翻转，也就是始终竖着的那种翻转，希望你能明白）
    b.总体目标是翻转180度，看起来像翻面，当翻到90度时，需要立刻把StarterGui - GachaResult - Result - Cover隐藏起来，然后把StarterGui - GachaResult - Icon显示出来，这是手办图标，需要把StarterGui - GachaResult - Result - Name显示出来，这是手办名字，需要把StarterGui - GachaResult - Result - Rare显示出来，这是稀有度，需要把StarterGui - GachaResult - Result - Speed显示出来，这是基础产速
    c.以上几个内容显示出来的时候，需要把这几个对应的信息替换成手办的对应信息
    d.然后继续完成翻转，看起来是一个反面的过程
    e.在翻面完成后，如果这是一个全新的从未获得过的手办，在翻面完成后，需要把StarterGui - GachaResult - Result - NewTitle显示出来

    以上是开启动画的第三步，展示变化：
    1.如果是已经获得过的卡，则在翻转完成瞬间，需要把StarterGui - GachaResult - LevelUp显示出来
    2.LevelUp下也有Icon/Name/Rare/Speed这几个子节点，也要替换对应的信息
    3.在LevelUp - Bg - Progressbar是一个进度条，Size用X的Scale，当Size是0，就是进度条为0，如果Size是1就是进度条满。同时LevelUp - Bg - Text是等级信息，格式是Lv.x,x是等级数字
    4.当StarterGui - GachaResult - LevelUp显示出来后，需要立刻播进度条动画，进度条从当前进度线性变化到升级后的进度，在0.5秒内完成，在进度条动画播放完后，把等级文本更新成最新的等级文本
    5.当进度条动画播放完成后，也要把LevelUp - Speed的文本内容替换为最新的产出速度，这里是经过产速公式计算后的最终产出速度

    以上是开启动画的第三步，最后是第四步，共同消失：
    1.在升级动画播放完成后，Result和LevelUp共同向屏幕上方滑动，移出屏幕，完成整个开启动画的展示
    2.如果这是全新的卡，就不出现升级相关的内容（也就是第三步），展示完成后就向上移动移出屏幕即可

2.如果开的是新卡，在卡移动出屏幕后，在开始播放新手办获得时，台子升起来的镜头动画，所以流程是：展示封面 - 开启 - 展示结果 - 卡消失 - 播放镜头动画


我们需要在盲盒表中加入每个盲盒的展示图片字段信息，更新后的盲盒表是这样的：
Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon	盲盒展示图片
1001	Leaf	1	1	LeafCommon	50 	8	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1002	Water	2	1	WaterCommon	1500 	40	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1003	Lunar	3	1	LunarCommon	20000 	140	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1004	Solar	4	1	SolarCommon	180000 	480	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1005	Flame	5	1	FlameCommon	1200000 	1800	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1006	Heart	6	1	HeartCommon	5000000 	6600	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2001	Leaf	1	2	LeafLight	100 	9	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2002	Water	2	2	WaterLight	3000 	44	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2003	Lunar	3	2	LunarLight	40000 	154	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2004	Solar	4	2	SolarLight	360000 	528	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2005	Flame	5	2	FlameLight	2400000 	1980	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2006	Heart	6	2	HeartLight	10000000 	7260	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3001	Leaf	1	3	LeafGold	300 	10	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3002	Water	2	3	WaterGold	9000 	50	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3003	Lunar	3	3	LunarGold	120000 	175	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3004	Solar	4	3	SolarGold	1080000 	600	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3005	Flame	5	3	FlameGold	7200000 	2250	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3006	Heart	6	3	HeartGold	30000000 	8250	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4001	Leaf	1	4	LeafDiamond	750 	12	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4002	Water	2	4	WaterDiamond	22500 	58	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4003	Lunar	3	4	LunarDiamond	300000 	203	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4004	Solar	4	4	SolarDiamond	2700000 	696	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5001	Leaf	1	5	LeafRainbow	2500 	14	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5002	Water	2	5	WaterRainbow	75000 	68	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5004	Solar	4	5	SolarRainbow	9000000 	816	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001	rbxassetid://98616255072587	rbxassetid://98616255072587
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001	rbxassetid://98616255072587	rbxassetid://98616255072587


需要同步为我更新盲盒配置表


策划文档V3.1  更新一版手办表 
id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径	手办icon
10001	绿叶布布1	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1	rbxassetid://106915271340222
10002	绿叶布布2	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2	rbxassetid://105301091167285
10003	绿叶布布3	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3	rbxassetid://92602393759769
10004	绿叶布布4	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4	rbxassetid://77465737689764
10005	绿叶布布5	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5	rbxassetid://128609371638881
10006	绿叶布布6	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6	rbxassetid://77006643082762
10007	绿叶布布7	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7	rbxassetid://97576907938982
10008	绿叶布布8	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8	rbxassetid://100640430095892
10009	绿叶布布9	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9	rbxassetid://107958283001957
20001	水布布1	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://73924471186576
20002	水布布2	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://97475868474045
20003	水布布3	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://94121257331073
20004	水布布4	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://80371625018349
20005	水布布5	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://131567376824995
20006	水布布6	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6	rbxassetid://98646372357977
20007	水布布7	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7	rbxassetid://131567376824995
20008	水布布8	116	2	1	Water/LBB07	ShowCase/Blue/Position8	ButtonBlue/Button8	rbxassetid://120763170661369
20009	水布布9	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9	rbxassetid://87646054592825
30001	月球布布1	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1	rbxassetid://116214626452083
30002	月球布布2	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2	rbxassetid://133690692800448
30003	月球布布3	285	3	1	Lunar/LBB02	ShowCase/Purple/Position3	ButtonPurple/Button3	rbxassetid://77847158725505
30004	月球布布4	325	3	1	Lunar/LBB02	ShowCase/Purple/Position4	ButtonPurple/Button4	rbxassetid://100929113578714
30005	月球布布5	370	3	1	Lunar/LBB02	ShowCase/Purple/Position5	ButtonPurple/Button5	rbxassetid://77847158725505
30006	月球布布6	420	3	1	Lunar/LBB02	ShowCase/Purple/Position6	ButtonPurple/Button6	rbxassetid://98084586375258
30007	月球布布7	480	3	1	Lunar/LBB02	ShowCase/Purple/Position7	ButtonPurple/Button7	rbxassetid://81392569495246
30008	月球布布8	550	3	1	Lunar/LBB02	ShowCase/Purple/Position8	ButtonPurple/Button8	rbxassetid://107529498094392
30009	月球布布9	630	3	1	Lunar/LBB02	ShowCase/Purple/Position9	ButtonPurple/Button9	rbxassetid://107304908021027
40001	太阳布布1	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1	rbxassetid://123301796994352
40002	太阳布布2	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2	rbxassetid://135903948038055
40003	太阳布布3	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3	rbxassetid://137010302356268
40004	太阳布布4	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4	rbxassetid://133825497379267
40005	太阳布布5	1600	4	1	Solar/LBB04	ShowCase/Orange/Position5	ButtonOrange/Button5	rbxassetid://78728521411560
40006	太阳布布6	1830	4	1	Solar/LBB04	ShowCase/Orange/Position6	ButtonOrange/Button6	rbxassetid://98165717690396
40007	太阳布布7	2100	4	1	Solar/LBB04	ShowCase/Orange/Position7	ButtonOrange/Button7	rbxassetid://133103323967935
40008	太阳布布8	2400	4	1	Solar/LBB04	ShowCase/Orange/Position8	ButtonOrange/Button8	rbxassetid://71595524788019
40009	太阳布布9	2750	4	1	Solar/LBB04	ShowCase/Orange/Position9	ButtonOrange/Button9	rbxassetid://132021136924285
50001	火焰布布1	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1	rbxassetid://81520307684372
50002	火焰布布2	3400	5	1	Flame/LBB01	ShowCase/Red/Position2	ButtonRed/Button2	rbxassetid://90342220987736
50003	火焰布布3	3850	5	1	Flame/LBB01	ShowCase/Red/Position3	ButtonRed/Button3	rbxassetid://73676714004019
50004	火焰布布4	4350	5	1	Flame/LBB01	ShowCase/Red/Position4	ButtonRed/Button4	rbxassetid://108104612245462
50005	火焰布布5	4900	5	1	Flame/LBB01	ShowCase/Red/Position5	ButtonRed/Button5	rbxassetid://121911610580026
50006	火焰布布6	5550	5	1	Flame/LBB01	ShowCase/Red/Position6	ButtonRed/Button6	rbxassetid://107904367562204
50007	火焰布布7	6300	5	1	Flame/LBB01	ShowCase/Red/Position7	ButtonRed/Button7	rbxassetid://98108287971614
60001	心脏布布1	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1	rbxassetid://129520383058807
60002	心脏布布2	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2	rbxassetid://125879099426075
60003	心脏布布3	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3	rbxassetid://131333015213094
60004	心脏布布4	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4	rbxassetid://136225094377885
60005	心脏布布5	18000	6	1	Heart/LBB04	ShowCase/Yellow/Position5	ButtonYellow/Button5	rbxassetid://112335648315899
60006	心脏布布6	20000	6	1	Heart/LBB04	ShowCase/Yellow/Position6	ButtonYellow/Button6	rbxassetid://84929220767434
60007	心脏布布7	22300	6	1	Heart/LBB04	ShowCase/Yellow/Position7	ButtonYellow/Button7	rbxassetid://136190154597023
70001	虚空布布1	33000	7	1	Heart/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://137355628441296
70002	虚空布布2	38000	7	1	Heart/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://105553650967188
70003	虚空布布3	44000	7	1	Heart/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://83967828201151
70004	虚空布布4	51000	7	1	Heart/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://135305551396163
70005	虚空布布5	59000	7	1	Heart/LBB04	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://78448815998112

以上是我更新后的手办表，需要你帮我更新配置

策划文档V3.2 关于镜头动画的一些调整

1.现在抽卡动画结束后，镜头时立刻对准目标开始播放动画，现在希望抽卡动画结束后的时间再延长一点再去对准目标播动画
2.在动画结束后，以前是立刻回到玩家镜头，现在需要修改为：镜头动画播放完后，保持结束状态，然后把StarterGui - Camera - Exit的Visivle属性改成True显示出来
3.玩家点击Exit按钮，立刻恢复玩家镜头，但是注意：是硬切，不要做之前的镜头线性返回的效果了

另外补充一个规则：玩家点击StarterGui - MainGui - Home按钮，立刻将玩家传送回基地出生位置

策划文档V3.3 补充关于index的功能

在我们的index界面中，有关于每个品质解锁了多少个的显示，现在我们在界面上增加了图标的展示功能
具体规则是：

1.玩家切换页签切换品质的时候，需要把StarterGui - Index - IndexBg - InfoBg - CurrentIcon的图片内容换成对应品质的图标

品质与对应的图标是：

品质1	leaf	rbxassetid://108955563208582
品质2	water	rbxassetid://133424751984403
品质3	lunar	rbxassetid://97174425150192
品质4	solar	rbxassetid://130407159333392
品质5	flame	rbxassetid://137727751536051
品质6	heart	rbxassetid://115976015958196
品质7	celestial	rbxassetid://110967078953865


策划文档V3.4 修改一下盲盒表相关的配置

Id	盲盒名字	盲盒品质	盲盒稀有度	盲盒模型名字	盲盒价格	开启倒计时（秒）	盲盒对应卡池	盲盒icon	盲盒展示图片
1001	Leaf	1	1	LeafCommon	50 	8	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
1002	Water	2	1	WaterCommon	1500 	40	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
1003	Lunar	3	1	LunarCommon	20000 	140	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
1004	Solar	4	1	SolarCommon	180000 	480	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
1005	Flame	5	1	FlameCommon	1200000 	1800	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
1006	Heart	6	1	HeartCommon	5000000 	6600	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
1007	Celestial	7	1	CelestialCommon	20000000 	19800	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
2001	Leaf	1	2	LeafLight	100 	9	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
2002	Water	2	2	WaterLight	3000 	44	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
2003	Lunar	3	2	LunarLight	40000 	154	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
2004	Solar	4	2	SolarLight	360000 	528	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
2005	Flame	5	2	FlameLight	2400000 	1980	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
2006	Heart	6	2	HeartLight	10000000 	7260	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
2007	Celestial	7	2	CelestialLight	40000000 	21780	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
3001	Leaf	1	3	LeafGold	300 	10	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
3002	Water	2	3	WaterGold	9000 	50	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
3003	Lunar	3	3	LunarGold	120000 	175	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
3004	Solar	4	3	SolarGold	1080000 	600	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
3005	Flame	5	3	FlameGold	7200000 	2250	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
3006	Heart	6	3	HeartGold	30000000 	8250	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
3007	Celestial	7	3	CelestialGold	120000000 	24750	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
4001	Leaf	1	4	LeafDiamond	750 	12	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
4002	Water	2	4	WaterDiamond	22500 	58	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
4003	Lunar	3	4	LunarDiamond	300000 	203	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
4004	Solar	4	4	SolarDiamond	2700000 	696	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
4005	Flame	5	4	FlameDiamond	18000000 	2610	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
4006	Heart	6	4	HeartDiamond	75000000 	9570	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
4007	Celestial	7	4	CelestialDiamond	300000000 	28710	99001	rbxassetid://120738172280657	rbxassetid://98616255072587
5001	Leaf	1	5	LeafRainbow	2500 	14	99001	rbxassetid://107877804846649	rbxassetid://98616255072587
5002	Water	2	5	WaterRainbow	75000 	68	99001	rbxassetid://91134558890103	rbxassetid://98616255072587
5003	Lunar	3	5	LunarRainbow	1000000 	238	99001	rbxassetid://121158065949906	rbxassetid://98616255072587
5004	Solar	4	5	SolarRainbow	9000000 	816	99001	rbxassetid://123720993696670	rbxassetid://98616255072587
5005	Flame	5	5	FlameRainbow	60000000 	3060	99001	rbxassetid://95224550415811	rbxassetid://98616255072587
5006	Heart	6	5	HeartRainbow	250000000 	11220	99001	rbxassetid://127841276677202	rbxassetid://98616255072587
5007	Celestial	7	5	CelestialRainbow	1000000000 	33660	99001	rbxassetid://120738172280657	rbxassetid://98616255072587


策划文档V3.5 关于背包信息的修改（BackpackGui）

在背包中出现的盲盒，需要补充这个盲盒的品质信息
StarterGui - BackpackGui - BackpackFrame - ItemListFrame - ArmyTemplate - Rare是品质信息
当这个盲盒的品质是最低的1（common）时，不显示
当盲盒品质是其他的品质时，需要把Rare的文本内容改成品质名字，并显示出来



策划文档V3.6 更新手办表信息

id	手办名字	金币基础产速	品质	稀有度	模型资源	对应展台路径	对应领取按钮路径	手办icon
10001	Greyshade Sneak	1	1	1	Leaf/LBB01	ShowCase/Green/Position1	ButtonGreen/Button1	rbxassetid://106915271340222
10002	Starcharm Mechanic	2	1	1	Leaf/LBB02	ShowCase/Green/Position2	ButtonGreen/Button2	rbxassetid://105301091167285
10003	Minty Squint	3	1	1	Leaf/LBB03	ShowCase/Green/Position3	ButtonGreen/Button3	rbxassetid://92602393759769
10004	Pinecone Redtail	4	1	1	Leaf/LBB04	ShowCase/Green/Position4	ButtonGreen/Button4	rbxassetid://77465737689764
10005	Tiny Tiger Brave	5	1	1	Leaf/LBB05	ShowCase/Green/Position5	ButtonGreen/Button5	rbxassetid://128609371638881
10006	Bluefrost Cone	6	1	1	Leaf/LBB06	ShowCase/Green/Position6	ButtonGreen/Button6	rbxassetid://77006643082762
10007	Honeydoze	7	1	1	Leaf/LBB07	ShowCase/Green/Position7	ButtonGreen/Button7	rbxassetid://97576907938982
10008	Forest Basketling	8	1	1	Leaf/LBB08	ShowCase/Green/Position8	ButtonGreen/Button8	rbxassetid://100640430095892
10009	Berrybramble Bear	10	1	1	Leaf/LBB09	ShowCase/Green/Position9	ButtonGreen/Button9	rbxassetid://107958283001957
20001	Emerald Bonk	50	2	1	Water/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://73924471186576
20002	Rainbow Drizzle	56	2	1	Water/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://97475868474045
20003	Violet Giftling	63	2	1	Water/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://94121257331073
20004	Frogleaf	71	2	1	Water/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://80371625018349
20005	Rosehug	80	2	1	Water/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://131567376824995
20006	Snowpuff	90	2	1	Water/LBB06	ShowCase/Blue/Position6	ButtonBlue/Button6	rbxassetid://98646372357977
20007	Party Box Pop	102	2	1	Water/LBB07	ShowCase/Blue/Position7	ButtonBlue/Button7	rbxassetid://131567376824995
20008	Splashring	116	2	1	Water/LBB08	ShowCase/Blue/Position8	ButtonBlue/Button8	rbxassetid://120763170661369
20009	Seastar Chanter	132	2	1	Water/LBB09	ShowCase/Blue/Position9	ButtonBlue/Button9	rbxassetid://87646054592825
30001	Pajama Snoozer	220	3	1	Lunar/LBB01	ShowCase/Purple/Position1	ButtonPurple/Button1	rbxassetid://116214626452083
30002	Starseam Witchlet	250	3	1	Lunar/LBB02	ShowCase/Purple/Position2	ButtonPurple/Button2	rbxassetid://133690692800448
30003	Nightclaw	285	3	1	Lunar/LBB03	ShowCase/Purple/Position3	ButtonPurple/Button3	rbxassetid://77847158725505
30004	Halo Hymn	325	3	1	Lunar/LBB04	ShowCase/Purple/Position4	ButtonPurple/Button4	rbxassetid://100929113578714
30005	Specs Scholar	370	3	1	Lunar/LBB05	ShowCase/Purple/Position5	ButtonPurple/Button5	rbxassetid://77847158725505
30006	Wanderbow	420	3	1	Lunar/LBB06	ShowCase/Purple/Position6	ButtonPurple/Button6	rbxassetid://98084586375258
30007	Prismfeather Sprite	480	3	1	Lunar/LBB07	ShowCase/Purple/Position7	ButtonPurple/Button7	rbxassetid://81392569495246
30008	Greyshade Gentleman	550	3	1	Lunar/LBB08	ShowCase/Purple/Position8	ButtonPurple/Button8	rbxassetid://107529498094392
30009	Pumpkin Ghast	630	3	1	Lunar/LBB09	ShowCase/Purple/Position9	ButtonPurple/Button9	rbxassetid://107304908021027
40001	Sunblossom	950	4	1	Solar/LBB01	ShowCase/Orange/Position1	ButtonOrange/Button1	rbxassetid://123301796994352
40002	Flowercrown Bride	1080	4	1	Solar/LBB02	ShowCase/Orange/Position2	ButtonOrange/Button2	rbxassetid://135903948038055
40003	Twinbasket Harvest	1230	4	1	Solar/LBB03	ShowCase/Orange/Position3	ButtonOrange/Button3	rbxassetid://137010302356268
40004	Leafwing Dino	1400	4	1	Solar/LBB04	ShowCase/Orange/Position4	ButtonOrange/Button4	rbxassetid://133825497379267
40005	Broomlet Witch	1600	4	1	Solar/LBB05	ShowCase/Orange/Position5	ButtonOrange/Button5	rbxassetid://78728521411560
40006	Swinggiggle	1830	4	1	Solar/LBB06	ShowCase/Orange/Position6	ButtonOrange/Button6	rbxassetid://98165717690396
40007	Vinewreath Wisher	2100	4	1	Solar/LBB07	ShowCase/Orange/Position7	ButtonOrange/Button7	rbxassetid://133103323967935
40008	Lemon Pilot	2400	4	1	Solar/LBB08	ShowCase/Orange/Position8	ButtonOrange/Button8	rbxassetid://71595524788019
40009	Cosmo Drifter	2750	4	1	Solar/LBB09	ShowCase/Orange/Position9	ButtonOrange/Button9	rbxassetid://132021136924285
50001	Bombsnit	3000	5	1	Flame/LBB01	ShowCase/Red/Position1	ButtonRed/Button1	rbxassetid://81520307684372
50002	Flamecrown Blade	3400	5	1	Flame/LBB02	ShowCase/Red/Position2	ButtonRed/Button2	rbxassetid://90342220987736
50003	Blazefuzz King	3850	5	1	Flame/LBB03	ShowCase/Red/Position3	ButtonRed/Button3	rbxassetid://73676714004019
50004	Roseveil Count	4350	5	1	Flame/LBB04	ShowCase/Red/Position4	ButtonRed/Button4	rbxassetid://108104612245462
50005	Inferno Fanlord	4900	5	1	Flame/LBB05	ShowCase/Red/Position5	ButtonRed/Button5	rbxassetid://121911610580026
50006	Neon Skater	5550	5	1	Flame/LBB06	ShowCase/Red/Position6	ButtonRed/Button6	rbxassetid://107904367562204
50007	Crystal Seer	6300	5	1	Flame/LBB07	ShowCase/Red/Position7	ButtonRed/Button7	rbxassetid://98108287971614
60001	Snowroll Buddy	12000	6	1	Heart/LBB01	ShowCase/Yellow/Position1	ButtonYellow/Button1	rbxassetid://129520383058807
60002	Bubbleballerina	13200	6	1	Heart/LBB02	ShowCase/Yellow/Position2	ButtonYellow/Button2	rbxassetid://125879099426075
60003	Seamoon Siren	14600	6	1	Heart/LBB03	ShowCase/Yellow/Position3	ButtonYellow/Button3	rbxassetid://131333015213094
60004	Butterglow Fairy	16200	6	1	Heart/LBB04	ShowCase/Yellow/Position4	ButtonYellow/Button4	rbxassetid://136225094377885
60005	Nurse Nuzzle	18000	6	1	Heart/LBB05	ShowCase/Yellow/Position5	ButtonYellow/Button5	rbxassetid://112335648315899
60006	Redflag Climber	20000	6	1	Heart/LBB06	ShowCase/Yellow/Position6	ButtonYellow/Button6	rbxassetid://84929220767434
60007	Sakura Fest	22300	6	1	Heart/LBB07	ShowCase/Yellow/Position7	ButtonYellow/Button7	rbxassetid://136190154597023
70001	Starfloat	33000	7	1	Celestial/LBB01	ShowCase/Blue/Position1	ButtonBlue/Button1	rbxassetid://137355628441296
70002	Thunder Sprout	38000	7	1	Celestial/LBB02	ShowCase/Blue/Position2	ButtonBlue/Button2	rbxassetid://105553650967188
70003	Whitewing Prayer	44000	7	1	Celestial/LBB03	ShowCase/Blue/Position3	ButtonBlue/Button3	rbxassetid://83967828201151
70004	Balloon Cakeling	51000	7	1	Celestial/LBB04	ShowCase/Blue/Position4	ButtonBlue/Button4	rbxassetid://135305551396163
70005	Rainbow Unicorn Knight	59000	7	1	Celestial/LBB05	ShowCase/Blue/Position5	ButtonBlue/Button5	rbxassetid://78448815998112


策划文档V3.7 关于Index界面的一些修改

我们补充以下规则：

1.我们的每个手办的图标在界面中显示时，因为每个手办都有其对应的品质，所以我们需要在Index界面上显示出手办信息时，展示对应的品质
2.展示对应的品质的时候，有个逻辑是：
    a.StarterGui - Index - IndexBg - InfoBg - ScrollingFrame - FigurineTemplate下有多个图片，分别对应我们的每个品质
    b.比如Flame/Celestial/Heart/Leaf/Lunar/Solar/Water等，每个的Visible属性都是false
    c.当一个手办信息生成时，需要根据这个手办的品质，决定把哪个图片显示出来，比如leaf的品质，就把Leaf图片显示出来

策划文档V3.8 关于Bag界面的一些修改

我们补充以下规则：
1.跟上述的Index界面一样，我们也需要给每个盲盒显示对应的背景。
2.StarterGui - Bag - BagBg - ScrollingFrame - CapsuleTemplate下有多个图片，分别对应我们的每个品质
3.比如Flame/Celestial/Heart/Leaf/Lunar/Solar/Water等，每个的Visible属性都是false
4.当一个盲盒信息生成时，需要根据这个盲盒的品质，决定把哪个图片显示出来，比如leaf的品质，就把Leaf图片显示出来

原来是StarterGui - Bag - BagBg - ScrollingFrame - CapsuleTemplate - Name原来是显示盲盒名字，现在改成：显示稀有度名字，和backpack里面的逻辑是一样的，如果是common就不显示，其他的显示稀有度的名字

策划文档V3.9 关于抽卡动画效果的规则补充

1.展示动画第一步，需要把StarterGui - GachaResult - Result - Cover的图标改成这个盲盒对应的图标，同时像上述V3.7和V3.8部分的逻辑一样，在StarterGui - GachaResult - Result下也有各个品质的图，需要把品质图显示出来
2.展示动画第二步（转换信息的时候），需要同步更改Icon/Name/Rare/Speed相关的信息，这些我都设定成了Visible默认False，展示出来时要改成True
3.同时LevelUp界面也是的，下面也有各个品质的图片，显示出来时，要把对应的品质的名字的图片显示出来
