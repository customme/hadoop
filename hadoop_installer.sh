#!/bin/bash
#
# Author: superz
# Date: 2015-11-20
# Description: hadoop集群自动安装程序
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
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="10.10.10.61 yygz-61.gzserv.com root 123456 hadoop123 namenode,zkfc,yarn,historyserver
10.10.10.64 yygz-64.gzserv.com root 123456 hadoop123 namenode,zkfc,httpfs,yarn
10.10.10.65 yygz-65.gzserv.com root 123456 hadoop123 datanode,journalnode,zookeeper
10.10.10.66 yygz-66.gzserv.com root 123456 hadoop123 datanode,journalnode,zookeeper
10.10.10.67 yygz-67.gzserv.com root 123456 hadoop123 datanode,journalnode,zookeeper"
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
HOSTS="192.168.1.178 hdpc1-mn01 root 123456 123456 namenode,zkfc,yarn,historyserver
192.168.1.179 hdpc1-mn02 root 123456 123456 namenode,zkfc,httpfs,yarn
192.168.1.227 hdpc1-sn001 root 123456 123456 datanode,journalnode,zookeeper
192.168.1.229 hdpc1-sn002 root 123456 123456 datanode,journalnode,zookeeper
192.168.1.230 hdpc1-sn003 root 123456 123456 datanode,journalnode,zookeeper"
fi

# hadoop镜像
HADOOP_MIRROR=http://mirror.bit.edu.cn/apache/hadoop/common
HADOOP_NAME=hadoop-$HADOOP_VERSION
# hadoop安装包名
HADOOP_PKG=${HADOOP_NAME}.tar.gz
# hadoop安装包下载地址
HADOOP_URL=$HADOOP_MIRROR/$HADOOP_NAME/$HADOOP_PKG

# 相关目录
HADOOP_PID_DIR=$HADOOP_TMP_DIR
YARN_PID_DIR=$HADOOP_TMP_DIR
YARN_LOG_DIR=$HADOOP_LOG_DIR
HADOOP_MAPRED_PID_DIR=$HADOOP_TMP_DIR
HADOOP_MAPRED_LOG_DIR=$HADOOP_LOG_DIR
HTTPFS_LOG_DIR=$HADOOP_LOG_DIR
HTTPFS_TMP_DIR=$HADOOP_TMP_DIR

# dfs exclude hosts
DFS_EXCLUDE_FILE=excludes

# 当前用户名，所属组
THE_USER=$HDFS_USER
THE_GROUP=$HDFS_GROUP

# 用户hadoop配置文件目录
CONF_DIR=$CONF_DIR/hadoop


# 创建hadoop相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 临时文件目录
            mkdir -p $HADOOP_TMP_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_TMP_DIR

            # 数据文件目录
            mkdir -p $HADOOP_DATA_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_DATA_DIR

            # 日志文件目录
            mkdir -p $HADOOP_LOG_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_LOG_DIR
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_TMP_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_TMP_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_DATA_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_DATA_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_LOG_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_LOG_DIR"
        fi
    done
}

# 设置hadoop环境变量
function set_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# hadoop config start/,/^# hadoop config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # hadoop config start' /etc/profile
            sed -i "$ a export HADOOP_HOME=$HADOOP_HOME" /etc/profile
            sed -i "$ a export HADOOP_CONF_DIR=$HADOOP_CONF_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" /etc/profile
            sed -i '$ a # hadoop config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hadoop config start/,/^# hadoop config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hadoop config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HADOOP_HOME=$HADOOP_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HADOOP_CONF_DIR=$HADOOP_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$HADOOP_HOME/bin:\\\$HADOOP_HOME/sbin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hadoop config end' /etc/profile"
        fi
    done
}

# core 配置
function core_config()
{
    # Basic
    echo "
fs.defaultFS=hdfs://$NAMESERVICE_ID
hadoop.tmp.dir=$HADOOP_TMP_DIR
fs.trash.interval=4320
fs.trash.checkpoint.interval=60
"

    # HTTPFS
    echo "
hadoop.proxyuser.hdfs.hosts=*
hadoop.proxyuser.hdfs.groups=*
"

    # Tuning
    echo "
io.file.buffer.size=4096
ipc.server.listen.queue.size=128
"
}

