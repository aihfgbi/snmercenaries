local this = {}

-- 签到配置
this.sign_gold = {1000,1000,1000,3000,3000,5000,5000}

-- 胜利红包
this.winhongbao = {
-- cost表示消耗的胜利次数
-- award表示奖励的红包数额，根据weight来随机，根据earn内的值写random(earn[1],earn[2])
	[1001]={cost=5, award={{weight=80, earn={1,3}},{weight=20,earn={3,5}},{weight=10,earn={5,10}}}},
	[1002]={cost=20, award={{weight=80, earn={4,12}},{weight=20,earn={12,20}},{weight=10,earn={20,40}}}},
	[1003]={cost=50, award={{weight=80, earn={10,30}},{weight=20,earn={30,50}},{weight=10,earn={50,100}}}},
}

-- 绑定红包
this.bindhongbao = {10,100}

return this