#!/bin/bash
#
# Author: superz
# Date: 2017-09-15
# Description: kylin集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# kylin镜像
KYLIN_MIRROR=http://mirror.bit.edu.cn/apache/kylin
KYLIN_NAME=apache-kylin-${KYLIN_VERSION}-bin-hbase1x
# kylin安装包名
KYLIN_PKG=${KYLIN_NAME}.tar.gz
# kylin安装包下载地址
KYLIN_URL=$KYLIN_MIRROR/apache-kylin-$KYLIN_VERSION/$KYLIN_PKG

# kylin集群配置信息
# ip hostname admin_user admin_passwd owner_passwd role
HOSTS="10.10.20.104 yygz-104.tjinserv.com root 7oGTb2P3nPQKHWw1ZG kylin123 job
10.10.20.110 yygz-110.tjinserv.com root 7oGTb2P3nPQKHWw1ZG kylin123 query
10.10.20.111 yygz-111.tjinserv.com root 7oGTb2P3nPQKHWw1ZG kylin123 query"
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
HOSTS="192.168.1.227 hdpc1-sn001 root 123456 123456 job
192.168.1.229 hdpc1-sn002 root 123456 123456 query
192.168.1.230 hdpc1-sn003 root 123456 123456 query"
fi

# 当前用户名，所属组
THE_USER=$KYLIN_USER
THE_GROUP=$KYLIN_GROUP

# kylin hadoop_conf_dir
KYLIN_HADOOP_CONF_DIR=$KYLIN_HOME/hadoop_conf

# 用户kylin配置文件目录
CONF_DIR=$CONF_DIR/kylin


