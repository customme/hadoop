#!/bin/bash
#
# Author: superz
# Date: 2015-12-07
# Description: hbase集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# hbase集群配置信息
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="10.10.10.61 yygz-61.gzserv.com root 123456 hbase123 hbase-master
10.10.10.64 yygz-64.gzserv.com root 123456 hbase123 hbase-master
10.10.10.65 yygz-65.gzserv.com root 123456 hbase123 regionserver,zookeeper
10.10.10.66 yygz-66.gzserv.com root 123456 hbase123 regionserver,zookeeper
10.10.10.67 yygz-67.gzserv.com root 123456 hbase123 regionserver,zookeeper"

# hbase安装包名
if [[ $HBASE_VERSION =~ ^0 ]]; then
    HBASE_NAME=hbase-${HBASE_VERSION}-hadoop2
elif [[ $HBASE_VERSION =~ ^[12] ]]; then
    HBASE_NAME=hbase-${HBASE_VERSION}
fi
HBASE_PKG=${HBASE_NAME}-bin.tar.gz
# hbase安装包下载地址
HBASE_URL=http://mirror.bit.edu.cn/apache/hbase/$HBASE_VERSION/$HBASE_PKG

# 相关目录
HBASE_PID_DIR=$HBASE_TMP_DIR

# 当前用户名，所属组
THE_USER=$HBASE_USER
THE_GROUP=$HBASE_GROUP