# hdfs 配置
function hdfs_config()
{
    # Basic
    echo "
dfs.namenode.name.dir=file://$DFS_NAME_DIR
dfs.datanode.data.dir=file://$DFS_DATA_DIR
dfs.replication=2
dfs.datanode.du.reserved=1073741824
dfs.blockreport.intervalMsec=600000
dfs.datanode.directoryscan.interval=600
dfs.namenode.datanode.registration.ip-hostname-check=false
dfs.hosts.exclude=$HADOOP_CONF_DIR/excludes
"

    local namenodes=(`echo "$HOSTS" | awk '$6 ~ /namenode/ {printf("%s ",$2)}'`)
    local journalnodes=`echo "$HOSTS" | awk '$6 ~ /journalnode/ {printf("%s:%s,",$2,"'$QJM_SERVER_PORT'")}' | sed 's/,$//'`

    # NameNode HA
    echo "
dfs.nameservices=$NAMESERVICE_ID
dfs.ha.namenodes.$NAMESERVICE_ID=$NAMESERVICE_ID1,$NAMESERVICE_ID2
dfs.namenode.rpc-address.$NAMESERVICE_ID.NAMESERVICE_ID1=${namenodes[0]}:$NAMENODE_RPC_PORT
dfs.namenode.rpc-address.$NAMESERVICE_ID.NAMESERVICE_ID2=${namenodes[1]}:$NAMENODE_RPC_PORT
dfs.namenode.http-address.$NAMESERVICE_ID.NAMESERVICE_ID1=${namenodes[0]}:$NAMENODE_HTTP_PORT
dfs.namenode.http-address.$NAMESERVICE_ID.NAMESERVICE_ID2=${namenodes[1]}:$NAMENODE_HTTP_PORT
dfs.namenode.shared.edits.dir=qjournal:/$journalnodes/$NAMESERVICE_ID
dfs.client.failover.proxy.provider.$NAMESERVICE_ID=org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider
dfs.ha.fencing.methods=sshfence
dfs.ha.fencing.ssh.private-key-files=/home/$HDFS_USER/.ssh/id_rsa
dfs.ha.fencing.ssh.connect-timeout=30000
dfs.journalnode.edits.dir=$HADOOP_DATA_DIR/journal
dfs.ha.automatic-failover.enabled=true
ha.zookeeper.session-timeout.ms=10000
"

    # Tuning
    echo "
dfs.blocksize=64m
dfs.namenode.handler.count=10
dfs.datanode.handler.count=10
dfs.datanode.max.transfer.threads=4096
dfs.datanode.balance.bandwidthPerSec=10485760
dfs.namenode.replication.work.multiplier.per.iteration=4
dfs.namenode.replication.max-streams=10
dfs.namenode.replication.max-streams-hard-limit=20
"
}

# mapred 配置
function mapred_config()
{
    local historyserver=`echo "$HOSTS" | awk '$6 ~ /historyserver/ {print $2}'`

    # Basic
    echo "
mapreduce.framework.name=yarn
mapreduce.jobhistory.address=$historyserver:$JOBHISTORY_SERVER_PORT
mapreduce.jobhistory.webapp.address=$historyserver:$JOBHISTORY_WEB_PORT
mapreduce.jobhistory.admin.address=$historyserver:$JOBHISTORY_ADMIN_PORT
yarn.app.mapreduce.am.staging-dir=/tmp
"

    # Tuning
    echo "
mapreduce.map.memory.mb=512
mapreduce.map.java.opts=-Xmx410m
mapreduce.reduce.memory.mb=512
mapreduce.reduce.java.opts=-Xmx410m
yarn.app.mapreduce.am.resource.mb=512
yarn.app.mapreduce.am.command-opts=-Xmx410m
mapreduce.task.io.sort.mb=100
mapreduce.jobtracker.handler.count=10
mapreduce.tasktracker.http.threads=40
mapreduce.tasktracker.map.tasks.maximum=2
mapreduce.tasktracker.reduce.tasks.maximum=2
"
}

