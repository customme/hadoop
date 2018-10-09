# Author: superz
# Date: 2015-11-20
# Description: 集群配置信息 测试环境


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
