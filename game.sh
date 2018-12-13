#!/bin/bash
export REDIS_ADDR="192.168.3.32"
export REDIS_PORT=8380
export REDIS_PASS="K5Ad^V1a@F23j5d!m4zj"
export LOG_REDIS_ADDR="192.168.3.32"
export LOG_REDIS_PORT=8379
export LOG_REDIS_PASS="K5Ad^V1a@F23j5d!m4zj"
export DBS_COUNT=1
export GAME_COUNT=1
export GOLDGAME_COUNT=1
export LOG_NAME="loglist"
export MYSQL_HOST="192.168.1.9"
export MYSQL_PORT=5306
export MYSQL_DB="accountsdb"
export MYSQL_USER="server_v1"
export MYSQL_PWD="Xzy123China123"

SKYNET_PATH="../../skynet/skynet"
serviceArray=(
"httpgate;0;etc/config.httpgate;0.0.0.0;8903"
"game;0;etc/config.game"
"goldgame;0;etc/config.goldgame"
"dbs;1;etc/config.userdata"
"robot;0;etc/config.robot"
)
### node_name;config_path;ip;port;max_client
### 名字;配置路径;监听地址;监听端口;最大连接数

startAct()
{
	echo -e "\033[32m start process. \033[0m"
	if [ ! -d ./pid ]; then
		mkdir -p ./pid
	fi
	clearLog
	num=${#serviceArray[*]}
	for((i=0;i<$num;i++))
	do
		startPro ${serviceArray[$i]}
	done
	echo -e "\033[32m Start Skynet SUCCESS.\033[0m"
	
}

startPro()
{
	NUM=`echo $1 | awk -F ";" '{print NF}'`
	export NODE_NAME=`echo $1 | awk -F ";" '{print $1}'`
	export NODE_INDEX=`echo $1 | awk -F ";" '{print $2}'`
	export CONFIG_PATH=`echo $1 | awk -F ";" '{print $3}'`
	if [ $NUM -ge 4 ];then
		export IP_ADDR=`echo $1 | awk -F ";" '{print $4}'`
	fi
	if [ $NUM -ge 5 ];then
		export PORT=`echo $1 | awk -F ";" '{print $5}'`
	fi
	if [ $NUM -ge 6 ];then
		export MAX_CLIENT=`echo $1 | awk -F ";" '{print $6}'`
	fi
	echo -e "\033[32m start $NODE_NAME ... \033[0m"
	$SKYNET_PATH $CONFIG_PATH
        sleep 0.5
}

stopAct()
{
	echo -e "\033[33m stop process...  \033[0m"
	echo -e "\033[33m kill skynet... \033[0m"
	run_pid=`ps aux  | grep  skynet | grep config | awk '{printf $2" "}'`
	echo -e "\033[33m $run_pid \033[0m"
	for i in $run_pid
	do
   		kill -9 $i
	done
	echo -e "\033[33m Shutting down skynet SUCCESS! \033[0m"
	echo 
	sleep 0.5
}

clearLog()
{
	echo -e "\033[32m clear log... \033[0m"
	if [ ! -d ./log_temp ]; then
		mkdir -p ./log_temp
	fi
	mv ./log/* ./log_temp/
	sleep 0.5
}

case "$1" in
    start)
        startAct
        ;;
    stop)
        stopAct
        ;;
   restart)
	stopAct
	startAct
        ;;
  *)
  	stopAct
	startAct
	;;
esac
