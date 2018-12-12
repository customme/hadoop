#!/bin/bash
#
# Author: superz
# Date: 2016-08-05
# Description: kafka集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# kafka安装包名
KAFKA_NAME=kafka_${SCALA_VERSION%.*}-$KAFKA_VERSION
KAFKA_PKG=${KAFKA_NAME}.tgz
# kafka安装包下载地址
KAFKA_URL=http://mirror.bit.edu.cn/apache/kafka/$KAFKA_VERSION/$KAFKA_PKG

# kafka集群配置信息
# ip hostname admin_user admin_passwd owner_passwd id
HOSTS="10.10.10.65 yygz-65.gzserv.com root 123456 kafka123 0
10.10.10.66 yygz-66.gzserv.com root 123456 kafka123 1
10.10.10.67 yygz-67.gzserv.com root 123456 kafka123 2"

# 相关目录
KAFKA_PID_DIR=$KAFKA_TMP_DIR

# 当前用户名，所属组
THE_USER=$KAFKA_USER
THE_GROUP=$KAFKA_GROUP


# 创建kafka相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd id; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 修改broker.id host.name
            sed -i "s/\(broker.id=\).*/\1${id}/" $KAFKA_HOME/config/server.properties
            sed -i "/broker.id=/ a\host.name=${hostname}" $KAFKA_HOME/config/server.properties

            # 创建kafka日志文件目录
            if [[ -n "$KAFKA_LOG_DIR" ]]; then
                mkdir -p $KAFKA_LOG_DIR
                chown -R ${KAFKA_USER}:${KAFKA_GROUP} $KAFKA_LOG_DIR
            fi

            # 创建kafka临时文件目录
            if [[ -n "$KAFKA_TMP_DIR" ]]; then
                mkdir -p $KAFKA_TMP_DIR
                chown -R ${KAFKA_USER}:${KAFKA_GROUP} $KAFKA_TMP_DIR
            fi
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"s/\(broker.id=\).*/\1${id}/\" $KAFKA_HOME/config/server.properties"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"/broker.id=/ a\host.name=${hostname}\" $KAFKA_HOME/config/server.properties"

            if [[ -n "$KAFKA_LOG_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $KAFKA_LOG_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${KAFKA_USER}:${KAFKA_GROUP} $KAFKA_LOG_DIR"
            fi

            if [[ -n "$KAFKA_TMP_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $KAFKA_TMP_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${KAFKA_USER}:${KAFKA_GROUP} $KAFKA_TMP_DIR"
            fi
        fi
    done
}

# 设置kafka环境变量
function set_env()
{
    debug "Set kafka environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set kafka environment variables at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# kafka config start/,/^# kafka config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # kafka config start' /etc/profile
            sed -i "$ a export KAFKA_HOME=$KAFKA_HOME" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$KAFKA_HOME/bin" /etc/profile
            sed -i '$ a # kafka config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# kafka config start/,/^# kafka config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # kafka config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export KAFKA_HOME=$KAFKA_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$KAFKA_HOME/bin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # kafka config end' /etc/profile"
        fi
    done
}

# kafka 配置
function kafka_config()
{
    echo "
broker.id=0
listeners=PLAINTEXT://:$KAFKA_SERVER_PORT
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=$KAFKA_LOG_DIR
num.partitions=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=yygz-65.gzserv.com:2181,yygz-66.gzserv.com:2181,yygz-67.gzserv.com:2181
zookeeper.connection.timeout.ms=6000
group.initial.rebalance.delay.ms=0
auto.create.topics.enable=false
delete.topic.enable=true
"
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载kafka
    if [[ ! -f $KAFKA_PKG ]]; then
        debug "Download kafka from: $KAFKA_URL"
        wget $KAFKA_URL
    fi

    # 解压kafka安装包
    tar -zxf $KAFKA_PKG

    # 配置 server.properties
    kafka_config > $KAFKA_NAME/config/server.properties

    sed -i "/\$LOG_DIR/ i\export LOG_DIR=${KAFKA_LOG_DIR}" $KAFKA_NAME/bin/kafka-run-class.sh
    if [[ -n "$KAFKA_PID_DIR" ]]; then
        sed -i "$ a export PID_DIR=${KAFKA_PID_DIR}" $KAFKA_NAME/bin/kafka-server-start.sh
    fi
    if [[ -n "$KAFKA_SERVER_HEAP" ]]; then
        sed -i "/[^ ]KAFKA_HEAP_OPTS/ i\\\nexport KAFKA_HEAP_OPTS=\"${KAFKA_SERVER_HEAP}\"" $KAFKA_NAME/bin/kafka-server-start.sh
    fi

    # 压缩配置好的kafka
    mv -f $KAFKA_PKG ${KAFKA_PKG}.o
    tar -zcf $KAFKA_PKG $KAFKA_NAME

    # 安装kafka
    debug "Install kafka"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd id; do
        debug "Install kafka at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建kafka安装目录
            mkdir -p $KAFKA_INSTALL_DIR

            # 安装kafka
            rm -rf $KAFKA_INSTALL_DIR/$KAFKA_NAME
            mv -f $KAFKA_NAME $KAFKA_INSTALL_DIR
            chown -R ${KAFKA_USER}:${KAFKA_GROUP} $KAFKA_INSTALL_DIR
            if [[ `basename $KAFKA_HOME` != $KAFKA_NAME ]]; then
                su -l $KAFKA_USER -c "ln -snf $KAFKA_INSTALL_DIR/$KAFKA_NAME $KAFKA_HOME"
            fi
        else
            autoscp "$admin_passwd" $KAFKA_PKG ${admin_user}@${ip}:~/$KAFKA_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $KAFKA_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $KAFKA_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $KAFKA_INSTALL_DIR/$KAFKA_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $KAFKA_NAME $KAFKA_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${KAFKA_USER}:${KAFKA_GROUP} $KAFKA_INSTALL_DIR"
            if [[ `basename $KAFKA_HOME` != $KAFKA_NAME ]]; then
                autossh "$owner_passwd" ${KAFKA_USER}@${ip} "ln -snf $KAFKA_INSTALL_DIR/$KAFKA_NAME $KAFKA_HOME"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $KAFKA_NAME

    # 创建kafka相关目录
    create_dir

    # 设置kafka环境变量
    set_env
}

# 启动kafka集群
function start()
{
    debug "Start kafka cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd id; do
        debug "Start kafka at host: $ip"
        autossh "$owner_passwd" ${KAFKA_USER}@${ip} "nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > $KAFKA_LOG_DIR/kafka.out 2>&1 &"
    done
}

# 停止kafka集群
function stop()
{
    debug "Stop kafka cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd id; do
        debug "Stop kafka at host: $ip"
        autossh "$owner_passwd" ${KAFKA_USER}@${ip} "$KAFKA_HOME/bin/kafka-server-stop.sh"
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-c create user<add/delete>] [-h config host<hostname,hosts>] [-i install] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"kafka.Kafka\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $KAFKA_HOME $KAFKA_LOG_DIR /tmp/hsperfdata_$KAFKA_USER"
    done
}

# 管理
function admin()
{
    broker_list=hdpc1-sn001:9092,hdpc1-sn002:9092,hdpc1-sn003:9092
    zk_list=hdpc1-sn001:2181,hdpc1-sn002:2181,hdpc1-sn003:2181

    # 列出所有topic
    $KAFKA_HOME/bin/kafka-topics.sh --list --zookeeper $zk_list

    # 创建topic
    $KAFKA_HOME/bin/kafka-topics.sh --create --replication-factor 2 --partitions 3 --topic test --zookeeper $zk_list

    # 查看topic详细
    $KAFKA_HOME/bin/kafka-topics.sh --describe --topic test --zookeeper $zk_list

    # 删除topic
    $KAFKA_HOME/bin/kafka-topics.sh --delete --topic test --zookeeper $zk_list
    # 删除kafka文件存储目录
    rm -rf /tmp/kafka-logs/test
    # 删除zookeeper节点(如果delete.topic.enable=false)
    echo "rmr /brokers/topics/test" | zkCli.sh
    echo "delete /config/topics/test" | zkCli.sh
    # 查看已删除topic
    echo "ls /admin/delete_topics" | zkCli.sh

    # 查看topic的offset最小值/最大值
    $KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list $broker_list --topic test --time -2
    $KAFKA_HOME/bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list $broker_list --topic test --time -1

    # 增加partition(kafka不支持减少partition的数量)
    $KAFKA_HOME/bin/kafka-topics.sh --alter --topic test --partitions 4 --zookeeper $zk_list

    # 修改topic配置
    $KAFKA_HOME/bin/kafka-topics.sh --alter --topic test --config max.message.bytes=128000 --zookeeper $zk_list

    # producer发送消息
    $KAFKA_HOME/bin/kafka-console-producer.sh --broker-list $broker_list --topic test

    # consumer接收消息
    $KAFKA_HOME/bin/kafka-console-consumer.sh --zookeeper $zk_list --topic test --from-beginning
    # 新版
    $KAFKA_HOME/bin/kafka-console-consumer.sh --bootstrap-server $broker_list --topic test --from-beginning

    # 列出消费者组
    $KAFKA_HOME/bin/kafka-consumer-groups.sh --bootstrap-server $broker_list --list

    # 查看消费组
    $KAFKA_HOME/bin/kafka-consumer-groups.sh --bootstrap-server $broker_list --describe --group group
    $KAFKA_HOME/bin/kafka-consumer-groups.sh --bootstrap-server $broker_list --describe --group group --members
    $KAFKA_HOME/bin/kafka-consumer-groups.sh --bootstrap-server $broker_list --describe --group group --members --verbose

    # 查看消费的offset(已废弃)
    $KAFKA_HOME/bin/kafka-console-consumer.sh --bootstrap-server $broker_list --topic __consumer_offsets --formatter "kafka.coordinator.GroupMetadataManager\$OffsetsMessageFormatter" --from-beginning
    $KAFKA_HOME/bin/kafka-consumer-groups.sh --bootstrap-server $broker_list --describe --group group --offsets --verbose

    # 重置offset
    $KAFKA_HOME/bin/kafka-consumer-groups.sh --bootstrap-server $broker_list --group group --reset-offsets --execute --to-earliest --all-topics

    # kafka底层消费
    $KAFKA_HOME/bin/kafka-simple-consumer-shell.sh --broker-list $broker_list --partition 1 --offset 4 --max-messages 3 --topic test

    # 写性能测试
    $KAFKA_HOME/bin/kafka-producer-perf-test.sh --broker-list $broker_list --batch-size 1 --message-size 1024 --messages 10000 --sync --topics test
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -c [add/delete] 创建用户
    # -h [hostname,hosts] 配置host
    # -i 安装集群
    # -s [init/start/stop/restart] 启动/停止集群
    # -v debug模式
    while getopts "c:h:is:v" name; do
        case "$name" in
            c)
                local command="$OPTARG"
                if [[ "$command" = "delete" ]]; then
                    delete_flag=1
                fi
                create_flag=1;;
            h)
                local $command="$OPTARG"
                if [[ "$command" = "hostname" ]]; then
                    hostname_flag=1
                fi
                hosts_flag=1;;
            i)
                install_flag=1;;
            s)
                start_cmd="$OPTARG";;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 安装环境
    install_env

    # 删除用户
    [[ $delete_flag ]] && log_fn delete_user
    # 创建用户
    [[ $create_flag ]] && log_fn create_user

    # 配置host
    [[ $hostname_flag ]] && log_fn modify_hostname
    [[ $hosts_flag ]] && log_fn add_host

    # 安装集群
    [[ $install_flag ]] && log_fn install

    # 启动集群
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"