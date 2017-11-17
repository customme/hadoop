#!/bin/bash
#
# Author: superz
# Date: 2016-07-25
# Description: ganglia集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# 安装
function install()
{
    # 出错立即退出
    set -e

    # 安装ganglia
    debug "Install ganglia"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Install ganglia at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 安装epel yum源
            yum -y install epel-release

            # 安装ganglia
            yum -y install ganglia-gmetad ganglia-devel ganglia-gmond rrdtool httpd ganglia-web php

            # 部署ganglia web到http服务器
            ln -snf /usr/share/ganglia /var/www/html
            chown -R apache:apache /var/www/html/ganglia
            chmod -R 755 /var/www/html/ganglia

            # 配置ganglia web
            sed -i '/<\/Location>/ i\  Allow from all' /etc/httpd/conf.d/ganglia.conf

            # 配置ganglia meta
            sed -i '/^data_source/ a\data_source "hadoop cluster1" hdpc1-mn01' /etc/ganglia/gmetad.conf

            # 配置ganglia monitor
            # /etc/ganglia/gmond.conf
            # globals
            # send_metadata_interval = 30
            #
            # cluster
            # name = "hadoop cluster1"
            # owner = "ganglia"
            #
            # udp_send_channel
            # host = hdpc1-mn01
            # port = 8649
            #
            # udp_recv_channel
            # port = 8649
            #
            # tcp_accept_channel
            # port = 8649
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "yum -y install epel-release"

            autossh "$admin_passwd" ${admin_user}@${ip} "yum -y install ganglia-gmond"
        fi
    done
}

# 启动ganglia集群
function start()
{
    debug "Start ganglia cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Start ganglia at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            service httpd start
            service gmetad start
            service gmond start
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "service gmond start"
        fi
    done
}

# 停止ganglia集群
function stop()
{
    debug "Stop ganglia cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Stop ganglia at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            service httpd stop
            service gmetad stop
            service gmond stop
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "service gmond stop"
        fi
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-i install] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            rpm --nodeps -e ganglia-gmetad ganglia-devel ganglia-gmond ganglia-web
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "rpm --nodeps -e ganglia-gmond"
        fi
    done
}

# 管理
function admin()
{
    # gmetad dead but subsys locked
    # service iptables stop
    # setenforce 0
    # rm -rf /var/lib/ganglia/rrds/*
    # 重启所有服务
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -i 安装集群
    # -s [init/start/stop/restart] 启动/停止集群
    # -v debug模式
    while getopts "is:v" name; do
        case "$name" in
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

    # 安装集群
    [[ $install_flag ]] && log_fn install

    # 启动集群
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"