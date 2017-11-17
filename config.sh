# Author: superz
# Date: 2015-11-20
# Description: 集群配置信息


# 本机ip
LOCAL_IP=`ifconfig eth0 2> /dev/null | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1`
if [[ -z "$LOCAL_IP" ]]; then
    LOCAL_IP=`ifconfig eno1 2> /dev/null | grep "inet " | awk '{print $2}'`
fi

# 系统版本号
SYS_VERSION=`sed 's/.* release \([0-9]\.[0-9]\).*/\1/' /etc/redhat-release`

# 时间服务器
TIME_SERVER=1.asia.pool.ntp.org

# ssh端口
SSH_PORT=22

# 用户配置文件目录
CONF_DIR=conf
# 用户库文件目录
LIB_DIR=lib

# 集群配置信息
# ip hostname admin_user admin_passwd roles
HOSTS="10.10.20.99 yygz-99.tjinserv.com root 7oGTb2P3nPQKHWw1ZG namenode,zkfc,yarn,historyserver,hbase-master,metastore,spark-master,gmond
10.10.20.101 yygz-101.tjinserv.com root 7oGTb2P3nPQKHWw1ZG namenode,zkfc,httpfs,yarn,hbase-master,hiveserver2,spark-master,history-server,gmetad
10.10.20.104 yygz-104.tjinserv.com root 7oGTb2P3nPQKHWw1ZG datanode,journalnode,zookeeper,regionserver,hive-client,spark-worker,flume,kafka,gmond
10.10.20.110 yygz-110.tjinserv.com root 7oGTb2P3nPQKHWw1ZG datanode,journalnode,zookeeper,regionserver,hive-client,spark-worker,flume,kafka,gmond
10.10.20.111 yygz-111.tjinserv.com root 7oGTb2P3nPQKHWw1ZG datanode,journalnode,zookeeper,regionserver,hive-client,spark-worker,flume,kafka,gmond"

# hadoop组件版本
JAVA_VERSION=1.7.0_80
HADOOP_VERSION=2.7.4
ZK_VERSION=3.4.11
HBASE_VERSION=1.2.6
HIVE_VERSION=1.2.2
SCALA_VERSION=2.11.11
SPARK_VERSION=2.1.2
KAFKA_VERSION=1.0.0
FLUME_VERSION=1.7.0
STORM_VERSION=1.1.1
KYLIN_VERSION=2.2.0

# jdk安装包路径
JAVA_NAME=jdk${JAVA_VERSION}
JAVA_PKG=/work/soft/jdk-7u80-linux-x64.tar.gz

SCALA_NAME=scala-${SCALA_VERSION}
# scala安装包名
SCALA_PKG=${SCALA_NAME}.tgz
# scala安装包下载地址
SCALA_URL=http://downloads.lightbend.com/scala/${SCALA_VERSION}/${SCALA_NAME}.tgz

# 安装目录
BASE_INSTALL_DIR=/usr
JAVA_INSTALL_DIR=/work/install
HADOOP_INSTALL_DIR=$BASE_INSTALL_DIR/hadoop
ZK_INSTALL_DIR=$BASE_INSTALL_DIR/zookeeper
HBASE_INSTALL_DIR=$BASE_INSTALL_DIR/hbase
HIVE_INSTALL_DIR=$BASE_INSTALL_DIR/hive
SCALA_INSTALL_DIR=$BASE_INSTALL_DIR/scala
SPARK_INSTALL_DIR=$BASE_INSTALL_DIR/spark
KAFKA_INSTALL_DIR=$BASE_INSTALL_DIR/kafka
FLUME_INSTALL_DIR=$BASE_INSTALL_DIR/flume
STORM_INSTALL_DIR=$BASE_INSTALL_DIR/storm
KYLIN_INSTALL_DIR=$BASE_INSTALL_DIR/kylin

# 用户名，所属组
HDFS_USER=hdfs
HDFS_GROUP=hadoop
ZK_USER=zookeeper
ZK_GROUP=hadoop
HBASE_USER=hbase
HBASE_GROUP=hadoop
HIVE_USER=hive
HIVE_GROUP=hadoop
SPARK_USER=spark
SPARK_GROUP=hadoop
KAFKA_USER=kafka
KAFKA_GROUP=hadoop
FLUME_USER=flume
FLUME_GROUP=hadoop
STORM_USER=storm
STORM_GROUP=hadoop
KYLIN_USER=kylin
KYLIN_GROUP=hadoop

# 环境变量
JAVA_HOME=$JAVA_INSTALL_DIR/jdk${JAVA_VERSION}
HADOOP_HOME=$HADOOP_INSTALL_DIR/current
ZK_HOME=$ZK_INSTALL_DIR/current
HBASE_HOME=$HBASE_INSTALL_DIR/current
HIVE_HOME=$HIVE_INSTALL_DIR/current
SCALA_HOME=$SCALA_INSTALL_DIR/current
SPARK_HOME=$SPARK_INSTALL_DIR/current
KAFKA_HOME=$KAFKA_INSTALL_DIR/current
FLUME_HOME=$FLUME_INSTALL_DIR/current
STORM_HOME=$STORM_INSTALL_DIR/current
KYLIN_HOME=$KYLIN_INSTALL_DIR/current