# 设置kylin环境变量
function set_env()
{
    debug "Set kylin environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set kylin environment variables at host: $ip"
        exec_cmd "sed -i '/^# kylin config start/,/^# kylin config end/d' /etc/profile"
        exec_cmd "sed -i '$ G' /etc/profile"
        exec_cmd "sed -i '$ a # kylin config start' /etc/profile"
        exec_cmd "sed -i \"$ a export KYLIN_HOME=$KYLIN_HOME\" /etc/profile"
        exec_cmd "sed -i \"$ a export PATH=\\\$PATH:\\\$KYLIN_HOME/bin\" /etc/profile"
        exec_cmd "sed -i '$ a # kylin config end' /etc/profile"
    done
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载kylin
    if [[ ! -f $KYLIN_PKG ]]; then
        debug "Download kylin from: $KYLIN_URL"
        wget $KYLIN_URL
    fi

    # 解压kylin安装包
    tar -zxf $KYLIN_PKG

    # 配置kylin
    cp -f $CONF_DIR/kylin.properties $KYLIN_NAME/conf
    local servers=`echo "$HOSTS" | awk '{printf("%s:%s,",$1,"'$KYLIN_WEB_PORT'")}' | sed 's/,$//'`
    sed -i "s/[#]*\(kylin\.server\.cluster-servers=\).*/\1${servers}/" $KYLIN_CONF_DIR/kylin.properties

    # 压缩配置好的kylin
    mv -f $KYLIN_PKG ${KYLIN_PKG}.o
    tar -zcf $KYLIN_PKG $KYLIN_NAME

    # 安装kylin
    debug "Install kylin"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd role; do
        debug "Install kylin at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建kylin安装目录
            mkdir -p $KYLIN_INSTALL_DIR

            # 安装kylin
            rm -rf $KYLIN_INSTALL_DIR/$KYLIN_NAME
            mv -f $KYLIN_NAME $KYLIN_INSTALL_DIR
            chown -R ${KYLIN_USER}:${KYLIN_GROUP} $KYLIN_INSTALL_DIR
            if [[ `basename $KYLIN_HOME` != $KYLIN_NAME ]]; then
                su -l $KYLIN_USER -c "ln -snf $KYLIN_INSTALL_DIR/$KYLIN_NAME $KYLIN_HOME"
            fi

            # 配置文件
            if [[ $KYLIN_CONF_DIR != $KYLIN_HOME/conf ]]; then
                mkdir -p $KYLIN_CONF_DIR
                mv -f $KYLIN_HOME/conf/* $KYLIN_CONF_DIR
                chown -R ${KYLIN_USER}:${KYLIN_GROUP} $KYLIN_CONF_DIR
            fi

            sed -i "s/[#]*\(kylin\.server\.mode=\).*/\1${role}/" $KYLIN_CONF_DIR/kylin.properties
            ln -sf $HADOOP_CONF_DIR/core-site.xml $KYLIN_HADOOP_CONF_DIR/core-site.xml
            ln -sf $HADOOP_CONF_DIR/hdfs-site.xml $KYLIN_HADOOP_CONF_DIR/hdfs-site.xml
            ln -sf $HADOOP_CONF_DIR/yarn-site.xml $KYLIN_HADOOP_CONF_DIR/yarn-site.xml
            ln -sf $HBASE_CONF_DIR/hbase-site.xml $KYLIN_HADOOP_CONF_DIR/hbase-site.xml
            ln -sf $HIVE_CONF_DIR/hive-site.xml $KYLIN_HADOOP_CONF_DIR/hive-site.xml
        else
            autoscp "$admin_passwd" $KYLIN_PKG ${admin_user}@${ip}:~/$KYLIN_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $KYLIN_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $KYLIN_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $KYLIN_INSTALL_DIR/$KYLIN_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $KYLIN_NAME $KYLIN_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${KYLIN_USER}:${KYLIN_GROUP} $KYLIN_INSTALL_DIR"
            if [[ `basename $KYLIN_HOME` != $KYLIN_NAME ]]; then
                autossh "$owner_passwd" ${KYLIN_USER}@${ip} "ln -snf $KYLIN_INSTALL_DIR/$KYLIN_NAME $KYLIN_HOME"
            fi

            if [[ $KYLIN_CONF_DIR != $KYLIN_HOME/conf ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $KYLIN_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $KYLIN_HOME/conf/* $KYLIN_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${KYLIN_USER}:${KYLIN_GROUP} $KYLIN_CONF_DIR"
            fi

            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"s/[#]*\(kylin\\\.server\\\.mode=\).*/\1${role}/\" $KYLIN_CONF_DIR/kylin.properties"
            autossh "$admin_passwd" ${admin_user}@${ip} "ln -sf $HADOOP_CONF_DIR/core-site.xml $KYLIN_HADOOP_CONF_DIR/core-site.xml"
            autossh "$admin_passwd" ${admin_user}@${ip} "ln -sf $HADOOP_CONF_DIR/hdfs-site.xml $KYLIN_HADOOP_CONF_DIR/hdfs-site.xml"
            autossh "$admin_passwd" ${admin_user}@${ip} "ln -sf $HADOOP_CONF_DIR/yarn-site.xml $KYLIN_HADOOP_CONF_DIR/yarn-site.xml"
            autossh "$admin_passwd" ${admin_user}@${ip} "ln -sf $HBASE_CONF_DIR/hbase-site.xml $KYLIN_HADOOP_CONF_DIR/hbase-site.xml"
            autossh "$admin_passwd" ${admin_user}@${ip} "ln -sf $HIVE_CONF_DIR/hive-site.xml $KYLIN_HADOOP_CONF_DIR/hive-site.xml"
        fi
    done

    # 删除安装文件
    rm -rf $KYLIN_NAME

    # 设置kylin环境变量
    set_env
}

# 启动kylin集群
function start()
{
    debug "Start kylin cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        debug "Start kylin at host: $ip"
        autossh "$owner_passwd" ${KYLIN_USER}@${ip} "$KYLIN_HOME/bin/kylin.sh start"
    done
}

# 停止kylin集群
function stop()
{
    debug "Stop kylin cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd myid; do
        debug "Stop kylin at host: $ip"
        autossh "$owner_passwd" ${KYLIN_USER}@${ip} "$KYLIN_HOME/bin/kylin.sh stop"
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
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $KYLIN_HOME $KYLIN_CONF_DIR $KYLIN_DATA_DIR $KYLIN_LOG_DIR /tmp/hsperfdata_$KYLIN_USER /tmp/Jetty_*"
    done
}

# 管理
function admin()
{
    ps aux | grep kylin

    # Web UI: http://<hostname>:7070/kylin
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