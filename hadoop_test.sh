#!/bin/bash

# hadoop基准测试


# 本机ip
LOCAL_IP=`ifconfig eth0 2> /dev/null | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1`

HADOOP_VERSION=2.7.2

CCMD="yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-${HADOOP_VERSION}-tests.jar"

# HDFS写参数
# id nrFiles fileSize
hdfs_write_params="1 1 100GB
2 2 50GB
3 4 25GB
4 5 20GB
5 10 10GB
6 20 5GB
7 50 2GB
8 100 1GB
9 200 512MB
10 400 256MB
11 800 128MB
12 1600 64MB
13 3200 32MB
14 6400 16MB
15 12800 8MB
16 25600 4MB
17 51200 2MB
18 102400 1MB"

# HDFS读参数
# id nrFiles fileSize
hdfs_read_params="1 1 100GB
2 2 50GB
3 4 25GB
4 5 20GB
5 10 10GB
6 20 5GB
7 50 2GB
8 100 1GB
9 200 512MB
10 400 256MB
11 800 128MB
12 1600 64MB
13 3200 32MB
14 6400 16MB
15 12800 8MB
16 25600 4MB
17 51200 2MB
18 102400 1MB"

# NameNode写操作参数
# id maps reduces blockSize numberOfFiles replicationFactorPerFile
nn_write_params="1 1 1 134217728 100 3
2 1 1 134217728 1000 3
3 1 1 134217728 10000 3
4 10 10 134217728 100 3
5 10 10 134217728 1000 3
6 10 10 134217728 10000 3"

# NameNode读操作参数
# id maps reduces numberOfFiles
nn_read_params="1 1 1 100
2 1 1 1000
3 1 1 10000
4 10 10 100
5 10 10 1000
6 10 10 10000"

conf_keys="ipc.server.listen.queue.size
dfs.namenode.handler.count
dfs.datanode.handler.count
dfs.datanode.max.transfer.threads
mapreduce.map.memory.mb
mapreduce.reduce.memory.mb
mapred.child.java.opts
mapreduce.task.io.sort.mb
yarn.app.mapreduce.am.resource.mb
yarn.app.mapreduce.am.command-opts
mapreduce.jobtracker.handler.count
yarn.nodemanager.resource.memory-mb
yarn.scheduler.minimum-allocation-mb
yarn.scheduler.maximum-allocation-mb"


# 获取配置信息
function get_conf()
{
    echo "$conf_keys" | while read conf_key; do
        hdfs getconf -confKey $conf_key
    done | tee hadoop.config.$LOCAL_IP
}

# HDFS写测试
function hdfs_write()
{
    echo "id fileSize Number-of-files Total-MBytes-processed Throughput(mb/sec) Average-IO-rate(mb/sec) IO-rate-std-deviation Test-exec-time(sec)" | tr ' ' '\t' > hdfs-write.report

    echo "$hdfs_write_params" | while read id nrFiles fileSize; do
        clean_test
        $CCMD TestDFSIO -write -nrFiles $nrFiles -size $fileSize -resFile hdfs-write-$id.log
        awk 'BEGIN{ printf("%s\t%s",'$id',"'$fileSize'") } NR > 2 && NR < 9 { printf("\t%s",$NF) } END{ printf("\n") }' hdfs-write-$id.log >> hdfs-write.report
    done
}

# HDFS读测试
function hdfs_read()
{
    echo "id fileSize Number-of-files Total-MBytes-processed Throughput(mb/sec) Average-IO-rate(mb/sec) IO-rate-std-deviation Test-exec-time(sec)" | tr ' ' '\t' > hdfs-read.report

    echo "$hdfs_read_params" | while read id nrFiles fileSize; do
        $CCMD TestDFSIO -read -nrFiles $nrFiles -size $fileSize -resFile hdfs-read-$id.log
        awk 'BEGIN{ printf("%s\t%s",'$id',"'$fileSize'") } NR > 2 && NR < 9 { printf("\t%s",$NF) } END{ printf("\n") }' hdfs-read-$id.log >> hdfs-read.report
    done
}

# 删除测试数据
function clean_test()
{
     hdfs dfs -rm -f -r -skipTrash /benchmarks
}

# NameNode写操作测试
function nn_write()
{
    echo "id maps reduces blockSize numberOfFiles replicationFactorPerFile TPS-Total(ms) Longest-Map-Time(ms) exceptions" | tr ' ' '\t' > nn-write.report

    echo "$nn_write_params" | while read id maps reduces blockSize numberOfFiles replicationFactorPerFile; do
        $CCMD nnbench -operation create_write -maps $maps -reduces $reduces -blocksize $blockSize -numberOfFiles $numberOfFiles -replicationFactorPerFile $replicationFactorPerFile

        (
          echo -e "$id $maps $reduces $blockSize $numberOfFiles $replicationFactorPerFile\c" | tr ' ' '\t'
          grep -e "RAW DATA: TPS Total (ms)" -e "RAW DATA: Longest Map Time (ms)" -e "RAW DATA: # of exceptions" NNBench_results.log | awk '{ printf("\t%s",$NF) } END{ printf("\n") }'
        ) >> nn-write.report

        mv NNBench_results.log nn-write-$id.log
    done
}

# NameNode读操作测试
function nn_read()
{
    echo "id maps reduces numberOfFiles TPS-Total(ms) Longest-Map-Time(ms) exceptions" | tr ' ' '\t' > nn-read.report

    echo "$nn_read_params" | while read id maps reduces numberOfFiles; do
        $CCMD nnbench -operation open_read -maps $maps -reduces $reduces -numberOfFiles $numberOfFiles

        (
          echo -e "$id $maps $reduces $numberOfFiles\c" | tr ' ' '\t'
          grep -e "RAW DATA: TPS Total (ms)" -e "RAW DATA: Longest Map Time (ms)" -e "RAW DATA: # of exceptions" NNBench_results.log | awk '{ printf("\t%s",$NF) } END{ printf("\n") }'
        ) >> nn-read.report

        mv NNBench_results.log nn-read-$id.log
    done
}

function main()
{
    hdfs_write

    hdfs_read

    nn_write

    nn_read
}
main "$@"