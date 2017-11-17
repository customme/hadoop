#!/bin/bash
#
# Author: superz
# Date: 2016-03-15
# Description: ambari集群安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# hadoop集群配置信息
# ip hostname admin_user admin_passwd roles
HOSTS="192.168.1.178 hdpc1-mn01 root 123456 server,agent
192.168.1.179 hdpc1-mn02 root 123456 agent,mysql
192.168.1.227 hdpc1-sn001 root 123456 agent
192.168.1.229 hdpc1-sn002 root 123456 agent
192.168.1.230 hdpc1-sn003 root 123456 agent"


# 安装
function install()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd roles; do
        if [[ "$roles" =~ server ]]; then
            # 安装ambari-server
            autossh "$admin_passwd" ${admin_user}@${ip} "yum -y install ambari-server"
        fi

        if [[ "$roles" =~ agent ]]; then
            # 安装ambari-agent
            autossh "$admin_passwd" ${admin_user}@${ip} "yum -y install ambari-agent"

            # 将ambari-agent的hostname指向ambari-server
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/\\\[server\\\]/{n;s/hostname=.*/hostname=hdpc1-mn01/}' /etc/ambari-agent/conf/ambari-agent.ini"
        fi
    done
}

# 启动
function startup()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd roles; do
        if [[ "$roles" =~ server ]]; then
            # 启动ambari-server
            autossh "$admin_passwd" ${admin_user}@${ip} "ambari-server start"
        fi

        if [[ "$roles" =~ agent ]]; then
            # 启动ambari-agent
            autossh "$admin_passwd" ${admin_user}@${ip} "ambari-agent start"
        fi
    done
}

# 卸载
function uninstall()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd roles; do
        if [[ "$roles" =~ server ]]; then
            # 停止ambari-server
            autossh "$admin_passwd" ${admin_user}@${ip} "ambari-server stop"
        fi

        if [[ "$roles" =~ agent ]]; then
            # 停止ambari-agent
            autossh "$admin_passwd" ${admin_user}@${ip} "ambari-agent stop"
        fi

        if [[ "$roles" =~ mysql ]]; then
            # 停止mysql
            autossh "$admin_passwd" ${admin_user}@${ip} "service mysqld stop"

            # 卸载mysql
            autossh "$admin_passwd" ${admin_user}@${ip} "rpm -qa | grep mysql | xargs -r rpm -e --nodeps"

            # 删除文件
            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf /var/lib/mysql /data/mysql"
        fi

        # 卸载mysql客户端
        autossh "$admin_passwd" ${admin_user}@${ip} "rpm -qa | grep mysql | xargs -r rpm -e --nodeps"

        # 卸载ambari安装包
        autossh "$admin_passwd" ${admin_user}@${ip} "rpm -qa | grep ambari | xargs -r rpm -e --nodeps"

        # 删除ambari安装文件
        autossh "$admin_passwd" ${admin_user}@${ip} "find / -name \"ambari*\" | xargs -r rm -rf"

        # 删除hadoop系列
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf /usr/hdp /var/lib/hadoop* /var/lib/impala /var/lib/solr /var/lib/zookeeper /var/lib/slider /var/lib/storm /var/lib/oozie /var/lib/sqoop* /var/lib/spark /var/lib/hbase /var/lib/hive /var/lib/flume-ng /var/lib/sentry /var/lib/llama"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf /etc/hadoop* /etc/impala /etc/solr /etc/zookeeper /etc/slider /etc/storm /etc/oozie /etc/sqoop* /etc/spark /etc/hbase /etc/hive /etc/flume-ng /etc/sentry /etc/llama"

        # 删除相关连接
        autossh "$admin_passwd" ${admin_user}@${ip} "ls -l /usr/bin/ | grep hdp | awk '{print $NF}' | xargs -r rm -f"
        autossh "$admin_passwd" ${admin_user}@${ip} "ls -l /usr/bin/ | grep hdp | awk '{print $9}' | xargs -r -I {} rm -f /usr/bin/{}"
    done
}

function main()
{
    # 安装集群
    install

    # 启动集群
    startup

    # 卸载集群
    #uninstall
}
main "$@"