# 创建hbase相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建hbase临时文件目录
            if [[ -n "$HBASE_TMP_DIR" ]]; then
                mkdir -p $HBASE_TMP_DIR
                chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_TMP_DIR
            fi

            # 创建hbase日志文件目录
            if [[ -n "$HBASE_LOG_DIR" ]]; then
                mkdir -p $HBASE_LOG_DIR
                chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_LOG_DIR
            fi
        else
            if [[ -n "$HBASE_TMP_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HBASE_TMP_DIR;chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_TMP_DIR"
            fi

            if [[ -n "$HBASE_LOG_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HBASE_LOG_DIR;chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_LOG_DIR"
            fi
        fi
    done
}

# 设置hbase环境变量
function set_env()
{
    debug "Set hbase environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set hbase environment variables at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# hbase config start/,/^# hbase config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # hbase config start' /etc/profile
            sed -i "$ a export HBASE_HOME=$HBASE_HOME" /etc/profile
            sed -i "$ a export HBASE_CONF_DIR=$HBASE_CONF_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$HBASE_HOME/bin" /etc/profile
            sed -i '$ a # hbase config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hbase config start/,/^# hbase config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hbase config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HBASE_HOME=$HBASE_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HBASE_CONF_DIR=$HBASE_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$HBASE_HOME/bin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hbase config end' /etc/profile"
        fi
    done
}

# hbase 配置
function hbase_config()
{
    local zookeepers=`echo "$HOSTS" | awk '$6 ~ /zookeeper/ {printf("%s,",$2)}' | sed 's/,$//'`

    # Basic
    echo "
hbase.rootdir=hdfs://${NAMESERVICE_ID}$HBASE_ROOT_DIR
hbase.cluster.distributed=true
hbase.tmp.dir=$HBASE_TMP_DIR
hbase.master.port=60000
hbase.zookeeper.quorum=$zookeepers
"

    # Tuning
    echo "
hbase.regionserver.handler.count=30
hbase.region.replica.replication.enabled=true
"
}

# 配置hbase
function config_hbase()
{
    # 修改hbase-env.sh
    sed -i "s@.*\(export JAVA_HOME=\).*@\1${JAVA_HOME}@" $HBASE_NAME/conf/hbase-env.sh

    # jvm heap
    if [[ -n "$HBASE_REGIONSERVER_HEAP" ]]; then
        sed -i "/export HBASE_HEAPSIZE/ a export HBASE_REGIONSERVER_OPTS=\"\$HBASE_REGIONSERVER_OPTS ${HBASE_REGIONSERVER_HEAP}\"" $HBASE_NAME/conf/hbase-env.sh
    fi
    if [[ -n "$HBASE_MASTER_HEAP" ]]; then
        sed -i "/export HBASE_HEAPSIZE/ a export HBASE_MASTER_OPTS=\"\$HBASE_MASTER_OPTS ${HBASE_MASTER_HEAP}\"" $HBASE_NAME/conf/hbase-env.sh
    fi

    # jmx
    if [[ -n "$HBASE_MASTER_JMX_PORT" ]]; then
        sed -i 's/.*\(export HBASE_JMX_BASE=.*\)/\1/' $HBASE_NAME/conf/hbase-env.sh
        sed -i "s/.*\(export HBASE_MASTER_OPTS=.*jmxremote.port=\)[0-9]\+/\1${HBASE_MASTER_JMX_PORT}/" $HBASE_NAME/conf/hbase-env.sh
    fi
    if [[ -n "$HBASE_REGIONSERVER_JMX_PORT" ]]; then
        sed -i 's/.*\(export HBASE_JMX_BASE=.*\)/\1/' $HBASE_NAME/conf/hbase-env.sh
        sed -i "s/.*\(export HBASE_REGIONSERVER_OPTS=.*jmxremote.port=\)[0-9]\+/\1${HBASE_REGIONSERVER_JMX_PORT}/" $HBASE_NAME/conf/hbase-env.sh
    fi
    if [[ -n "$HBASE_THRIFT_JMX_PORT" ]]; then
        sed -i 's/.*\(export HBASE_JMX_BASE=.*\)/\1/' $HBASE_NAME/conf/hbase-env.sh
        sed -i "s/.*\(export HBASE_THRIFT_OPTS=.*jmxremote.port=\)[0-9]\+/\1${HBASE_THRIFT_JMX_PORT}/" $HBASE_NAME/conf/hbase-env.sh
    fi
    if [[ -n "$HBASE_REST_JMX_PORT" ]]; then
        sed -i 's/.*\(export HBASE_JMX_BASE=.*\)/\1/' $HBASE_NAME/conf/hbase-env.sh
        sed -i "s/.*\(export HBASE_REST_OPTS=.*jmxremote.port=\)[0-9]\+/\1${HBASE_REST_JMX_PORT}/" $HBASE_NAME/conf/hbase-env.sh
    fi

    # log/pid directory
    if [[ -n "$HBASE_LOG_DIR" ]]; then
        sed -i "s@.*\(export HBASE_LOG_DIR=\).*@\1${HBASE_LOG_DIR}@" $HBASE_NAME/conf/hbase-env.sh
    fi
    if [[ -n "$HBASE_PID_DIR" ]]; then
        sed -i "s@.*\(export HBASE_PID_DIR=\).*@\1${HBASE_PID_DIR}@" $HBASE_NAME/conf/hbase-env.sh
    fi

    # zookeeper
    sed -i 's/.*\(export HBASE_MANAGES_ZK=\).*/\1false/' $HBASE_NAME/conf/hbase-env.sh

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HBASE_NAME/conf/hbase-env.sh

    # 配置hbase-site.xml
    hbase_config | config_xml $HBASE_NAME/conf/hbase-site.xml

    # 添加regionservers
    echo "$HOSTS" | awk '$0 ~ /regionserver/ {print $2}' > $HBASE_NAME/conf/regionservers

    # 添加backup-masters
    echo "$HOSTS" | awk '$0 ~ /hbase-master/ {print $2}' | sed '1 d' > $HBASE_NAME/conf/backup-masters

    # hbase监控
    find $DIR -maxdepth 1 -type f -name "hadoop-metrics2-hbase.properties" | xargs -r -I {} cp {} $HBASE_NAME/conf
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载hbase
    if [[ ! -f $HBASE_PKG ]]; then
        debug "Download hbase from: $HBASE_URL"
        wget $HBASE_URL
    fi

    # 解压hbase安装包
    tar -zxf $HBASE_PKG

    # 配置hbase
    config_hbase

    # 压缩配置好的hbase
    mv -f $HBASE_PKG ${HBASE_PKG}.o
    tar -zcf $HBASE_PKG $HBASE_NAME

    # 安装hbase
    debug "Install hbase"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Install hbase at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建hbase安装目录
            mkdir -p $HBASE_INSTALL_DIR

            # 安装hbase
            rm -rf $HBASE_INSTALL_DIR/$HBASE_NAME
            mv -f $HBASE_NAME $HBASE_INSTALL_DIR
            chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_INSTALL_DIR
            if [[ `basename $HBASE_HOME` != $HBASE_NAME ]]; then
                su -l $HBASE_USER -c "ln -snf $HBASE_INSTALL_DIR/$HBASE_NAME $HBASE_HOME"
            fi

            # 配置文件
            if [[ $HBASE_CONF_DIR != $HBASE_HOME/conf ]]; then
                mkdir -p $HBASE_CONF_DIR
                mv -f $HBASE_HOME/conf/* $HBASE_CONF_DIR
                chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_CONF_DIR
            fi
        else
            autoscp "$admin_passwd" $HBASE_PKG ${admin_user}@${ip}:~/$HBASE_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $HBASE_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HBASE_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HBASE_INSTALL_DIR/$HBASE_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HBASE_NAME $HBASE_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_INSTALL_DIR"
            if [[ `basename $HBASE_HOME` != $HBASE_NAME ]]; then
                autossh "$owner_passwd" ${HBASE_USER}@${ip} "ln -snf $HBASE_INSTALL_DIR/$HBASE_NAME $HBASE_HOME"
            fi

            if [[ $HBASE_CONF_DIR != $HBASE_HOME/conf ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HBASE_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HBASE_HOME/conf/* $HBASE_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_CONF_DIR"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $HBASE_NAME

    # 创建hbase相关目录
    create_dir

    # 设置hbase环境变量
    set_env
}

# 初始化
function init()
{
    # 创建hdfs hbase根目录
    if [[ -n "$HBASE_ROOT_DIR" ]]; then
        su -l $HDFS_USER -c "hdfs dfs -mkdir -p $HBASE_ROOT_DIR"
        su -l $HDFS_USER -c "hdfs dfs -chown -R ${HBASE_USER}:${HBASE_GROUP} $HBASE_ROOT_DIR"
    fi

    # 启动hbase集群
    start
}

# 启动hbase集群
function start()
{
    debug "Start hbase cluster"
    echo "$HOSTS" | grep hbase-master | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HBASE_USER}@${ip} "$HBASE_HOME/bin/start-hbase.sh"
    done
}

# 停止hbase集群
function stop()
{
    debug "Stop hbase cluster"
    echo "$HOSTS" | grep hbase-master | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HBASE_USER}@${ip} "$HBASE_HOME/bin/stop-hbase.sh"
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-c create user<add/delete>] [-h config host<hostname,hosts>] [-i install] [-k config ssh] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"HMaster|HRegionServer\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HBASE_HOME $HBASE_CONF_DIR $HBASE_TMP_DIR $HBASE_LOG_DIR /tmp/hsperfdata_$HBASE_USER /tmp/Jetty_*"
    done
}

# 测试
function test()
{
: '
    # 显示表
    list

    # 创建表
    create 'test', {NAME => 'cf', VERSIONS => 3, TTL => 600}

    # 插入数据
    put 'test', 'row1', 'cf:ca', 'value1'
    put 'test', 'row1', 'cf:ca', 'value2'
    put 'test', 'row1', 'cf:ca', 'value3'

    # 获取表数据
    scan 'test'
    # 指定行健范围
    scan 'test', { STARTROW => 'row001', STOPROW => 'row010' }
    # 指定时间范围
    scan 'test', { TIMERANGE => [1513321938, 1513325538] }
    # 逆向扫描
    scan 'test', { REVERSED => true, LIMIT => 3 }

    # 获取一行数据
    get 'test', 'row1'
    get 'test', 'row1', {COLUMN => 'ca', VERSIONS => 2}

    # 禁用表
    disable 'test'

    # 启用表
    enable 'test'

    # 显示表定义
    desc 'test'

    # 删除表
    drop 'test'

    # 创建快照
    snapshot 'test', 'test-20160718'

    # 列出所有快照
    list_snapshots

    # 删除快照
    delete_snapshot 'test-20160718'

    # 从快照创建表
    clone_snapshot 'test-20160718', 'test-new'

    # 从快照恢复表
    disable 'test'
    restore_snapshot 'test-20160718'

    # 导出表到hdfs目录
    hbase org.apache.hadoop.hbase.mapreduce.Export table_name hdfs_dir

    # 导入hdfs文件到hbase表
    hbase org.apache.hadoop.hbase.mapreduce.Import table_name hdfs_dir
'
}

# 管理
function admin()
{
    ps aux | grep HMaster/HRegionServer

    # 打印xml配置信息
    print_config < $HBASE_CONF_DIR/hbase-site.xml

    # WebUI: http://hdpc1-mn01:16010/
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
    # -k 配置ssh免密码登录
    # -s [init/start/stop/restart] 启动/停止集群
    # -v debug模式
    while getopts "c:h:iks:v" name; do
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
            k)
                ssh_flag=1;;
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

    # 配置ssh免密码登录
    [[ $ssh_flag ]] && log_fn config_ssh

    # 安装集群
    [[ $install_flag ]] && log_fn install

    # 启动集群
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"