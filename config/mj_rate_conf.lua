--[[
	麻将倍率配置表
]]

local table = {}

table[1001] = {
	pinghu = 0,     		--平胡
	qingyise = 2, 			--清一色
	qidui = 2, 				--七对
	qingqidui = 2, 			--清七对
	pengpenghu = 2, 		--碰碰胡
	hunyise = 2, 			--混一色
	hunduidui = 2,			--混对对
	longqidui = 6, 			--龙七对
	tianhu = 10, 			--天胡
	dihu = 10, 				--地胡
	shisanyao = 10, 		--十三幺
	ziyise = 2, 			--字一色
	shibaluohan = 10, 		--十八罗汉
	gangshangkaihua = 2,    --刚上开花
	wuguijiabei = 2, 		--无鬼加倍
}

table[1101] = {
	pinghu = 0,     		--平胡
	qingyise = 2, 			--清一色
	qidui = 2, 				--七对
	qingqidui = 2, 			--清七对
	pengpenghu = 2, 		--碰碰胡
	hunyise = 2, 			--混一色
	hunduidui = 2,			--混对对
	longqidui = 3, 			--龙七对
	tianhu = 3, 			--天胡
	dihu = 3, 				--地胡
	shisanyao = 4, 		--十三幺
	ziyise = 2, 			--字一色
	shibaluohan = 5, 		--十八罗汉
	gangshangkaihua = 2,    --刚上开花
	wuguijiabei = 0, 		--无鬼加倍
}

return table