# 配置文件目录
HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ZK_CONF_DIR=$ZK_HOME/conf
HBASE_CONF_DIR=$HBASE_HOME/conf
HIVE_CONF_DIR=$HIVE_HOME/conf
SPARK_CONF_DIR=$SPARK_HOME/conf
FLUME_CONF_DIR=$FLUME_HOME/conf
STORM_CONF_DIR=$STORM_HOME/conf
KYLIN_CONF_DIR=$KYLIN_HOME/conf

# 相关目录根目录
HADOOP_TMP_DIR=/work/hadoop/tmp
HADOOP_DATA_DIR=/work/hadoop/data
HADOOP_LOG_DIR=/work/hadoop/log
ZK_DATA_DIR=/work/zookeeper/data
ZK_LOG_DIR=/work/zookeeper/log
HBASE_TMP_DIR=/work/hbase/tmp
HBASE_LOG_DIR=/work/hbase/log
HIVE_TMP_DIR=/work/hive/tmp
HIVE_LOG_DIR=/work/hive/log
SPARK_LOG_DIR=/work/spark/log
SPARK_TMP_DIR=/work/spark/tmp
KAFKA_LOG_DIR=/work/kafka/log
KAFKA_TMP_DIR=/work/kafka/tmp
FLUME_LOG_DIR=/work/flume/log
STORM_TMP_DIR=/work/storm/tmp
STORM_LOG_DIR=/work/storm/log

# dfs nameservice id
NAMESERVICE_ID=cluster1

# yarn staging目录
YARN_STAG_DIR=hdfs://$NAMESERVICE_ID/tmp
# hive仓库目录
HIVE_DB_DIR=hdfs://$NAMESERVICE_ID/hive/warehouse
# hbase数据目录
HBASE_ROOT_DIR=hdfs://$NAMESERVICE_ID/hbase

# namenode数据目录
DFS_NAME_DIR=$HADOOP_DATA_DIR/dfsname
# datanode数据目录
DFS_DATA_DIR=$HADOOP_DATA_DIR/dfsdata

# hadoop heapsize
# $HADOOP_CONF_DIR/hadoop-env.sh
HADOOP_NAMENODE_HEAP="-Xms16g -Xmx16g"
HADOOP_DATANODE_HEAP="-Xms2g -Xmx2g"
HADOOP_CLIENT_HEAP="-Xms32m -Xmx1g"
# $HADOOP_CONF_DIR/yarn-env.sh
YARN_RESOURCEMANAGER_HEAP="-Xms4g -Xmx4g"
YARN_NODEMANAGER_HEAP="-Xms2g -Xmx2g"
# $HADOOP_CONF_DIR/mapred-env.sh
MR_HISTORYSERVER_HEAP=1024

# zookeeper heapsize
# $ZK_HOME/bin/zkServer.sh
ZK_SERVER_HEAP="-Xms4g -Xmx4g"
# $ZK_HOME/bin/zkCli.sh
ZK_CLIENT_HEAP="-Xms32m -Xmx1g"

# hbase heapsize
# $HBASE_CONF_DIR/hbase-env.sh
HBASE_MASTER_HEAP="-Xms2g -Xmx2g"
HBASE_REGIONSERVER_HEAP="-Xms16g -Xmx16g"

# hive heapsize
# $HIVE_CONF_DIR/hive-env.sh
HIVE_METASTORE_HEAP="-Xmx8g"
HIVE_SERVER2_HEAP="-Xmx4g"
HIVE_CLIENT_HEAP="-Xms32m -Xmx2g"

# kafka heapsize
# $KAFKA_HOME/bin/kafka-server-start.sh
KAFKA_SERVER_HEAP="-Xms2g -Xmx2g"

# namenode rpc端口
NAMENODE_RPC_PORT=8020
# namenode http端口
NAMENODE_HTTP_PORT=50070
# datanode ipc port
DATANODE_IPC_PORT=50020
# QJM服务端口
QJM_SERVER_PORT=8485
# jobhistory服务端口
JOBHISTORY_SERVER_PORT=10020
# jobhistory web端口
JOBHISTORY_WEB_PORT=19888
# jobhistory admin端口
JOBHISTORY_ADMIN_PORT=10033
# yarn web端口
YARN_WEB_PORT=8088
# hbase master端口
HBASE_MASTER_PORT=60000
# hive metastore thrift端口
HIVE_METASTORE_PORT=9083
# zookeeper服务端口
ZK_SERVER_PORT=2181
# kafka服务端口
KAFKA_SERVER_PORT=9092
# kylin web端口
KYLIN_WEB_PORT=7070

# hadoop jmx
HADOOP_JMX_BASE="-Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
HADOOP_NAMENODE_JMX_PORT=8004
HADOOP_DATANODE_JMX_PORT=8006
YARN_RESOURCEMANAGER_JMX_PORT=8008
YARN_NODEMANAGER_JMX_PORT=8009

# hbase jmx
HBASE_MASTER_JMX_PORT=10101
HBASE_REGIONSERVER_JMX_PORT=10102
