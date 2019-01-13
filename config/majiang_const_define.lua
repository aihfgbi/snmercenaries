
-- DEF = {
-- 	-- 胡牌类型
-- 	HU_PINGHU 			= 1,
-- 	HU_DADUIZI          = 2,
-- 	HU_QINYISE 			= 3,
	
-- 	HU_QIDUI 			= 4,
-- 	HU_QINDUI 			= 5,
-- 	HU_QINQIDUI 		= 6,

-- 	-- 胡牌番数
-- 	HU_PINGHU_FAN 		= 1,
-- 	HU_DADUIZI_FAN		= 2,
-- 	HU_QINYISE_FAN		= 2,
-- 	HU_QIDUI_FAN 		= 1,
-- 	HU_QINDUI_FAN 		= 4,
-- 	HU_QINQIDUI_FAN 	= 2,

-- 	MJ_HU 				= 1,
-- 	MJ_CT_GANG    		= 2,
-- 	MJ_CT_KEZI    		= 3,
-- 	MJ_CT_DUIZI   		= 4,
-- 	MJ_CT_SHUN    		= 5,
-- }

HU_TYPE = {
	PINGHU 			= 1,		--平胡
	QINGYISE 		= 2,		--清一色
	PENGPENGHU		= 3,		--碰碰胡
	QIDUI 			= 4,		--七对
	QINGQIDUI		= 5,		--清七对
	HUNYISE 		= 6,		--混一色
	HUNDUIDUI 		= 7,		--混对对
	LONGQIDUI		= 8,		--龙七对
	TIANHU			= 9,		--天湖
	DIHU			= 10,		--地胡
	SHISANYAO 		= 11,		--十三幺
	ZIYIYE 			= 12,		--字一色
	SHIBALUOHAN		= 13,		--十八罗汉
	WUGUIJIABEI 	= 14, 		--无鬼加倍
}

--状态
MJ_STATUS = {
	WAITING_START = 1, 			--等待开始
	BEFORE_START = 2, 			--正式开始前
	AFTER_START = 3,			--发牌结束
	PLAYER_OPT = 4,				--摸牌
	WAITING_PLAYER = 5,			--等待玩家出牌
	CHECK_CLAIM = 6,			--检查当前牌有无人吃碰杠，并对有这些需求的玩家进行排序
	WAITING_CLAIM = 7,			--是否有需要吃碰杠的玩家，有则进入8,无则进入4
	WAITING_CLAIM_PLAYER = 8,   --等待玩家的吃碰杠操作，若过则进入7,若有操作则进入5
	GAME_END = 9,  				--一局游戏结束
	GAME_REST_WAITING = 10,
	GAME_REST = 11,
	GAME_STOP = 12, 			--整局游戏结束 进行结算
	CHECK_QIANGGANG = 13,		--抢杠
--	GAME_OVER = 13,
	MAX_STATUS = 13
}

--牌位置
TILE_AREA = {
	HAND = 1,    --在手中
	HOLD = 2,    --吃 杠 碰之后的牌
	DISCARD = 3, --打出去
}

--玩家操作类型
OPT_TYPE = {
	DISCARD = 1, 				--出牌
	DRAW = 2,					--摸牌
	CHI = 3,					--吃
	PENG = 4, 					--碰
	LIGHT_GANG = 5, 			--明杠
	BLACK_GANG = 6,				--暗杠
	PENG_GANG = 7, 				--碰杠
	WIN = 8, 					--赢
	QIANG_GANG_WIN = 9, 		--抢杠胡
	PASS = 10,					--过
	DRAW_REVERSE = 11, 			--杠后补牌
}


TIME = {
	OPT_TIME = 20 * 100,			--玩家操作时间 (15秒)
	CLAIM_TIME = 20 * 100,					--等待吃、碰、杠、胡的时间
	START_TIME = 1*100,
	SETTLE_TIME = 10 * 100,		   --结算时间
}

--操作优先级
ORDER = {
	WIN = 3,
	PENG = 2,
	CHI = 1,
}

--赢的类型
WIN_TYPE = {
	OWN = 1,		--自摸
	OTHER = 2,      --点炮
	DISBAND = 3,    --解散
	GANG = 4,        --抢杠胡
	GANGSHANGKAIHUA = 5,		--杠上开花
	NOWINERS = 6    --流局
}

--十三幺牌型
SHI_SAN_YAO = {11, 19, 21, 29, 31, 39, 41, 43, 45, 47, 51, 53, 55}

--麻将牌
MJ_TILE = {
	wan  = {[11] = "1万",[12] = "2万",[13] = "3万",[14] = "4万",[15] = "5万",[16] = "6万",[17] = "7万",[18] = "8万",[19] = "9万"},
	tiao = {[21] = "1条",[22] = "2条",[23] = "3条",[24] = "4条",[25] = "5条",[26] = "6条",[27] = "7条",[28] = "8条",[29] = "9条"},
	tong = {[31] = "1筒",[32] = "2筒",[33] = "3筒",[34] = "4筒",[35] = "5筒",[36] = "6筒",[37] = "7筒",[38] = "8筒",[39] = "9筒"},
	feng = {[41] = "东风",[43] = "西风",[45] = "南风",[47] = "北风",[51] = "红中",[53] = "发财",[55] = "白板"}
}
