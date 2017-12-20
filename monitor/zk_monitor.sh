#!/bin/bash
#
# Author: superz
# Date: 2017-12-18
# Description: zookeeper监控重启程序

# 用法:
: '
ZK_HOME=/usr/zookeeper/current
* * * * * $ZK_HOME/bin/zk_monitor.sh > $ZK_HOME/zk_start.log 2>&1
'


source /etc/profile
source .bash_profile


function log()
{
    echo "$(date +'%F %T') $@"
}

if [[ ! `$ZK_HOME/bin/zkServer.sh status` ]]; then
    log "Kill zookeeper process if exists"
    jps | grep QuorumPeerMain | cut -d ' ' -f 1 | xargs -r kill -9

    log "Start zookeeper"
    cd $ZK_HOME
    ./bin/zkServer.sh start
fi
