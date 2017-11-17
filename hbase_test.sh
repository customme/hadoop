#!/bin/bash

# hbase基准测试


table=superz

CCMD="hbase org.apache.hadoop.hbase.PerformanceEvaluation --nomapred --table=$table"

# 写参数
# id rows presplit nclients
write_params="1 10000 10 500
2 100000 50 500
3 1000000 100 500"

# 读参数
# id rows nclients
read_params="1 10000 500
2 100000 500
3 1000000 500"


# 随机写测试
function test_write()
{
    echo "id nclients client rows insert_rows splits time Min Avg StdDev 50th 75th 95th 99th 99.9th 99.99th 99.999th Max" | tr ' ' '\t' > write.report

    echo "$write_params" | while read id rows presplit nclients; do
        echo "disable '$table';drop '$table'" | hbase shell

        $CCMD --rows=$rows --presplit=$presplit randomWrite $nclients > write-$id.log 2>&1

        insert_rows=`echo "count('$table')" | hbase shell | tail -n 1`

        for((i=0;i<$nclients;i++)){
            time=`grep "\[TestClient-${i}\] hbase.PerformanceEvaluation: Finished TestClient-${i} in " write-$id.log | awk '{print $(NF-3)}'`
            latency=`sed -n "/\[TestClient-${i}\] hbase.PerformanceEvaluation: RandomWriteTest Min/,/\[TestClient-${i}\] hbase.PerformanceEvaluation: RandomWriteTest Max/p" write-$id.log | awk '{print $NF}' | head -n 11 | tr '\n' ' '`
            echo "$id $nclients TestClient-${i} $rows $insert_rows $presplit $time $latency" | tr ' ' '\t' >> write.report
        }
    done
}

# 随机读测试
function test_read()
{
    echo "id nclients client rows time Min Avg StdDev 50th 75th 95th 99th 99.9th 99.99th 99.999th Max" | tr ' ' '\t' > read.report

    echo "$read_params" | while read id rows nclients; do
        $CCMD --rows=$rows randomRead $nclients > read-$id.log 2>&1

        for((i=0;i<$nclients;i++)){
            time=`grep "\[TestClient-${i}\] hbase.PerformanceEvaluation: Finished TestClient-${i} in " read-$id.log | awk '{print $(NF-3)}'`
            latency=`sed -n "/\[TestClient-${i}\] hbase.PerformanceEvaluation: RandomReadTest Min/,/\[TestClient-${i}\] hbase.PerformanceEvaluation: RandomReadTest Max/p" read-$id.log | awk '{print $NF}' | head -n 11 | tr '\n' '\t'`
            echo "$id $nclients TestClient-${i} $rows $time $latency" | tr ' ' '\t' >> read.report
        }
    done
}

function main()
{
    test_write

    test_read
}
main "$@"