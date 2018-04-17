#!/bin/bash
#
# Author: superz
# Date: 2015-11-12
# Description: zookeeper集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# zookeeper镜像
ZK_MIRROR=http://mirror.bit.edu.cn/apache/zookeeper
ZK_NAME=zookeeper-$ZK_VERSION
# zookeeper安装包名
ZK_PKG=${ZK_NAME}.tar.gz
# zookeeper安装包下载地址
ZK_URL=$ZK_MIRROR/$ZK_NAME/$ZK_PKG

# zookeeper集群配置信息
# ip hostname admin_user admin_passwd owner_passwd myid
HOSTS="10.10.20.104 yygz-104.tjinserv.com root 7oGTb2P3nPQKHWw1ZG zookeeper123 1
10.10.20.110 yygz-110.tjinserv.com root 7oGTb2P3nPQKHWw1ZG zookeeper123 2
10.10.20.111 yygz-111.tjinserv.com root 7oGTb2P3nPQKHWw1ZG zookeeper123 3"
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
HOSTS="192.168.1.227 hdpc1-sn001 root 123456 123456 1
192.168.1.229 hdpc1-sn002 root 123456 123456 2
192.168.1.230 hdpc1-sn003 root 123456 123456 3"
fi

# 当前用户名，所属组
THE_USER=$ZK_USER
THE_GROUP=$ZK_GROUP

# 用户zookeeper配置文件目录
CONF_DIR=$CONF_DIR/zookeeper


