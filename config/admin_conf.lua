local md5 =	require	"md5"
local this = {}

-- 超级密钥，全功能
this[md5.sumhexa("ss0")] = {"charge", "ctrl_gate", "gate_status", "add_gold", 
								"sub_gold", "add_money", "sub_money", "add_hongbao", "sub_hongbao", "get_user", "set_win",
								"set_ctrl_user", "del_ctrl_user", "get_ctrl_user", 
							}

-- 给php充值用的密钥
this[md5.sumhexa("-0)9nd8@03ncsl0")] = {"charge"}

-- 给后台查询用用户信息用
this[md5.sumhexa("2dn#(_&dl9*cn.wk")] = {"get_user"}


return this