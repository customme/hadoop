# Author: superz
# Date: 2015-11-20
# Description: 集群配置信息 测试环境


# 用户配置文件目录
CONF_DIR=conf-test

# 集群配置信息
# ip hostname admin_user admin_passwd roles
HOSTS="192.168.1.178 hdpc1-mn01 root 123456 namenode,zkfc,yarn,historyserver,hbase-master,metastore,spark-master,gmond
192.168.1.179 hdpc1-mn02 root 123456 namenode,zkfc,httpfs,yarn,hbase-master,hiveserver2,spark-master,history-server,gmetad
192.168.1.227 hdpc1-sn001 root 123456 datanode,journalnode,zookeeper,regionserver,hive-client,spark-worker,flume,kafka,gmond
192.168.1.229 hdpc1-sn002 root 123456 datanode,journalnode,zookeeper,regionserver,hive-client,spark-worker,flume,kafka,gmond
192.168.1.230 hdpc1-sn003 root 123456 datanode,journalnode,zookeeper,regionserver,hive-client,spark-worker,flume,kafka,gmond"

# hadoop组件版本
JAVA_VERSION=1.7.0_79

# jdk安装包路径
JAVA_NAME=jdk${JAVA_VERSION}
JAVA_PKG=/root/jdk-7u79-linux-x64.rpm

# 安装目录
BASE_INSTALL_DIR=/usr
JAVA_INSTALL_DIR=$BASE_INSTALL_DIR/java
HADOOP_INSTALL_DIR=$BASE_INSTALL_DIR/hadoop
ZK_INSTALL_DIR=$BASE_INSTALL_DIR/zookeeper
HBASE_INSTALL_DIR=$BASE_INSTALL_DIR/hbase
HIVE_INSTALL_DIR=$BASE_INSTALL_DIR/hive
SCALA_INSTALL_DIR=$BASE_INSTALL_DIR/scala
SPARK_INSTALL_DIR=$BASE_INSTALL_DIR/spark
KAFKA_INSTALL_DIR=$BASE_INSTALL_DIR/kafka
FLUME_INSTALL_DIR=$BASE_INSTALL_DIR/flume
STORM_INSTALL_DIR=$BASE_INSTALL_DIR/storm

# 环境变量
JAVA_HOME=$JAVA_INSTALL_DIR/default
HADOOP_HOME=$HADOOP_INSTALL_DIR/current
ZK_HOME=$ZK_INSTALL_DIR/current
HBASE_HOME=$HBASE_INSTALL_DIR/current
HIVE_HOME=$HIVE_INSTALL_DIR/current
SCALA_HOME=$SCALA_INSTALL_DIR/current
SPARK_HOME=$SPARK_INSTALL_DIR/current
KAFKA_HOME=$KAFKA_INSTALL_DIR/current
FLUME_HOME=$FLUME_INSTALL_DIR/current
STORM_HOME=$STORM_INSTALL_DIR/current

# 配置文件目录
HADOOP_CONF_DIR=/etc/hadoop
ZK_CONF_DIR=/etc/zookeeper
HBASE_CONF_DIR=/etc/hbase
HIVE_CONF_DIR=/etc/hive
SPARK_CONF_DIR=/etc/spark
FLUME_CONF_DIR=/etc/flume
STORM_CONF_DIR=/etc/storm

# 相关目录根目录
HADOOP_TMP_DIR=/var/hadoop/tmp
HADOOP_DATA_DIR=/var/hadoop/data
HADOOP_LOG_DIR=/var/hadoop/log
ZK_DATA_DIR=/var/zookeeper/data
ZK_LOG_DIR=/var/zookeeper/log
HBASE_TMP_DIR=/var/hbase/tmp
HBASE_LOG_DIR=/var/hbase/log
HIVE_TMP_DIR=/var/hive/tmp
HIVE_LOG_DIR=/var/hive/log
SPARK_LOG_DIR=/var/spark/log
SPARK_TMP_DIR=/var/spark/tmp
KAFKA_LOG_DIR=/var/kafka/log
KAFKA_TMP_DIR=/var/kafka/tmp
FLUME_LOG_DIR=/var/flume/log
STORM_TMP_DIR=/var/storm/tmp
STORM_LOG_DIR=/var/storm/log

# namenode数据目录
DFS_NAME_DIR=$HADOOP_DATA_DIR/dfsname
# datanode数据目录
DFS_DATA_DIR=$HADOOP_DATA_DIR/dfsdata

# hadoop jvm heap
# $HADOOP_CONF_DIR/hadoop-env.sh
HADOOP_NAMENODE_HEAP="-Xmx1g"
HADOOP_DATANODE_HEAP="-Xmx512m"
HADOOP_CLIENT_HEAP="-Xms32m -Xmx128m"
# $HADOOP_CONF_DIR/yarn-env.sh
YARN_RESOURCEMANAGER_HEAP="-Xmx512m"
YARN_NODEMANAGER_HEAP="-Xmx512m"
# $HADOOP_CONF_DIR/mapred-env.sh
MR_HISTORYSERVER_HEAP=256

# zookeeper jvm heap
# $ZK_HOME/bin/zkServer.sh
ZK_SERVER_HEAP="-Xmx1g"
# $ZK_HOME/bin/zkCli.sh
ZK_CLIENT_HEAP="-Xms32m -Xmx128m"

# hbase jvm heap
# $HBASE_CONF_DIR/hbase-env.sh
HBASE_MASTER_HEAP="-Xmx512m"
HBASE_REGIONSERVER_HEAP="-Xmx1g"

# hive jvm heap
# $HIVE_CONF_DIR/hive-env.sh
HIVE_METASTORE_HEAP="-Xmx1g"
HIVE_SERVER2_HEAP="-Xmx1g"
HIVE_CLIENT_HEAP="-Xms32m -Xmx512m"

# kafka jvm heap
# $KAFKA_HOME/bin/kafka-server-start.sh
KAFKA_SERVER_HEAP="-Xms128m -Xmx512m"
