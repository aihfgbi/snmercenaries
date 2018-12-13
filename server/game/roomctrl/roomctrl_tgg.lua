local this = {}
local send_to_all
local gameid=10008


local function SendMessage(msg)
	--LOG_WARNING("发送给所有玩家")
	send_to_all("ReceiveMessage",msg,gameid)
end

function this.update()

end

function this.init(t,api,ps,ftable,ttable)
	send_to_all=api.call_all_table
	players=ps
end

function this.ReceiveMessage(uid,status,gold)   
	
end

return this