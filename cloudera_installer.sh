#!/bin/bash
#
# Author: superz
# Date: 2016-03-11
# Description: cloudera集群安装程序
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
    todo_fn
}

# 卸载
function uninstall()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd roles; do
        if [[ "$roles" =~ server ]]; then
            # 停止cloudera-scm-server
            autossh "$admin_passwd" ${admin_user}@${ip} "service cloudera-scm-server stop"

            # 卸载文件系统
            autossh "$admin_passwd" ${admin_user}@${ip} "umount /var/run/cloudera-scm-server/process"
        fi

        if [[ "$roles" =~ agent ]]; then
            # 停止cloudera-scm-agent
            autossh "$admin_passwd" ${admin_user}@${ip} "service cloudera-scm-agent stop"

            # 卸载文件系统
            autossh "$admin_passwd" ${admin_user}@${ip} "umount /var/run/cloudera-scm-agent/process"
        fi

        if [[ "$roles" =~ mysql ]]; then
            # 停止mysql
            autossh "$admin_passwd" ${admin_user}@${ip} "service mysqld stop"

            # 卸载mysql
            autossh "$admin_passwd" ${admin_user}@${ip} "rpm -qa | grep mysql | xargs -r rpm -e --nodeps"

            # 删除文件
            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf /var/lib/mysql"
        fi

        # 卸载cloudera安装包
        autossh "$admin_passwd" ${admin_user}@${ip} "rpm -qa | grep cloudera | xargs -r rpm -e --nodeps"

        # 删除cloudera安装文件
        autossh "$admin_passwd" ${admin_user}@${ip} "find / -name \"cloudera*\" | xargs -r rm -rf"

        # 删除hadoop系列
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf /var/lib/hadoop* /var/lib/impala /var/lib/solr /var/lib/zookeeper /var/lib/hue /var/lib/storm /var/lib/oozie /var/lib/sqoop* /var/lib/spark /var/lib/hbase /var/lib/hive /var/lib/flume-ng /var/lib/sentry /var/lib/llama"

        # 删除相关连接
        autossh "$admin_passwd" ${admin_user}@${ip} "ls -l /etc/alternatives/ | grep cloudera | awk '{print $NF}' | xargs -r rm -f"
        autossh "$admin_passwd" ${admin_user}@${ip} "ls -l /etc/alternatives/ | grep cloudera | awk '{print $9}' | xargs -r -I {} rm -f /etc/alternatives/{}"
    done
}

function main()
{
    todo_fn
}
main "$@"