# 创建zookeeper相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建zookeeper数据文件目录
            mkdir -p $ZK_DATA_DIR
            chown -R ${ZK_USER}:${ZK_GROUP} $ZK_DATA_DIR

            # 生成myid
            su -l $ZK_USER -c "echo $myid > $ZK_DATA_DIR/myid"

            # 创建zookeeper日志文件目录
            if [[ -n "$ZK_LOG_DIR" ]]; then
                mkdir -p $ZK_LOG_DIR
                chown -R ${ZK_USER}:${ZK_GROUP} $ZK_LOG_DIR
            fi
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $ZK_DATA_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${ZK_USER}:${ZK_GROUP} $ZK_DATA_DIR"

            autossh "$owner_passwd" ${ZK_USER}@${ip} "echo $myid > $ZK_DATA_DIR/myid"

            if [[ -n "$ZK_LOG_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $ZK_LOG_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${ZK_USER}:${ZK_GROUP} $ZK_LOG_DIR"
            fi
        fi
    done
}

# 设置zookeeper环境变量
function set_env()
{
    debug "Set zookeeper environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set zookeeper environment variables at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# zookeeper config start/,/^# zookeeper config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # zookeeper config start' /etc/profile
            sed -i "$ a export ZK_HOME=$ZK_HOME" /etc/profile
            sed -i "$ a export ZOOCFGDIR=$ZK_CONF_DIR" /etc/profile
            sed -i "$ a export ZOO_LOG_DIR=$ZK_LOG_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$ZK_HOME/bin" /etc/profile
            sed -i '$ a # zookeeper config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# zookeeper config start/,/^# zookeeper config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # zookeeper config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export ZK_HOME=$ZK_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export ZOOCFGDIR=$ZK_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export ZOO_LOG_DIR=$ZK_LOG_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$ZK_HOME/bin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # zookeeper config end' /etc/profile"
        fi
    done
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载zookeeper
    if [[ ! -f $ZK_PKG ]]; then
        debug "Download zookeeper from: $ZK_URL"
        wget $ZK_URL
    fi

    # 解压zookeeper安装包
    tar -zxf $ZK_PKG

    # 配置zookeeper
    cp -f $CONF_DIR/zoo.cfg $ZK_NAME/conf
    cp -f $CONF_DIR/log4j.properties $ZK_NAME/conf
    if [[ -n "$ZK_SERVER_HEAP" ]]; then
        sed -i "/\$SERVER_JVMFLAGS/{x;/^$/s/^/SERVER_JVMFLAGS=\"${ZK_SERVER_HEAP}\"/p;x}" $ZK_NAME/bin/zkServer.sh
    fi
    if [[ -n "$ZK_CLIENT_HEAP" ]]; then
        sed -i "/\$JAVA/ i\CLIENT_JVMFLAGS=\"${ZK_CLIENT_HEAP}\"\n" $ZK_NAME/bin/zkCli.sh
    fi
    if [[ -n "$ZOO_LOG4J_PROP" ]]; then
        sed -i "s/^\([ ]*ZOO_LOG4J_PROP=\).*/\1$\"{ZOO_LOG4J_PROP}\"/" $ZK_NAME/bin/zkEnv.sh
    fi

    # 压缩配置好的zookeeper
    mv -f $ZK_PKG ${ZK_PKG}.o
    tar -zcf $ZK_PKG $ZK_NAME

    # 安装zookeeper
    debug "Install zookeeper"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        debug "Install zookeeper at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建zookeeper安装目录
            mkdir -p $ZK_INSTALL_DIR

            # 安装zookeeper
            rm -rf $ZK_INSTALL_DIR/$ZK_NAME
            mv -f $ZK_NAME $ZK_INSTALL_DIR
            chown -R ${ZK_USER}:${ZK_GROUP} $ZK_INSTALL_DIR
            if [[ `basename $ZK_HOME` != $ZK_NAME ]]; then
                su -l $ZK_USER -c "ln -snf $ZK_INSTALL_DIR/$ZK_NAME $ZK_HOME"
            fi

            # 配置文件
            if [[ $ZK_CONF_DIR != $ZK_HOME/conf ]]; then
                mkdir -p $ZK_CONF_DIR
                mv -f $ZK_HOME/conf/* $ZK_CONF_DIR
                chown -R ${ZK_USER}:${ZK_GROUP} $ZK_CONF_DIR
            fi
        else
            autoscp "$admin_passwd" $ZK_PKG ${admin_user}@${ip}:~/$ZK_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $ZK_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $ZK_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $ZK_INSTALL_DIR/$ZK_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $ZK_NAME $ZK_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${ZK_USER}:${ZK_GROUP} $ZK_INSTALL_DIR"
            if [[ `basename $ZK_HOME` != $ZK_NAME ]]; then
                autossh "$owner_passwd" ${ZK_USER}@${ip} "ln -snf $ZK_INSTALL_DIR/$ZK_NAME $ZK_HOME"
            fi

            if [[ $ZK_CONF_DIR != $ZK_HOME/conf ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $ZK_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $ZK_HOME/conf/* $ZK_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${ZK_USER}:${ZK_GROUP} $ZK_CONF_DIR"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $ZK_NAME

    # 创建zookeeper相关目录
    create_dir

    # 设置zookeeper环境变量
    set_env
}

# 启动zookeeper集群
function start()
{
    debug "Start zookeeper cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        debug "Start zookeeper at host: $ip"
        autossh "$owner_passwd" ${ZK_USER}@${ip} "$ZK_HOME/bin/zkServer.sh start"
    done
}

# 停止zookeeper集群
function stop()
{
    debug "Stop zookeeper cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        debug "Stop zookeeper at host: $ip"
        autossh "$owner_passwd" ${ZK_USER}@${ip} "test -f $ZK_HOME/bin/zkServer.sh && $ZK_HOME/bin/zkServer.sh stop"
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-c create user<add/delete>] [-h config host<hostname,hosts>] [-i install] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E QuorumPeerMain | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $ZK_HOME $ZK_CONF_DIR $ZK_DATA_DIR $ZK_LOG_DIR /tmp/hsperfdata_$ZK_USER /tmp/Jetty_*"
    done
}

# 管理
function admin()
{
    # zookeeper配置信息
    echo conf | nc hdpc1-sn001 2181

    # 客户端连接详细信息
    echo cons | nc hdpc1-sn001 2181

    # 列出所有watcher信息
    echo wchc | nc hdpc1-sn001 2181

    # 查看启动参数
    zkServer.sh print-cmd

    # 前台启动
    zkServer.sh start-foreground

    # 执行zookeeper命令
    echo "ls /" zkCli.sh

    # 查看日志
    java -cp $ZK_HOME/${ZK_NAME}.jar:$ZK_HOME/lib/slf4j-api-1.6.1.jar org.apache.zookeeper.server.LogFormatter log/version-2/log.100000001
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -c [add/delete] 创建用户
    # -h [hostname,hosts] 配置host
    # -i 安装集群
    # -s [init/start/stop/restart] 启动/停止集群
    # -v debug模式
    while getopts "c:h:is:v" name; do
        case "$name" in
            c)
                local command="$OPTARG"
                if [[ "$command" = "delete" ]]; then
                    delete_flag=1
                fi
                create_flag=1;;
            h)
                local $command="$OPTARG"
                if [[ "$command" = "hostname" ]]; then
                    hostname_flag=1
                fi
                hosts_flag=1;;
            i)
                install_flag=1;;
            s)
                start_cmd="$OPTARG";;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 安装环境
    install_env

    # 删除用户
    [[ $delete_flag ]] && log_fn delete_user
    # 创建用户
    [[ $create_flag ]] && log_fn create_user

    # 配置host
    [[ $hostname_flag ]] && log_fn modify_hostname
    [[ $hosts_flag ]] && log_fn add_host

    # 安装集群
    [[ $install_flag ]] && log_fn install

    # 启动集群
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"