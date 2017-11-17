#!/bin/bash
#
# Author: superz
# Date: 2016-08-03
# Description: hue自动安装程序
# Dependency: yum


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


HUE_VERSION=3.10.0
HUE_NAME=hue-$HUE_VERSION
HUE_PKG=/root/${HUE_NAME}.tgz

HUE_GROUP=hadoop
HUE_USER=hue
HUE_PASSWD=123456

HUE_INSTALL_DIR=$BASE_INSTALL_DIR/hue
HUE_HOME=$HUE_INSTALL_DIR/current


# 安装
function install()
{
    # 出错立即退出
    set -e

    tar -zxf $HUE_PKG
    cd $HUE_NAME
    make apps
    cd -
    mv $HUE_NAME $HUE_INSTALL_DIR
    if [[ `basename $HUE_HOME` != $HUE_NAME ]]; then
        ln -snf $HUE_INSTALL_DIR/$HUE_NAME $HUE_HOME
    fi

    # 创建用户/组
    groupadd -f $HUE_GROUP
    useradd $HUE_USER -g $HUE_GROUP
    echo "$HUE_PASSWD" | passwd --stdin $HUE_USER

    # 配置hue $HUE_HOME/desktop/conf/hue.ini

    # 配置环境变量
    sed -i '/^# hue config start/,/^# hue config end/d' /etc/profile
    sed -i '$ G' /etc/profile
    sed -i '$ a # hue config start' /etc/profile
    sed -i "$ a export HUE_HOME=$HUE_HOME" /etc/profile
    sed -i "$ a export PATH=\$PATH:\$HUE_HOME/build/evn/bin" /etc/profile
    sed -i '$ a # hue config end' /etc/profile

    # 更换元数据库
    $HUE_HOME/build/evn/bin/hue syncdb
    $HUE_HOME/build/evn/bin/hue migrate
}

# 启动
function start()
{
    debug "Start hue"
    $HUE_HOME/build/evn/bin/supervisor
}

# 停止
function stop()
{
    todo_fn
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-i install] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    todo_fn
}

# 管理
function admin()
{
    todo_fn
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -i 安装
    # -s [init/start/stop/restart] 启动/停止
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

    # 安装
    [[ $install_flag ]] && log_fn install

    # 启动/停止
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"