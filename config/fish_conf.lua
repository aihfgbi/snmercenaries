local data = {}
data[1001]={type=1001,name="小飞鱼",group=10,gold=2,weight=2}
data[1002]={type=1002,name="鳕鱼",group=10,gold=3,weight=3}
data[1003]={type=1003,name="鲇鱼",group=10,gold=4,weight=4}
data[1004]={type=1004,name="蝴蝶鱼",group=10,gold=5,weight=5}
data[1005]={type=1005,name="尖嘴鱼",group=10,gold=6,weight=6}
data[1006]={type=1006,name="小丑鱼",group=10,gold=8,weight=8}
data[1007]={type=1007,name="狮子鱼",group=10,gold=10,weight=10}

data[1008]={type=1008,name="河豚",group=20,gold=12,weight=12}
data[1009]={type=1009,name="螃蟹",group=20,gold=15,weight=15}
data[1010]={type=1010,name="机械螃蟹",group=20,gold=18,weight=18}
data[1011]={type=1011,name="灯笼鱼",group=20,gold=20,weight=20}
data[1013]={type=1013,name="安康鱼",group=20,gold=40,weight=40,is_boss=false}
data[1021]={type=1021,name="绿海龟",group=20,gold=30,weight=30,is_boss=false}

data[1017]={type=1017,name="剑旗鱼",group=30,gold=90,weight=90,is_boss=false}
data[1015]={type=1015,name="海豚",group=30,gold=60,weight=60,is_boss=false}
data[1016]={type=1016,name="紫锤鲨",group=30,gold=80,weight=80,is_boss=false}
data[1014]={type=1014,name="金龙鱼",group=30,gold=70,weight=70,is_boss=false}


data[1019]={type=1019,name="国王蟹",group=40,gold=180,weight=180,is_boss=false}
data[1020]={type=1020,name="鲨鱼·杰克",group=40,gold=200,weight=200,is_boss=false}
data[1024]={type=1024,name="大鲨鱼",group=40,gold=150,weight=150,is_boss=false}
data[1025]={type=1025,name="锤头鲨",group=40,gold=160,weight=160,is_boss=false}
data[1018]={type=1018,name="独角鲸",group=40,gold=220,weight=220,is_boss=false}

data[1027]={type=1027,name="海盗船",group=60,gold=300,weight=300,is_boss=true}
data[1028]={type=1028,name="海将军",group=60,gold=400,weight=400,is_boss=true}
data[1029]={type=1029,name="美人鱼",group=60,gold=500,weight=500,is_boss=true}
data[1030]={type=1030,name="火焰龙",group=60,gold=600,weight=600,is_boss=true}

-- 2d捕鱼用的场景小BOSS
data[5001]={type=5001,name="史前巨鳄,",group=61,gold=300,weight=300,is_boss=true}
data[5002]={type=5002,name="暗夜炬兽,",group=61,gold=300,weight=300,is_boss=true}
data[5003]={type=5003,name="帝王蟹,",group=61,gold=300,weight=300,is_boss=true}
data[5004]={type=5004,name="金龙",group=61,gold=400,weight=400,is_boss=true}


data[3002]={type=3002,name="冰冻鱼",group=100,gold=0,weight=10, effects={"ice"}}
data[3003]={type=3003,name="核导弹",group=100,gold=0,weight=1, effects={"boom", "10","20","30","40","60"}}
data[3004]={type=3004,name="炸药桶",group=100,gold=0,weight=1, effects={"boom", "10","20","30"}}
data[3005]={type=3005,name="爆裂鱼",group=100,gold=0,weight=1, effects={"boom", "10","20"}}
data[3006]={type=3006,name="电磁蟹",group=100,gold=100,weight=100, effects={"jiguang", "10","20"}}
data[3007]={type=3007,name="钻头蟹",group=100,gold=100,weight=100, effects={"zuantou", "5", "10","20"}}
data[3008]={type=3008,name="炸弹蟹",group=100,gold=100,weight=100, effects={"boom", "10","20"}}

data[4001]={type=4001,name="孙悟空",group=4000,gold=10000,weight=5000,is_boss=false, effects={"boss", "1", "20"}}
data[4002]={type=4002,name="李逵",group=4000,gold=10000,weight=5000,is_boss=false, effects={"boss", "1", "20"}}
data[4003]={type=4003,name="加勒比海盗船",group=4000,gold=10000,weight=5000,is_boss=false, effects={"boss", "1", "20"}}
data[4004]={type=4004,name="大章鱼",group=4000,gold=10000,weight=10000,is_boss=false, effects={"zhangyu", 4, 8, 30}} --一次刷4条，一共8条，2分钟持续时间
-- data[4005]={type=4005,name="史前巨鳄",group=4000}

data[8001]={type=8001,name="抢庄财神",group=200,gold=20,weight=20,is_boss=false,effects={"master"}} 

return data