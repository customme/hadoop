#!/bin/bash
#
# Author: superz
# Date: 2017-12-18
# Description: hdfs监控重启程序

# 用法:
: '
HADOOP_HOME=/usr/hadoop/current
* * * * * $HADOOP_HOME/bin/hdfs_monitor.sh > $HADOOP_HOME/hdfs_start.log 2>&1
'


source /etc/profile
source .bash_profile

NAMENODES=(nn1 nn2)


function log()
{
    echo "$(date +'%F %T') $@"
}

for namenode in "${NAMENODES[@]}"; do
    $HADOOP_HOME/bin/hdfs haadmin -getServiceState $namenode
done
