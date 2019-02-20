--[[
	麻将基础规则配置表
]]

local table = {}

table[10001] = {
	shifter = 0, 					--癞子牌(鬼牌) 0无 1翻鬼 2双鬼 其他填写牌的编号 如：白板 55
	peng = 1,						--是否可以碰 1是 0否
	gang = 1,						--是否可以杠 1是 0否
	chi = 1,						--吃
	dian = 1,						--点炮
	win_own = 2,					--自摸倍率
	win_other = 3,  				--点炮倍率
	ming_gang = 2,					--明杠倍率
	an_gang =1,						--暗杠倍率
	peng_gang = 2, 					--碰杠倍率
	qiangganghu = 1,				--抢杠胡
	qiangminggang = 1,				--抢明杠
	qianggangquanbao = 0,			--抢杠全包
	gangbaoquanbao = 0,				--杠爆全包
	wuguijiabei = 0,				--无鬼加倍
	fengpai = 1, 					--风（东西南北中发白）
	gengzhuang = 1,					--更庄
	jiejiegao = 0, 					--节节高
	horse = 0,   					--2 4 6 8表示抓马个数 21加分爆炸吗 22翻倍爆炸马
	base_horse = 0,					--是否马跟底分 1是
}

table[11001] = {
	shifter = 0, 					--癞子牌(鬼牌) 0无 1翻鬼 2双鬼 其他填写牌的编号 如：白板 55
	peng = 1,						--是否可以碰 1是 0否
	gang = 1,						--是否可以杠 1是 0否
	chi = 1,						--吃
	dian = 1,						--点炮
	win_own = 2,					--自摸倍率
	win_other = 3,  				--点炮倍率
	ming_gang = 2,					--明杠倍率
	an_gang =1,						--暗杠倍率
	peng_gang = 2, 					--碰杠倍率
	qiangganghu = 1,				--抢杠胡
	qiangminggang = 1,				--抢明杠
	qianggangquanbao = 0,			--抢杠全包
	gangbaoquanbao = 0,				--杠爆全包
	wuguijiabei = 0,				--无鬼加倍
	fengpai = 1, 					--风（东西南北中发白）
	gengzhuang = 1,					--更庄
	jiejiegao = 0, 					--节节高
	horse = 0,   					--2 4 6 8表示抓马个数 21加分爆炸吗 22翻倍爆炸马
	base_horse = 0,					--是否马跟底分 1是
}

return table