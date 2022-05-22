#!/bin/bash

create() {
    #Task 3: 创建判断是否创建网桥
    #$1容器名
    if ! [ -a "$CONFIG" ]; then
        touch $CONFIG
        chmod -R 777 $CONFIG
        echo "BRIDGE_NAME=$BRIDGE_NAME" >> $CONFIG
        echo "BRIDGE_IP=$BRIDGE_IP" >> $CONFIG
        echo "NET_INTER=$NET_INTER" >> $CONFIG
        echo "CONTAINER_IP_RANGE=$CONTAINER_IP_RANGE" >> $CONFIG
        echo "CONTAINER_IP=$CONTAINER_IP" >> $CONFIG
        netinit $BRIDGE_NAME $BRIDGE_IP
    else
        CONTAINER_IP=`sed '/^CONTAINER_IP=/!d;s/.*=//' $CONFIG`
        let i=${CONTAINER_IP#*.*.*.}
        i=$((i+1))
        CONTAINER_IP=${CONTAINER_IP%.*}.$i
        echo $CONTAINER_IP
        sed -i '/CONTAINER_IP=/d' $CONFIG
        echo "CONTAINER_IP=$CONTAINER_IP" >> $CONFIG
        #BRIDGE_IP=`sed '/^BRIDGE_IP=/!d;s/.*=//' $CONFIG`
        #echo "BRIDGE_NAME: $BRIDGE_NAME"
        #echo "BRIDGE_IP: $BRIDGE_IP"
        #netadd
    fi
    # TODO: Task 2
    echo TODO
}

limit_cpu() {
    if ! [ -d "/sys/fs/cgroup/cpu/$1" ]
    then
        mkdir "/sys/fs/cgroup/cpu/$1"
    fi

    echo 100000 >>"/sys/fs/cgroup/cpu/$1/cpu.cfs_period_us"

    limit=`echo $2 | awk '{print int($0 * 100000);}'`
    echo $limit >>"/sys/fs/cgroup/cpu/$1/cpu.cfs_quota_us"

    if [ -f "./proc/$1" ]
    then
        pid=`cat "./proc/$1"`
        echo $pid >>"/sys/fs/cgroup/cpu/$1/tasks"
    fi
}

limit_memory() {
    if ! [ -d "/sys/fs/cgroup/memory/$1" ]
    then
        mkdir "/sys/fs/cgroup/memory/$1"
    fi

    echo $2 >>"/sys/fs/cgroup/memory/$1/memory.limit_in_bytes"

    if [ -f "./proc/$1" ]
    then
        pid=`cat "./proc/$1"`
        echo $pid >>"/sys/fs/cgroup/memory/$1/tasks"
    fi
}

ps_() {
    # TODO: Task 2
    echo TODO
}

remove() {
    # TODO: Task 2
    echo TODO
}

run() {
    #$1 container name
    echo $$ >./proc/$1

    if ! [ -d "/sys/fs/cgroup/memory/$1" ]
    then
        mkdir "/sys/fs/cgroup/memory/$1"
    fi

    echo $$ >>"/sys/fs/cgroup/memory/$1/tasks"

    if ! [ -d "/sys/fs/cgroup/cpu/$1" ]
    then
        mkdir "/sys/fs/cgroup/cpu/$1"
    fi

    echo $$ >>"/sys/fs/cgroup/cpu/$1/tasks"

    #Task 3 创建命名空间，虚拟网卡挂载网桥，分配IP，开启nat
    sudo ip netns add $1
    sudo ip link add $10 type veth peer name $11
    sudo ip link set $11 netns $1
    sudo brctl addif $BRIDGE_NAME $10
    sudo ip link set $10 up
    sudo ip netns exec $1 ifconfig $11 $CONTAINER_IP up
    sudo ip netns exec $1 route add default dev $11
    
    unshare --pid --mount-proc --ipc --uts --mount --net --user --map-root-user --root ./mnt/$1 --fork /bin/sh

    sudo ip netns del $1
    sudo brctl delif $BRIDGE_NAME $10
    sudo ip link delete $10
    

    unlink ./proc/$1
}

netinit() {
    sudo brctl addbr $1
    sudo ifconfig $1 $2
    sudo ifconfig $1 up
    sudo route add default dev $NET_INTER
    sudo route add -net $CONTAINER_IP_RANGE dev $1
    #sudo brctl addif $1 $NET_INTER
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -t nat -A POSTROUTING -s $CONTAINER_IP_RANGE ! -o $BRIDGE_NAME -j MASQUERADE
    #sudo route add default dev $NET_INTER
}

usage() {
    echo 'Usage:'
    echo './mydocker.sh container create <container_name> <image_name>'
    echo './mydocker.sh container remove <container_name>'
    echo './mydocker.sh run <container_name>'
    echo './mydocker.sh ps'
    echo './mydocker.sh limit memory <container_name> <limit>'
    echo './mydocker.sh limit cpu <container_name> <limit>"'
}

flag=0
CONFIG=./config.txt
BRIDGE_NAME=mydocker
BRIDGE_IP=192.168.11.1
NET_INTER=ens33
CONTAINER_IP_RANGE=192.168.11.0/24
CONTAINER_IP=192.168.11.2


if [ ! $1 ]
then
    usage
    exit
fi

if [ $1 = 'container' ]
then
    if [ ! $2 ]
    then
        usage
        exit
    fi

    if [ $2 = 'create' ]
    then
        if [ ! $3 ] || [ ! $4 ] || [ $5 ]
        then
            usage
            exit
        fi

        flag=1
    elif [ $2 = 'remove' ]
    then
        if [ ! $3 ] || [ $4 ]
        then
            usage
            exit
        fi

        flag=2
    else
        usage
        exit
    fi
elif [ $1 = 'limit' ]
then
    if [ ! $2 ]
    then
        usage
        exit
    fi

    if [ $2 = 'memory' ]
    then
        if [ ! $3 ] || [ ! $4 ] || [ $5 ]
        then
            usage
            exit
        fi

        flag=5
    elif [ $2 = 'cpu' ]
    then
        if [ ! $3 ] || [ ! $4 ] || [ $5 ]
        then
            usage
            exit
        fi

        flag=6
    else
        usage
        exit
    fi
elif [ $1 = 'run' ]
then
    if [ ! $2 ] || [ $3 ]
    then
        usage
        exit
    fi

    flag=3
elif [ $1 = 'ps' ]
then
    if [ $2 ]
    then
        usage
        exit
    fi

    flag=4
else
    usage
    exit
fi

if [ $flag = 1 ]
then             # $3-容器名 $4-镜像名
    if ! [ -d './images' ] || ! [ -d './layer' ]
    then
        echo 'Opendir error!'
        exit
    fi

    if ! [ -d "./images/$4" ]
    then
        echo "Image '$4' does not exist!"
        exit
    fi

    if [ -d "./layer/$3" ]
    then
        echo "Container '$3' already exists!"
        exit
    fi

    # 执行任务2
    create $3 $4
    #debug
    run $3

elif [ $flag = 2 ]
then              # $3-容器名
    if ! [ -d './layer' ]
    then
        echo 'Opendir error!'
        exit
    fi

    if ! [ -d "./layer/$3" ]
    then
        echo "Container '$3' does not exist!"
        exit
    fi

    # 执行任务2
    remove $3

elif [ $flag = 3 ]
then             # $2-容器名
    if ! [ -d './layer' ] || ! [ -d './proc' ]
    then
        echo 'Opendir error!'
        exit
    fi

    if ! [ -d "./layer/$2" ]
    then
        echo "Container '$2' does not exist!"
        exit
    fi

    if [ -f "./proc/$2" ]
    then
        echo "Container '$2' is already running!"
        exit
    fi

    # 执行任务4
    run $2
elif [ $flag = 4 ]
then
    # 执行任务4
    ps_
elif [ $flag = 5 ]
then             # $3-容器名，$4-限制
    if ! [ -d './layer' ]
    then
        echo 'Opendir error!'
        exit
    fi

    if ! [ -d "./layer/$3" ]
    then
        echo "Container '$3' does not exist!"
        exit
    fi

    # 执行任务4
    limit_memory $3 $4
elif [ $flag = 6 ]
then             # $3-容器名，$4-限制
    if ! [ -d './layer' ]
    then
        echo 'Opendir error!'
        exit
    fi

    if ! [ -d "./layer/$3" ]
    then
        echo "Container '$3' does not exist!"
        exit
    fi

    result=`echo $4 | awk '{if($0 > 0.0 && $0 <= 1.0) print "yes"; else print "no";}'`
    if [ $result = 'no' ]
    then
        echo "limit 范围在 (0.0,1.0]，请重新输入"
        exit
    fi

    # 执行任务4
    limit_cpu $3 $4
else
    usage
    exit
fi
