#!/bin/bash
#
# Author: superz
# Date: 2017-01-24
# Description: storm集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# storm镜像
STORM_MIRROR=http://mirror.bit.edu.cn/apache/storm
STORM_NAME=apache-storm-$STORM_VERSION
# storm安装包名
STORM_PKG=${STORM_NAME}.tar.gz
# storm安装包下载地址
STORM_URL=$STORM_MIRROR/$STORM_NAME/$STORM_PKG

# storm集群配置信息
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="10.10.20.99 yygz-99.tjinserv.com root 7oGTb2P3nPQKHWw1ZG storm123 nimbus
10.10.20.101 yygz-101.tjinserv.com root 7oGTb2P3nPQKHWw1ZG storm123 nimbus
10.10.20.104 yygz-104.tjinserv.com root 7oGTb2P3nPQKHWw1ZG storm123 supervisor
10.10.20.110 yygz-110.tjinserv.com root 7oGTb2P3nPQKHWw1ZG storm123 supervisor
10.10.20.111 yygz-111.tjinserv.com root 7oGTb2P3nPQKHWw1ZG storm123 supervisor"
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
HOSTS="192.168.1.227 hdpc1-dn001 root 123456 123456 nimbus,supervisor
192.168.1.229 hdpc1-dn002 root 123456 123456 nimbus,supervisor
192.168.1.230 hdpc1-dn003 root 123456 123456 supervisor"
fi

# 当前用户名，所属组
THE_USER=$STORM_USER
THE_GROUP=$STORM_GROUP

# 用户storm配置文件目录
CONF_DIR=$CONF_DIR/storm


# 创建storm相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建storm临时文件目录
            mkdir -p $STORM_TMP_DIR
            chown -R ${STORM_USER}:${STORM_GROUP} $STORM_TMP_DIR

            # 创建storm日志文件目录
            if [[ -n "$STORM_LOG_DIR" ]]; then
                mkdir -p $STORM_LOG_DIR
                chown -R ${STORM_USER}:${STORM_GROUP} $STORM_LOG_DIR
            fi
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $STORM_TMP_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${STORM_USER}:${STORM_GROUP} $STORM_TMP_DIR"

            if [[ -n "$STORM_LOG_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $STORM_LOG_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${STORM_USER}:${STORM_GROUP} $STORM_LOG_DIR"
            fi
        fi
    done
}

# 设置storm环境变量
function set_env()
{
    debug "Set storm environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set storm environment variables at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# storm config start/,/^# storm config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # storm config start' /etc/profile
            sed -i "$ a export STORM_HOME=$STORM_HOME" /etc/profile
            sed -i "$ a export STORM_CONF_DIR=$STORM_CONF_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$STORM_HOME/bin" /etc/profile
            sed -i '$ a # storm config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# storm config start/,/^# storm config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # storm config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export STORM_HOME=$STORM_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export STORM_CONF_DIR=$STORM_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$STORM_HOME/bin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # storm config end' /etc/profile"
        fi
    done
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载storm
    if [[ ! -f $STORM_PKG ]]; then
        debug "Download storm from: $STORM_URL"
        wget $STORM_URL
    fi

    # 解压storm安装包
    tar -zxf $STORM_PKG

    # 配置storm
    cp -f $CONF_DIR/storm.yaml $STORM_NAME/conf

    # 压缩配置好的storm
    mv -f $STORM_PKG ${STORM_PKG}.o
    tar -zcf $STORM_PKG $STORM_NAME

    # 安装storm
    debug "Install storm"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        debug "Install storm at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建storm安装目录
            mkdir -p $STORM_INSTALL_DIR

            # 安装storm
            rm -rf $STORM_INSTALL_DIR/$STORM_NAME
            mv -f $STORM_NAME $STORM_INSTALL_DIR
            chown -R ${STORM_USER}:${STORM_GROUP} $STORM_INSTALL_DIR
            if [[ `basename $STORM_HOME` != $STORM_NAME ]]; then
                su -l $STORM_USER -c "ln -snf $STORM_INSTALL_DIR/$STORM_NAME $STORM_HOME"
            fi

            # 配置文件
            if [[ $STORM_CONF_DIR != $STORM_HOME/conf ]]; then
                mkdir -p $STORM_CONF_DIR
                mv -f $STORM_HOME/conf/* $STORM_CONF_DIR
                chown -R ${STORM_USER}:${STORM_GROUP} $STORM_CONF_DIR
            fi
        else
            autoscp "$admin_passwd" $STORM_PKG ${admin_user}@${ip}:~/$STORM_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $STORM_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $STORM_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $STORM_INSTALL_DIR/$STORM_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $STORM_NAME $STORM_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${STORM_USER}:${STORM_GROUP} $STORM_INSTALL_DIR"
            if [[ `basename $STORM_HOME` != $STORM_NAME ]]; then
                autossh "$owner_passwd" ${STORM_USER}@${ip} "ln -snf $STORM_INSTALL_DIR/$STORM_NAME $STORM_HOME"
            fi

            if [[ $STORM_CONF_DIR != $STORM_HOME/conf ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $STORM_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $STORM_HOME/conf/* $STORM_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${STORM_USER}:${STORM_GROUP} $STORM_CONF_DIR"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $STORM_NAME

    # 创建storm相关目录
    create_dir

    # 设置storm环境变量
    set_env
}

# 启动storm集群
function start()
{
    echo "$HOSTS" | grep nimbus | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Start storm nimbus at host: $ip"
        autossh "$owner_passwd" ${STORM_USER}@${ip} "$STORM_HOME/bin/storm nimbus"

        debug "Start storm ui at host: $ip"
        autossh "$owner_passwd" ${STORM_USER}@${ip} "$STORM_HOME/bin/storm ui"
    done

    echo "$HOSTS" | grep supervisor | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Start storm supervisor at host: $ip"
        autossh "$owner_passwd" ${STORM_USER}@${ip} "$STORM_HOME/bin/storm supervisor"
    done
}

# 停止storm集群
function stop()
{
    echo "$HOSTS" | grep nimbus | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Stop storm nimbus at host: $ip"
        autossh "$owner_passwd" ${STORM_USER}@${ip} "ps aux | grep nimbus | grep -v grep | xargs -r kill -9"

        debug "Stop storm ui at host: $ip"
        autossh "$owner_passwd" ${STORM_USER}@${ip} "ps aux | grep storm.ui.core | grep -v grep | xargs -r kill -9"
    done

    echo "$HOSTS" | grep supervisor | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Stop storm supervisor at host: $ip"
        autossh "$owner_passwd" ${STORM_USER}@${ip} "ps aux | grep supervisor | grep -v grep | xargs -r kill -9"
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
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $STORM_HOME $STORM_CONF_DIR $STORM_TMP_DIR $STORM_LOG_DIR /tmp/hsperfdata_$STORM_USER /tmp/Jetty_*"
    done
}

# 管理
function admin()
{
    jps -l

    # hdpc1-dn001:6066

    # 默认配置
    # https://github.com/nathanmarz/storm/blob/master/conf/defaults.yaml
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