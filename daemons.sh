#!/bin/bash
#
# Author: superz
# Date: 2016-08-05
# Description: 守护进程


HADOOP_HOME=/usr/hadoop/current
ZK_HOME=/usr/zookeeper/current
HBASE_HOME=/usr/hbase/current
HIVE_HOME=/usr/hive/current
SPARK_HOME=/usr/spark/current

# zookeeper
* * * * * ($ZK_HOME/bin/zkServer.sh status || ((echo "`date +'\%F \%T'` [ Start zookeeper ]";source /etc/profile;cd $ZK_HOME;./bin/zkServer.sh start) >> $ZK_HOME/zk_start.log 2>&1))

# namenode
* * * * * ($HADOOP_HOME/bin/hdfs haadmin -getServiceState nn1 || ((echo "`date +'\%F \%T'` [ Start namenode ]";$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode) >> $HADOOP_HOME/namenode_start.log 2>&1))

# zkfc
* * * * * ([[ ! `ps aux | grep DFSZKFailoverController | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start zkfc ]";$HADOOP_HOME/sbin/hadoop-daemon.sh start zkfc) >> $HADOOP_HOME/zkfc_start.log 2>&1))

# journalnode
* * * * * ([[ ! `ps aux | grep JournalNode | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start journalnode ]";$HADOOP_HOME/sbin/hadoop-daemon.sh start journalnode) >> $HADOOP_HOME/journalnode_start.log 2>&1))

# resourcemanager
* * * * * ($HADOOP_HOME/bin/yarn rmadmin -getServiceState rm1 || ((echo "`date +'\%F \%T'` [ Start resourcemanager ]";$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager) >> $HADOOP_HOME/resourcemanager_start.log 2>&1))

# nodemanager
* * * * * ([[ ! `ps aux | grep NodeManager | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start nodemanager ]";$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager) >> $HADOOP_HOME/nodemanager_start.log 2>&1))

# datanode
* * * * * ([[ ! `ps aux | grep DataNode | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start datanode ]";$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode) >> $HADOOP_HOME/datanode_start.log 2>&1))

# job history server
* * * * * ([[ ! `ps aux | grep JobHistoryServer | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start mapreduce historyserver ]";$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver) >> $HADOOP_HOME/historyserver_start.log 2>&1))

# hbase master
* * * * * ([[ ! `ps aux | grep HMaster | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start hbase master ]";$HBASE_HOME/bin/hbase-daemon.sh start master) >> $HBASE_HOME/master_start.log 2>&1))

# hbase regionserver
* * * * * ([[ ! `ps aux | grep HRegionServer | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start regionserver ]";$HBASE_HOME/bin/hbase-daemon.sh start regionserver) >> $HBASE_HOME/regionserver_start.log 2>&1))

# hive metastore
* * * * * ([[ ! `ps aux | grep HiveMetaStore | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start hive metastore ]";source /etc/profile;nohup $HIVE_HOME/bin/hive --service metastore) >> $HIVE_HOME/metastore_start.log 2>&1 &))

# hive server2
* * * * * ([[ ! `ps aux | grep HiveServer2 | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start hiveserver2 ]";source /etc/profile;nohup $HIVE_HOME/bin/hiveserver2) >> $HIVE_HOME/hiveserver2_start.log 2>&1 &))

# spark master
* * * * * ([[ ! `ps aux | grep 'spark.*Master' | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start spark master ]";$SPARK_HOME/sbin/start-master.sh) >> $SPARK_HOME/master_start.log 2>&1))

# spark worker
SPARK_MASTER=spark://hdpc1-dn001:7077,hdpc1-dn002:7077
* * * * * ([[ ! `ps aux | grep 'spark.*Worker' | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start spark worker ]";$SPARK_HOME/sbin/start-slave.sh $SPARK_MASTER) >> $SPARK_HOME/worker_start.log 2>&1))

# spark history server
* * * * * ([[ ! `ps aux | grep 'spark.*HistoryServer' | grep -v grep` ]] && ((echo "`date +'\%F \%T'` [ Start spark history server ]";$SPARK_HOME/sbin/start-history-server.sh) >> $SPARK_HOME/historyserver_start.log 2>&1))
