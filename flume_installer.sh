#!/bin/bash
#
# Author: superz
# Date: 2016-08-10
# Description: flume集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# flume镜像
FLUME_MIRROR=http://mirror.bit.edu.cn/apache/flume
FLUME_NAME=apache-flume-${FLUME_VERSION}-bin
# flume安装包名
FLUME_PKG=${FLUME_NAME}.tgz
# flume安装包下载地址
FLUME_URL=$FLUME_MIRROR/$FLUME_VERSION/$FLUME_PKG

# flume集群配置信息
# ip hostname admin_user admin_passwd owner_passwd
HOSTS="10.10.20.104 yygz-104.tjinserv.com root 7oGTb2P3nPQKHWw1ZG flume123
10.10.20.110 yygz-110.tjinserv.com root 7oGTb2P3nPQKHWw1ZG flume123
10.10.20.111 yygz-111.tjinserv.com root 7oGTb2P3nPQKHWw1ZG flume123"
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
HOSTS="192.168.1.227 hdpc1-sn001 root 123456 123456 0
192.168.1.229 hdpc1-sn002 root 123456 123456 1
192.168.1.230 hdpc1-sn003 root 123456 123456 2"
fi

# 当前用户名，所属组
THE_USER=$FLUME_USER
THE_GROUP=$FLUME_GROUP

# 用户flume配置文件目录
CONF_DIR=$CONF_DIR/flume


# 创建flume相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建flume日志文件目录
            if [[ -n "$FLUME_LOG_DIR" ]]; then
                mkdir -p $FLUME_LOG_DIR
                chown -R ${FLUME_USER}:${FLUME_GROUP} $FLUME_LOG_DIR
            fi
        else
            if [[ -n "$FLUME_LOG_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $FLUME_LOG_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${FLUME_USER}:${FLUME_GROUP} $FLUME_LOG_DIR"
            fi
        fi
    done
}

# 设置flume环境变量
function set_env()
{
    debug "Set flume environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set flume environment variables at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# flume config start/,/^# flume config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # flume config start' /etc/profile
            sed -i "$ a export FLUME_HOME=$FLUME_HOME" /etc/profile
            sed -i "$ a export FLUME_CONF_DIR=$FLUME_CONF_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$FLUME_HOME/bin" /etc/profile
            sed -i '$ a # flume config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${hostname} "sed -i '/^# flume config start/,/^# flume config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${hostname} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${hostname} "sed -i '$ a # flume config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${hostname} "sed -i \"$ a export FLUME_HOME=$FLUME_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${hostname} "sed -i \"$ a export FLUME_CONF_DIR=$FLUME_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${hostname} "sed -i \"$ a export PATH=\\\$PATH:\\\$FLUME_HOME/bin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${hostname} "sed -i '$ a # flume config end' /etc/profile"
        fi
    done
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载flume
    if [[ ! -f $FLUME_PKG ]]; then
        debug "Download flume from: $FLUME_URL"
        wget $FLUME_URL
    fi

    # 解压flume安装包
    tar -zxf $FLUME_PKG

    # 配置flume
    cp -f $FLUME_HOME/conf/flume-env.sh.template $FLUME_HOME/conf/flume-env.sh
    # log4j

    # 压缩配置好的flume
    mv -f $FLUME_PKG ${FLUME_PKG}.o
    tar -zcf $FLUME_PKG $FLUME_NAME

    # 安装flume
    debug "Install flume"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Install flume at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建flume安装目录
            mkdir -p $FLUME_INSTALL_DIR

            # 安装flume
            rm -rf $FLUME_INSTALL_DIR/$FLUME_NAME
            mv -f $FLUME_NAME $FLUME_INSTALL_DIR
            chown -R ${FLUME_USER}:${FLUME_GROUP} $FLUME_INSTALL_DIR
            if [[ `basename $FLUME_HOME` != $FLUME_NAME ]]; then
                su -l $FLUME_USER -c "ln -snf $FLUME_INSTALL_DIR/$FLUME_NAME $FLUME_HOME"
            fi
        else
            autoscp "$admin_passwd" $FLUME_PKG ${admin_user}@${ip}:~/$FLUME_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $FLUME_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $FLUME_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $FLUME_INSTALL_DIR/$FLUME_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $FLUME_NAME $FLUME_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${FLUME_USER}:${FLUME_GROUP} $FLUME_INSTALL_DIR"
            if [[ `basename $FLUME_HOME` != $FLUME_NAME ]]; then
                autossh "$owner_passwd" ${FLUME_USER}@${ip} "ln -snf $FLUME_INSTALL_DIR/$FLUME_NAME $FLUME_HOME"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $FLUME_NAME

    # 创建flume相关目录
    create_dir

    # 设置flume环境变量
    set_env
}

# 启动flume集群
function start()
{
    todo_fn
}

# 停止flume集群
function stop()
{
    todo_fn
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
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $FLUME_HOME $FLUME_LOG_DIR /tmp/hsperfdata_$FLUME_USER"
    done
}

# 管理
function admin()
{
    $FLUME_HOME/bin/flume-ng -version
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