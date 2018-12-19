local CMD = {
	["hall.reqConnect"] = 10001, --请求连接,后端主动返回
	["10001"] = "hall.reqConnect",
    ["hall.resConnect"] = 20001, --请求连接
	["20001"] = "hall.resConnect",
	["hall.reqVerification"] = 10002, --请求验证
	["10002"] = "hall.reqVerification",
    ["hall.resVerification"] = 20002, --请求验证
	["20002"] = "hall.resVerification",
	["hall.reqLogin"] = 10003, --登陆
	["10003"] = "hall.reqLogin",
    ["hall.resLogin"] = 20003, --登陆返回
	["20003"] = "hall.resLogin",
    ["hall.reqRefreshInfo"] = 10004, --刷新用戶信息
	["10004"] = "hall.reqRefreshInfo",
    ["hall.resRefreshInfo"] = 20004, --用戶信息返回
	["20004"] = "hall.resRefreshInfo",
    ["hall.reqHeart"] = 10005, --心跳
	["10005"] = "hall.reqHeart",
    ["hall.resHeart"] = 20005, --心跳
	["20005"] = "hall.resHeart",
    ["hall.reqGameList"] = 10006, --游戏列表
	["10006"] = "hall.reqGameList",
    ["hall.resGameList"] = 20006, --游戏列表返回
	["20006"] = "hall.resGameList",
    ["hall.reqBankInfo"] = 10007, --请求银行数据
	["10007"] = "hall.reqBankInfo",
    ["hall.resBankInfo"] = 20007, --请求银行数据
	["20007"] = "hall.resBankInfo",
    ["hall.reqBankAccess"] = 10008, --存取
	["10008"] = "hall.reqBankAccess",
    ["hall.resBankAccess"] = 20008, --存取返回
	["20008"] = "hall.resBankAccess",
    ["hall.reqBankCodeChange"] = 10009, --修改银行密码
	["10009"] = "hall.reqBankCodeChange",
    ["hall.resBankCodeChange"] = 20009, --修改银行密码返回
	["20009"] = "hall.resBankCodeChange",
    ["hall.reqMailList"] = 10010, --请求邮件列表
	["10010"] = "hall.reqMailList",
    ["hall.resMailList"] = 20010, --请求邮件列表
	["20010"] = "hall.resMailList",
    ["hall.reqMailRead"] = 10011, --将邮件标为已读
	["10011"] = "hall.reqMailRead",
    ["hall.resMailRead"] = 20011, --将邮件标为已读
	["20011"] = "hall.resMailRead",
    ["hall.reqMailNew"] = 10012, --请求是否有新邮件
	["10012"] = "hall.reqMailNew",
    ["hall.resMailNew"] = 20012, --请求是否有新邮件，如果有新邮件会主动发送
	["20012"] = "hall.resMailNew",
	["hall.reqExchangeGold"] = 10013, --金币兑换
	["10013"] = "hall.reqExchangeGold",
    ["hall.resExchangeGold"] = 20013, --金币兑换返回
	["20013"] = "hall.resExchangeGold",

	["hall.reqCreateGame"] = 10014, --請求創建房間
	["10014"] = "hall.reqCreateGame",
	["hall.reqQuickJoinGame"] = 10015, --快速加入房间
	["10015"] = "hall.reqQuickJoinGame",
	["hall.resQuickJoinGame"] = 20015, --加入房间返回
	["20015"] = "hall.resQuickJoinGame",
}
return CMD