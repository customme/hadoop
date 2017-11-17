#!/bin/bash
#
# spark±‡“Î
# ”√∑®: nohup ./spark_builder.sh &


export MAVEN_OPTS="-Xmx2g -XX:MaxPermSize=512M -XX:ReservedCodeCacheSize=512m"

./dev/change-scala-version.sh 2.11

cmd="./make-distribution.sh --name hadoop-2.7.3 --tgz -Phadoop-2.7 -Dhadoop.version=2.7.3 -Pyarn -Phive -Phive-thriftserver -Pspark-ganglia-lgpl -DskipTests -Dscala-2.11"

$cmd
result=$?
while [[ $result -ne 0 ]]; do
    $cmd
    result=$?
done