# yarn 配置
function yarn_config()
{
    # Basic
    echo "
yarn.nodemanager.log-dirs=$HADOOP_LOG_DIR/yarn
yarn.nodemanager.remote-app-log-dir=/log/yarn
yarn.nodemanager.aux-services=mapreduce_shuffle
yarn.log-aggregation-enable=true
yarn.log-aggregation.retain-seconds=2592000
yarn.nodemanager.vmem-check-enabled=false
"

    local resourcemanagers=(`echo "$HOSTS" | awk '$6 ~ /yarn/ {printf("%s ",$2)}'`)
    local zookeepers=`echo "$HOSTS" | awk '$6 ~ /zookeeper/ {printf("%s:%s,",$2,"'$ZK_SERVER_PORT'")}' | sed 's/,$//'`

    # ResourceManager HA
    echo "
yarn.resourcemanager.ha.enabled=true
yarn.resourcemanager.cluster-id=$YARN_CLUSTER_ID
yarn.resourcemanager.ha.rm-ids=$YARN_RM_ID1,$YARN_RM_ID2
yarn.resourcemanager.hostname.$YARN_RM_ID1=${resourcemanagers[0]}
yarn.resourcemanager.hostname.$YARN_RM_ID2=${resourcemanagers[1]}
yarn.resourcemanager.webapp.address.$YARN_RM_ID1=${resourcemanagers[0]}:$YARN_WEB_PORT
yarn.resourcemanager.webapp.address.$YARN_RM_ID2=${resourcemanagers[1]}:$YARN_WEB_PORT
yarn.resourcemanager.recovery.enabled=true
yarn.resourcemanager.store.class=org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore
yarn.resourcemanager.zk-address=$zookeepers
"

    # Tuning
    echo "
yarn.nodemanager.resource.memory-mb=2048
yarn.nodemanager.resource.cpu-vcores=2
yarn.scheduler.minimum-allocation-mb=256
yarn.scheduler.maximum-allocation-mb=2048
yarn.scheduler.maximum-allocation-vcores=2
"
}

# httpfs 配置
function httpfs_config()
{
    # Hue HttpFS
    echo "
httpfs.proxyuser.hue.hosts=*
httpfs.proxyuser.hue.groups=*
"
}

# 配置hadoop
function config_hadoop()
{
    # 修改hadoop-env.sh
    sed -i "s@.*\(export JAVA_HOME=\).*@\1${JAVA_HOME}@" $HADOOP_NAME/etc/hadoop/hadoop-env.sh

    # jvm heap
    if [[ -n "$HADOOP_NAMENODE_HEAP" ]]; then
        sed -i "s/.*\(export HADOOP_NAMENODE_OPTS=.*\)\"/\1 ${HADOOP_NAMENODE_HEAP}\"/" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi
    if [[ -n "$HADOOP_DATANODE_HEAP" ]]; then
        sed -i "s/.*\(export HADOOP_DATANODE_OPTS=.*\)\"/\1 ${HADOOP_DATANODE_HEAP}\"/" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi
    if [[ -n "$HADOOP_CLIENT_HEAP" ]]; then
        sed -i "s/\(.*export HADOOP_CLIENT_OPTS=.*\)-Xm[sx][[:alnum:]]\+[ ]\?\(.*\)/\1\2/g" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
        sed -i "s/.*\(export HADOOP_CLIENT_OPTS=.*\)\"/\1 ${HADOOP_CLIENT_HEAP}\"/" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi

    # log/pid directory
    sed -i "s@.*\(export HADOOP_LOG_DIR=\).*@\1${HADOOP_LOG_DIR}@" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    if [[ -n "$HADOOP_PID_DIR" ]]; then
        sed -i "s@.*\(export HADOOP_PID_DIR=\).*@\1${HADOOP_PID_DIR}@" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi

    # jmx
    if [[ -n "$HADOOP_NAMENODE_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/hadoop-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
        fi
        sed -i "$ a export HADOOP_NAMENODE_OPTS=\"\$HADOOP_NAMENODE_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${HADOOP_NAMENODE_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi
    if [[ -n "$HADOOP_DATANODE_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/hadoop-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
        fi
        sed -i "$ a export HADOOP_DATANODE_OPTS=\"\$HADOOP_DATANODE_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${HADOOP_DATANODE_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/hadoop-env.sh

    # 修改yarn-env.sh
    sed -i "s@^\# \(export JAVA_HOME=\).*@\1${JAVA_HOME}@" $HADOOP_NAME/etc/hadoop/yarn-env.sh

    # jvm heap
    if [[ -n "$YARN_RESOURCEMANAGER_HEAP" ]]; then
        sed -i "/export YARN_RESOURCEMANAGER_HEAPSIZE/ a\export YARN_RESOURCEMANAGER_OPTS=\"\$YARN_RESOURCEMANAGER_OPTS ${YARN_RESOURCEMANAGER_HEAP}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi
    if [[ -n "$YARN_NODEMANAGER_HEAP" ]]; then
        sed -i "/export YARN_NODEMANAGER_HEAPSIZE/ a\export YARN_NODEMANAGER_OPTS=\"\$YARN_NODEMANAGER_OPTS ${YARN_NODEMANAGER_HEAP}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi

    # log/pid directory
    if [[ -n "$YARN_LOG_DIR" ]]; then
        sed -i "/\"\$YARN_LOG_DIR/ i\export YARN_LOG_DIR=${YARN_LOG_DIR}" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi
    if [[ -n "$YARN_PID_DIR" ]]; then
        sed -i "$ a \\\nexport YARN_PID_DIR=${YARN_PID_DIR}" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi

    # jmx
    if [[ -n "$YARN_RESOURCEMANAGER_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/yarn-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
        fi
        sed -i "$ a export YARN_RESOURCEMANAGER_OPTS=\"\$YARN_RESOURCEMANAGER_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${YARN_RESOURCEMANAGER_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi
    if [[ -n "$YARN_NODEMANAGER_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/yarn-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
        fi
        sed -i "$ a export YARN_NODEMANAGER_OPTS=\"\$YARN_NODEMANAGER_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${YARN_NODEMANAGER_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/yarn-env.sh

    # 修改mapred-env.sh
    sed -i "s@^\# \(export JAVA_HOME=\).*@\1${JAVA_HOME}@" $HADOOP_NAME/etc/hadoop/mapred-env.sh

    # jvm heap
    if [[ -n "$MR_HISTORYSERVER_HEAP" ]]; then
        sed -i "s/\(export HADOOP_JOB_HISTORYSERVER_HEAPSIZE=\).*/\1${MR_HISTORYSERVER_HEAP}/" $HADOOP_NAME/etc/hadoop/mapred-env.sh
    fi

    # log/pid directory
    if [[ -n "$HADOOP_MAPRED_LOG_DIR" ]]; then
        sed -i "$ a \\\nexport HADOOP_MAPRED_LOG_DIR=${HADOOP_MAPRED_LOG_DIR}" $HADOOP_NAME/etc/hadoop/mapred-env.sh
    fi
    if [[ -n "$HADOOP_MAPRED_PID_DIR" ]]; then
        sed -i "$ a \\\nexport HADOOP_MAPRED_PID_DIR=${HADOOP_MAPRED_PID_DIR}" $HADOOP_NAME/etc/hadoop/mapred-env.sh
    fi

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/mapred-env.sh

    # 配置core-site.xml
    core_config | config_xml $HADOOP_NAME/etc/hadoop/core-site.xml

    # 配置hdfs-site.xml
    hdfs_config | config_xml $HADOOP_NAME/etc/hadoop/hdfs-site.xml

    # 配置mapred-site.xml
    if [[ ! -f $HADOOP_NAME/etc/hadoop/mapred-site.xml ]]; then
        cp $HADOOP_NAME/etc/hadoop/mapred-site.xml.template $HADOOP_NAME/etc/hadoop/mapred-site.xml
    fi
    mapred_config | config_xml $HADOOP_NAME/etc/hadoop/mapred-site.xml

    # 配置yarn-site.xml
    yarn_config | config_xml $HADOOP_NAME/etc/hadoop/yarn-site.xml

    # 配置httpfs-site.xml
    if [[ -f $CONF_DIR/httpfs-site.cfg ]]; then
        sed -i "s@.*\(export HTTPFS_LOG=\).*@\1${HTTPFS_LOG_DIR}@" $HADOOP_NAME/etc/hadoop/httpfs-env.sh
        sed -i "s@.*\(export HTTPFS_TEMP=\).*@\1${HTTPFS_TMP_DIR}@" $HADOOP_NAME/etc/hadoop/httpfs-env.sh
        sed -i "$ a \\\nexport CATALINA_PID=${HADOOP_TMP_DIR}/httpfs.pid" $HADOOP_NAME/etc/hadoop/httpfs-env.sh

        # 删除连续空行
        sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/httpfs-env.sh

        httpfs_config | config_xml $HADOOP_NAME/etc/hadoop/httpfs-site.xml
    fi

    # 修改slaves文件
    echo "$HOSTS" | awk '$0 ~ /datanode/ {print $2}' > $HADOOP_NAME/etc/hadoop/slaves

    # exclude hosts
    if [[ ! -f $HADOOP_NAME/etc/hadoop/$DFS_EXCLUDE_FILE ]]; then
        touch $HADOOP_NAME/etc/hadoop/$DFS_EXCLUDE_FILE
    fi

    # hadoop本地库
    hadoop_native_lib=`find $LIB_DIR -name "hadoop-native-64-*.tar" | head -n 1`
    if [[ -n "$hadoop_native_lib" ]]; then
        tar -xf $hadoop_native_lib -C $HADOOP_NAME/lib/native
    fi

    # hadoop监控
    if [[ -f $CONF_DIR/hadoop-metrics.properties ]]; then
        cp -f $CONF_DIR/hadoop-metrics.properties $HADOOP_NAME/etc/hadoop
    fi
    if [[ -f $CONF_DIR/hadoop-metrics2.properties ]]; then
        cp -f $CONF_DIR/hadoop-metrics2.properties $HADOOP_NAME/etc/hadoop
    fi
}

# 安装
function install()
{
    # 下载hadoop
    if [[ ! -f $HADOOP_PKG ]]; then
        wget $HADOOP_URL
    fi

    # 解压hadoop
    tar -zxf $HADOOP_PKG

    # 配置hadoop
    config_hadoop

    # 压缩配置好的hadoop
    mv -f $HADOOP_PKG ${HADOOP_PKG}.o
    tar -zcf $HADOOP_PKG $HADOOP_NAME

    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建hadoop安装目录
            mkdir -p $HADOOP_INSTALL_DIR

            # 安装hadoop
            rm -rf $HADOOP_INSTALL_DIR/$HADOOP_NAME
            mv -f $HADOOP_NAME $HADOOP_INSTALL_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_INSTALL_DIR
            if [[ `basename $HADOOP_HOME` != $HADOOP_NAME ]]; then
                su -l $HDFS_USER -c "ln -snf $HADOOP_INSTALL_DIR/$HADOOP_NAME $HADOOP_HOME"
            fi

            # 配置文件
            if [[ $HADOOP_CONF_DIR != $HADOOP_HOME/etc/hadoop ]]; then
                mkdir -p $HADOOP_CONF_DIR
                mv -f $HADOOP_HOME/etc/hadoop/* $HADOOP_CONF_DIR
                chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_CONF_DIR
            fi
        else
            autoscp "$admin_passwd" $HADOOP_PKG ${admin_user}@${ip}:~/$HADOOP_PKG $SSH_PORT 100
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $HADOOP_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HADOOP_INSTALL_DIR/$HADOOP_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HADOOP_NAME $HADOOP_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_INSTALL_DIR"
            if [[ `basename $HADOOP_HOME` != $HADOOP_NAME ]]; then
                autossh "$owner_passwd" ${HDFS_USER}@${ip} "ln -snf $HADOOP_INSTALL_DIR/$HADOOP_NAME $HADOOP_HOME"
            fi

            if [[ $HADOOP_CONF_DIR != $HADOOP_HOME/etc/hadoop ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HADOOP_HOME/etc/hadoop/* $HADOOP_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_CONF_DIR"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $HADOOP_NAME

    # 创建hadoop相关目录
    create_dir

    # 设置hadoop环境变量
    set_env
}

# 升级
function upgrade()
{
    # 安装
    install

    # 滚动重启
    if [[ $apply_flag ]]; then
        log_fn rolling_restart
    fi
}

# 初始化
function init()
{
    # 出错立即退出
    set -e

    # 启动journalnode
    echo "$HOSTS" | grep namenode | head -1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemons.sh start journalnode"
    done

    # 格式化zkfc
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/bin/hdfs zkfc -formatZK -force -nonInteractive"
    done

    # 如果从non-HA转HA，需要初始化journalnode
    # hdfs namenode -initializeSharedEdits -force

    # 等待journalnode启动
    sleep 5
    # 格式化hdfs
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/bin/hdfs namenode -format"
    done

    # 启动zkfc
    echo "$HOSTS" | grep zkfc | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemon.sh start zkfc"
    done

    # 启动active namenode
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode"
    done

    # 同步active namenode数据到standby namenode，并启动standby namenode
    echo "$HOSTS" | grep namenode | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/bin/hdfs namenode -bootstrapStandby -force"
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode"
    done

    # 启动所有datanode
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemons.sh start datanode"
    done

    # 启动yarn（resourcemanager、nodemanager）
    echo "$HOSTS" | grep yarn | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/start-yarn.sh"
    done

    # 启动standby resourcemanager
    echo "$HOSTS" | grep yarn | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager"
    done

    # 启动historyserver
    echo "$HOSTS" | grep historyserver | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver"
    done

    # 启动httpfs
    echo "$HOSTS" | grep httpfs | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/httpfs.sh start"
    done
}

# 启动集群
function start()
{
    # 出错立即退出
    set -e

    # 启动dfs（namenode、datanode、journalnode、zkfc）
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/start-dfs.sh"
    done

    # 启动yarn（resourcemanager、nodemanager）
    echo "$HOSTS" | grep yarn | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/start-yarn.sh"
    done

    # 启动standby resourcemanager
    echo "$HOSTS" | grep yarn | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager"
    done

    # 启动historyserver
    echo "$HOSTS" | grep historyserver | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver"
    done

    # 启动httpfs
    echo "$HOSTS" | grep httpfs | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/httpfs.sh start"
    done
}

# 停止集群
function stop()
{
    # 停止dfs（namenode、datanode、journalnode、zkfc）
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/stop-dfs.sh"
    done

    # 停止yarn（resourcemanager、nodemanager）
    echo "$HOSTS" | grep yarn | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/stop-yarn.sh"
    done

    # 停止standby resourcemanager
    echo "$HOSTS" | grep yarn | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/yarn-daemon.sh stop resourcemanager"
    done

    # 停止historyserver
    echo "$HOSTS" | grep historyserver | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh stop historyserver"
    done

    # 停止httpfs
    echo "$HOSTS" | grep httpfs | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/httpfs.sh stop"
    done
}

# 滚动重启
function rolling_restart()
{
    # active namenode ip
    ACTIVE_IP="192.168.1.227"
    STANDBY_IP="192.168.1.229"
    ACTIVE_HOST=(`echo "$HOSTS" | grep $ACTIVE_IP`)
    STANDBY_HOST=(`echo "$HOSTS" | grep $STANDBY_IP`)
    ACTIVE_ID="nn1"
    STANDBY_ID="nn2"

    # 重启namenode
    # 1 创建fsimage
    hdfs dfsadmin -rollingUpgrade prepare
    sleep 3
    # 2 等待fsimage创建成功
    local msg=`hdfs dfsadmin -rollingUpgrade query`
    while [[ -z `echo "$msg" | grep "Proceed with rolling upgrade"` ]]; do
        sleep 3
        msg=`hdfs dfsadmin -rollingUpgrade query`
    done
    # 3 关闭standby namenode
    $HADOOP_HOME/sbin/hadoop-daemon.sh stop namenode
    # 4 重启standby namenode
    hdfs namenode -rollingUpgrade started
    # 5 切换active/standby namenode
    hdfs haadmin -failover --forcefence --forceactive $STANDBY_ID $ACTIVE_ID
    # 6 关闭active namenode
    $HADOOP_HOME/sbin/hadoop-daemon.sh stop namenode
    # 7 重启active namenode
    hdfs namenode -rollingUpgrade started

    # 重启datanode
    echo "$HOSTS" | grep datanode | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        # 1 关闭datanode
        hdfs dfsadmin -shutdownDatanode $hostname:$DATANODE_IPC_PORT upgrade
        sleep 3
        # 2 获取datanode状态
        msg=`hdfs dfsadmin -getDatanodeInfo $hostname:$DATANODE_IPC_PORT`
        while [[ -z `echo "$msg" | grep "Proceed"` ]]; do
            sleep 3
            msg=`hdfs dfsadmin -getDatanodeInfo $hostname:$DATANODE_IPC_PORT`
        done
        # 3 重启datanode
        $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode
    done

    # 结束本次升级
    hdfs dfsadmin -rollingUpgrade finalize
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-b backup] [-c create user<add/delete>] [-d detect environment] [-h config host<hostname,hosts>] [-i install<zookeeper,hbase,hive,spark>] [-k config ssh] [-s start<init/start/stop/restart>] [-u upgrade<install,apply>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"JournalNode|NameNode|DataNode|ResourceManager|NodeManager|DFSZKFailoverController|JobHistoryServer\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HADOOP_HOME $HADOOP_CONF_DIR $HADOOP_TMP_DIR $HADOOP_LOG_DIR $HADOOP_DATA_DIR /tmp/hsperfdata_$HDFS_USER /tmp/Jetty_*"
    done
}

# 测试
function test()
{
    # 开启debug模式
    export HADOOP_ROOT_LOGGER=DEBUG,console

    # 上传本地文件到hdfs
    hdfs dfs -mkdir /input
    hdfs dfs -put $HADOOP_HOME/LICENSE.txt /input

    # 执行mapreduce任务
    yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-${HADOOP_VERSION}.jar wordcount /input /output

    # 基准测试
    yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-${HADOOP_VERSION}-tests.jar

    # webhdfs
    curl "http://hdpc1-mn01:50070/webhdfs/v1/?op=liststatus&user.name=hdfs"
}

# 管理
function admin()
{
    # 查看dfs报告
    hdfs dfsadmin -report

    # 检测块
    hdfs fsck /

    # 查看正在被打开的文件
    hdfs fsck / -openforwrite

    # 查看缺失块
    hdfs fsck / -list-corruptfileblocks

    # 恢复租约
    hdfs debug recoverLease [-path path] [-retries <num-retries>]

    # 删除坏块
    hdfs fsck / -delete

    # 刷新节点
    hdfs dfsadmin -refreshNodes

    # 备份namenode元数据
    hdfs dfsadmin -fetchImage fsimage.`date +'%Y%m%d%H%M%S'`

    # 查看namenode状态
    hdfs haadmin -getServiceState nn1/nn2

    # 手动切换namenode状态 nn1 -> standby nn2 -> active
    hdfs haadmin -failover --forcefence --forceactive nn1 nn2

    # 强制切换
    hdfs haadmin -transitionToActive/transitionToStandby --forcemanual nn1/nn2

    # 查看resourcemanager状态
    yarn rmadmin -getServiceState rm1/rm2

    # 手动切换resourcemanager状态
    yarn rmadmin -failover --forcefence --forceactive rm1 rm2

    # 强制切换
    yarn rmadmin -transitionToActive/transitionToStandby --forcemanual rm1/rm2

    # 查看运行节点
    yarn node -list

    # 查看application
    yarn application -list -appStates ALL

    # 杀掉application
    yarn application -kill applicationId

    # 刷新节点
    yarn rmadmin -refreshNodes

    # 查看job
    mapred job -list all

    # 杀掉job
    mapred job -kill jobId

    # 查看日志级别
    hadoop daemonlog -getlevel hdpc1-mn01:50070 log4j.logger.http.requests.namenode
    hadoop daemonlog -getlevel hdpc1-mn01:8088 log4j.logger.http.requests.resourcemanager
    # 设置日志级别
    hadoop daemonlog -setlevel hdpc1-mn01:50070 log4j.logger.http.requests.namenode DEBUG
    hadoop daemonlog -setlevel hdpc1-mn01:8088 log4j.logger.http.requests.resourcemanager DEBUG

    # 获取配置信息
    hdfs getconf -confKey dfs.datanode.max.transfer.threads

    # 设置数据平衡临时带宽
    hdfs dfsadmin -setBalancerBandwidth 52428800
    # 运行数据平衡(前台运行)
    hdfs balancer -threshold 5
    # 运行数据平衡(后台运行)
    $HADOOP_HOME/sbin/start-balancer.sh -threshold 5
    # 停止数据平衡
    $HADOOP_HOME/sbin/stop-balancer.sh

    # 打印xml配置信息
    print_config < $HADOOP_CONF_DIR/core-site.xml
    print_config < $HADOOP_CONF_DIR/hdfs-site.xml
    print_config < $HADOOP_CONF_DIR/mapred-site.xml
    print_config < $HADOOP_CONF_DIR/yarn-site.xml

    # namenode Web UI: http://hdpc1-mn01:50070/

    # yarn Web UI: http://hdpc1-mn01:8088/
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -b 备份重要文件
    # -c [add/delete] 创建用户
    # -d 检测环境
    # -h [hostname,hosts] 配置host
    # -i [zookeeper,hbase,hive,spark] 安装集群
    # -k 配置ssh免密码登录
    # -s [init/start/stop/restart] 启动/停止集群
    # -u [install,apply] 安装,应用
    # -v debug模式
    while getopts "bc:dh:i:ks:u:v" name; do
        case "$name" in
            b)
                backup_flag=1;;
            c)
                create_cmd="$OPTARG"
                if [[ "$create_cmd" = "delete" ]]; then
                    delete_flag=1
                fi
                create_flag=1;;
            d)
                detect_flag=1;;
            h)
                local command="$OPTARG"
                if [[ "$command" =~ "hostname" ]]; then
                    hostname_flag=1
                fi
                if [[ "$command" =~ "hosts" ]]; then
                    hosts_flag=1
                fi;;
            i)
                local command="$OPTARG"
                if [[ "$command" =~ "zookeeper" ]]; then
                    zk_flag=1
                fi
                if [[ "$command" =~ "hbase" ]]; then
                    hbase_flag=1
                fi
                if [[ "$command" =~ "hive" ]]; then
                    hive_flag=1
                fi
                if [[ "$command" =~ "spark" ]]; then
                    spark_flag=1
                fi
                install_flag=1;;
            k)
                ssh_flag=1;;
            s)
                start_cmd="$OPTARG"
                start_flag=1;;
            u)
                local command="$OPTARG"
                if [[ "$command" =~ "apply" ]]; then
                    apply_flag=1
                fi
                upgrade_flag=1;;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 不能同时选择安装和升级
    if [[ $install_flag -eq 1 && $upgrade_flag -eq 1 ]]; then
        echo "You can choose either install or upgrade, but not both at the same time"
        exit 1
    fi

    # 安装环境
    install_env

    # 检测环境
    [[ $detect_flag ]] && log_fn detect_env

    # 备份重要文件
    [[ $backup_flag ]] && log_fn backup

    # 删除用户
    [[ $delete_flag ]] && log_fn delete_user
    # 创建用户
    [[ $create_flag ]] && log_fn create_user

    # 配置host
    [[ $hostname_flag ]] && log_fn modify_hostname
    [[ $hosts_flag ]] && log_fn add_host

    # 配置ssh免密码登录
    [[ $ssh_flag ]] && log_fn config_ssh

    # 安装jdk
    log_fn install_jdk

    # 安装zookeeper
    if [[ $zk_flag ]]; then
        options=${create_flag/1/-c $create_cmd }-i${start_flag/1/ -s $start_cmd}${debug_flag/1/ -v}
        log "Install zookeeper: $DIR/zk_installer.sh $options"
        sh $DIR/zk_installer.sh $options
        log "Install zookeeper done"
    fi

    # 安装hadoop
    [[ $install_flag ]] && log_fn install

    # 升级hadoop
    [[ $upgrade_flag ]] && log_fn upgrade

    # 启动hadoop集群
    [[ $start_flag ]] && log_fn $start_cmd

    # 安装hbase
    if [[ $hbase_flag ]]; then
        options=${create_flag/1/-c $create_cmd }-i${ssh_flag/1/ -k}${start_flag/1/ -s $start_cmd}${debug_flag/1/ -v}
        log "Install hbase: $DIR/hbase_installer.sh $options"
        sh $DIR/hbase_installer.sh $options
        log "Install hbase done"
    fi

    # 安装hive
    if [[ $hive_flag ]]; then
        options=${create_flag/1/-c $create_cmd }-i${start_flag/1/ -s $start_cmd}${debug_flag/1/ -v}
        log "Install hive: $DIR/hive_installer.sh $options"
        sh $DIR/hive_installer.sh $options
        log "Install hive done"
    fi

    # 安装spark
    if [[ $spark_flag ]]; then
        options=${create_flag/1/-c $create_cmd }-i${ssh_flag/1/ -k}${start_flag/1/ -s $start_cmd}${debug_flag/1/ -v}
        log "Install spark: $DIR/spark_installer.sh $options"
        sh $DIR/spark_installer.sh $options
        log "Install spark done"
    fi
}
main "$@"