#!/bin/bash
#
# Author: superz
# Date: 2016-03-17
# Description: spark集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# spark集群配置信息
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="10.10.10.61 yygz-61.gzserv.com root 123456 spark123 spark-master
10.10.10.64 yygz-64.gzserv.com root 123456 spark123 spark-master,history-server
10.10.10.65 yygz-65.gzserv.com root 123456 spark123 spark-worker,zookeeper
10.10.10.66 yygz-66.gzserv.com root 123456 spark123 spark-worker,zookeeper
10.10.10.67 yygz-67.gzserv.com root 123456 spark123 spark-worker,zookeeper"
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
HOSTS="192.168.1.178 hdpc1-mn01 root 123456 123456 spark-master
192.168.1.179 hdpc1-mn02 root 123456 123456 spark-master,history-server
192.168.1.227 hdpc1-sn001 root 123456 123456 spark-worker,zookeeper
192.168.1.229 hdpc1-sn002 root 123456 123456 spark-worker,zookeeper
192.168.1.230 hdpc1-sn003 root 123456 123456 spark-worker,zookeeper"
fi

# spark镜像
SPARK_MIRROR=http://mirror.bit.edu.cn/apache/spark
if [[ $HADOOP_VERSION =~ ^2.[23467] ]]; then
    SPARK_NAME=spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION:0:3}
elif [[ $HADOOP_VERSION =~ ^2.5 ]]; then
    SPARK_NAME=spark-${SPARK_VERSION}-bin-hadoop2.4
fi
# spark安装包名
SPARK_PKG=${SPARK_NAME}.tgz
# spark安装包下载地址
SPARK_URL=$SPARK_MIRROR/spark-$SPARK_VERSION/$SPARK_PKG

# 相关目录
SPARK_WORKER_DIR=$SPARK_LOG_DIR
SPARK_PID_DIR=$SPARK_TMP_DIR
# master恢复信息目录
SPARK_RECOVERY_DIR=$SPARK_TMP_DIR
# 应用程序日志目录
SPARK_HISTORY_LOG_DIR=hdfs://$NAMESERVICE_ID/spark/log/app

# master恢复模式
SPARK_RECOVERY_MODE=ZOOKEEPER

# 当前用户名，所属组
THE_USER=$SPARK_USER
THE_GROUP=$SPARK_GROUP

# 用户spark配置文件目录
CONF_DIR=$CONF_DIR/spark


# 创建spark相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建spark临时文件目录
            if [[ -n "$SPARK_TMP_DIR" ]]; then
                mkdir -p $SPARK_TMP_DIR
                chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_TMP_DIR
            fi

            # 创建spark日志文件目录
            if [[ -n "$SPARK_LOG_DIR" ]]; then
                mkdir -p $SPARK_LOG_DIR
                chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_LOG_DIR
            fi
        else
            if [[ -n "$SPARK_TMP_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $SPARK_TMP_DIR;chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_TMP_DIR"
            fi

            if [[ -n "$SPARK_LOG_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $SPARK_LOG_DIR;chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_LOG_DIR"
            fi
        fi
    done
}

# 设置spark环境变量
function set_env()
{
    debug "Set spark environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set spark environment variables at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# spark config start/,/^# spark config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # spark config start' /etc/profile
            sed -i "$ a export SPARK_HOME=$SPARK_HOME" /etc/profile
            sed -i "$ a export SPARK_CONF_DIR=$SPARK_CONF_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" /etc/profile
            sed -i '$ a # spark config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# spark config start/,/^# spark config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # spark config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export SPARK_HOME=$SPARK_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export SPARK_CONF_DIR=$SPARK_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$SPARK_HOME/bin:\\\$SPARK_HOME/sbin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # spark config end' /etc/profile"
        fi
    done
}

# 配置spark
function config_spark()
{
    # 修改spark-env.sh
    if [[ ! -f $SPARK_NAME/conf/spark-env.sh ]]; then
        cp $SPARK_NAME/conf/spark-env.sh.template $SPARK_NAME/conf/spark-env.sh
    fi
    sed -i '$ G' $SPARK_NAME/conf/spark-env.sh
    sed -i "$ a export JAVA_HOME=$JAVA_HOME" $SPARK_NAME/conf/spark-env.sh
    sed -i "$ a export SCALA_HOME=$SCALA_HOME" $SPARK_NAME/conf/spark-env.sh

    # log/pid directory
    sed -i '$ G' $SPARK_NAME/conf/spark-env.sh
    if [[ -n "$SPARK_LOG_DIR" ]]; then
        sed -i "$ a export SPARK_LOG_DIR=$SPARK_LOG_DIR" $SPARK_NAME/conf/spark-env.sh
    fi
    if [[ -n "$SPARK_WORKER_DIR" ]]; then
        sed -i "$ a export SPARK_WORKER_DIR=$SPARK_WORKER_DIR" $SPARK_NAME/conf/spark-env.sh
    fi
    if [[ -n "$SPARK_PID_DIR" ]]; then
        sed -i "$ a export SPARK_PID_DIR=$SPARK_PID_DIR" $SPARK_NAME/conf/spark-env.sh
    fi

    # master HA
    sed -i '$ G' $SPARK_NAME/conf/spark-env.sh
    if [[ "$SPARK_RECOVERY_MODE" = ZOOKEEPER ]]; then
        zk_url=`echo "$HOSTS" | awk '$0 ~ /zookeeper/ {printf("%s:%s,",$2,'$ZK_SERVER_PORT')}' | sed 's/,$//'`
        sed -i "$ a export SPARK_DAEMON_JAVA_OPTS=\"-Dspark.deploy.recoveryMode=ZOOKEEPER -Dspark.deploy.zookeeper.url=$zk_url\"" $SPARK_NAME/conf/spark-env.sh
    else
        # 本地文件
        if [[ "$SPARK_RECOVERY_MODE" = FILESYSTEM ]]; then
            sed -i "$ a export SPARK_DAEMON_JAVA_OPTS=\"-Dspark.deploy.recoveryMode=FILESYSTEM -Dspark.deploy.recoveryDirectory=$SPARK_RECOVERY_DIR\"" $SPARK_NAME/conf/spark-env.sh
        fi
        SPARK_MASTER_IP=`echo "$HOSTS" | awk '$0 ~ /spark-master/ {print $2}'`
        sed -i "$ a export SPARK_MASTER_IP=$SPARK_MASTER_IP" $SPARK_NAME/conf/spark-env.sh
    fi

    # history server
    sed -i "$ a \\\nexport SPARK_HISTORY_OPTS=\"-Dspark.history.fs.logDirectory=$SPARK_HISTORY_LOG_DIR\"" $SPARK_NAME/conf/spark-env.sh

    # hive
    sed -i "$ a \\\nexport HIVE_HOME=$HIVE_HOME" $SPARK_NAME/conf/spark-env.sh

    # hadoop
    sed -i "$ a export HADOOP_HOME=$HADOOP_HOME" $SPARK_NAME/conf/spark-env.sh
    sed -i "$ a export HADOOP_CONF_DIR=$HADOOP_CONF_DIR" $SPARK_NAME/conf/spark-env.sh

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $SPARK_NAME/conf/spark-env.sh

    # spark-defaults.conf
    cp $SPARK_NAME/conf/spark-defaults.conf.template $SPARK_NAME/conf/spark-defaults.conf

    # log4j
    cp $SPARK_NAME/conf/log4j.properties.template $SPARK_NAME/conf/log4j.properties

    # 添加slaves
    echo "$HOSTS" | awk '$0 ~ /spark-worker/ {print $2}' > $SPARK_NAME/conf/slaves
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载spark
    if [[ ! -f $SPARK_PKG ]]; then
        debug "Download spark from: $SPARK_URL"
        wget $SPARK_URL
    fi

    # 解压spark安装包
    tar -zxf $SPARK_PKG

    # 配置spark
    config_spark

    # 压缩配置好的spark
    mv -f $SPARK_PKG ${SPARK_PKG}.o
    tar -zcf $SPARK_PKG $SPARK_NAME

    # 安装spark
    debug "Install spark"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Install spark at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建spark安装目录
            mkdir -p $SPARK_INSTALL_DIR

            # 安装spark
            rm -rf $SPARK_INSTALL_DIR/$SPARK_NAME
            mv -f $SPARK_NAME $SPARK_INSTALL_DIR
            chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_INSTALL_DIR
            if [[ `basename $SPARK_HOME` != $SPARK_NAME ]]; then
                su -l $SPARK_USER -c "ln -snf $SPARK_INSTALL_DIR/$SPARK_NAME $SPARK_HOME"
            fi

            # 配置文件
            if [[ $SPARK_CONF_DIR != $SPARK_HOME/conf ]]; then
                mkdir -p $SPARK_CONF_DIR
                mv -f $SPARK_HOME/conf/* $SPARK_CONF_DIR
                chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_CONF_DIR
            fi
            su -l $SPARK_USER -c "ln -sf $HIVE_CONF_DIR/hive-site.xml $SPARK_CONF_DIR/hive-site.xml"
        else
            autoscp "$admin_passwd" $SPARK_PKG ${admin_user}@${ip}:~/$SPARK_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $SPARK_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $SPARK_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $SPARK_INSTALL_DIR/$SPARK_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $SPARK_NAME $SPARK_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_INSTALL_DIR"
            if [[ `basename $SPARK_HOME` != $SPARK_NAME ]]; then
                autossh "$owner_passwd" ${SPARK_USER}@${ip} "ln -snf $SPARK_INSTALL_DIR/$SPARK_NAME $SPARK_HOME"
            fi

            if [[ $SPARK_CONF_DIR != $SPARK_HOME/conf ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $SPARK_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $SPARK_HOME/conf/* $SPARK_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_CONF_DIR"
            fi
            autossh "$owner_passwd" ${SPARK_USER}@${ip} "ln -sf $HIVE_CONF_DIR/hive-site.xml $SPARK_CONF_DIR/hive-site.xml"
        fi
    done

    # 删除安装文件
    rm -rf $SPARK_NAME

    # 创建spark相关目录
    create_dir

    # 设置spark环境变量
    set_env
}

# 初始化
function init()
{
    if [[ -n "$YARN_STAG_DIR" ]]; then
        su -l $HDFS_USER -c "hdfs dfs -mkdir -p $YARN_STAG_DIR/$SPARK_USER"
        su -l $HDFS_USER -c "hdfs dfs -chown -R ${SPARK_USER}:${SPARK_GROUP} $YARN_STAG_DIR/$SPARK_USER"
        su -l $HDFS_USER -c "hdfs dfs -chmod -R g+x $YARN_STAG_DIR"
    fi

    if [[ -n "$SPARK_HISTORY_LOG_DIR" ]]; then
        su -l $HDFS_USER -c "hdfs dfs -mkdir -p $SPARK_HISTORY_LOG_DIR"
        su -l $HDFS_USER -c "hdfs dfs -chown -R ${SPARK_USER}:${SPARK_GROUP} $SPARK_HISTORY_LOG_DIR"

        sed -i "$ a spark.eventLog.enabled           true" $SPARK_NAME/conf/spark-defaults.conf
        sed -i "$ a spark.eventLog.dir               $SPARK_HISTORY_LOG_DIR" $SPARK_NAME/conf/spark-defaults.conf
        sed -i "$ a spark.eventLog.compress          true" $SPARK_NAME/conf/spark-defaults.conf
    fi

    # 启动spark集群
    start
}

# 启动spark集群
function start()
{
    # 启动master和slaves
    debug "Start spark master and slaves"
    echo "$HOSTS" | grep spark-master | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${SPARK_USER}@${ip} "$SPARK_HOME/sbin/start-all.sh"
    done

    # 启动standby master
    debug "Start spark standby masters"
    echo "$HOSTS" | grep spark-master | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Start spark standby master at host: $ip"
        autossh "$owner_passwd" ${SPARK_USER}@${ip} "$SPARK_HOME/sbin/start-master.sh"
    done

    # 启动history server
    debug "Start spark history server"
    echo "$HOSTS" | grep history-server | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${SPARK_USER}@${ip} "$SPARK_HOME/sbin/start-history-server.sh"
    done
}

# 停止spark集群
function stop()
{
    # 停止master和slaves
    debug "Stop spark master and slaves"
    echo "$HOSTS" | grep spark-master | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${SPARK_USER}@${ip} "$SPARK_HOME/sbin/stop-all.sh"
    done

    # 停止standby master
    debug "Stop spark standby masters"
    echo "$HOSTS" | grep spark-master | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Stop spark standby master at host: $ip"
        autossh "$owner_passwd" ${SPARK_USER}@${ip} "$SPARK_HOME/sbin/stop-master.sh"
    done

    # 停止history server
    debug "Stop spark history server"
    echo "$HOSTS" | grep history-server | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Stop spark history server at host: $ip"
        autossh "$owner_passwd" ${SPARK_USER}@${ip} "$SPARK_HOME/sbin/stop-history-server.sh"
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-c create user<add/delete>] [-h config host<hostname,hosts>] [-i install] [-k config ssh] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"spark.deploy.master.Master|spark.deploy.worker.Worker\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $SPARK_HOME $SPARK_CONF_DIR $SPARK_TMP_DIR $SPARK_LOG_DIR /tmp/hsperfdata_$SPARK_USER /tmp/Jetty_*"
    done
}

# 测试
function test()
{
    # run application locally on 2 cores
    spark-submit --master local[2] --class org.apache.spark.examples.SparkPi --name Spark-Pi $SPARK_HOME/lib/spark-examples-${SPARK_VERSION}-hadoop2.6.0.jar

    # run on a spark standalone cluster in client deploy mode
    spark-submit --master spark://hdpc1-mn02:7077 --class org.apache.spark.examples.SparkPi --name Spark-Pi $SPARK_HOME/lib/spark-examples-${SPARK_VERSION}-hadoop2.6.0.jar

    # run on a spark standalone cluster in cluster deploy mode
    spark-submit --master spark://hdpc1-mn02:7077 --deploy-mode cluster --class org.apache.spark.examples.SparkPi --name Spark-Pi $SPARK_HOME/lib/spark-examples-${SPARK_VERSION}-hadoop2.6.0.jar

    # spark on yarn cluster
    spark-submit --master yarn-cluster --class org.apache.spark.examples.SparkLR --name SparkLR $SPARK_HOME/lib/spark-examples-${SPARK_VERSION}-hadoop2.6.0.jar

    # spark on yarn client
    spark-shell --master yarn-client

    # spark sql with hive（以hive用户运行）
    drivers=`ls $HIVE_HOME/lib/mysql-connector-java-*.jar`
    spark-sql --driver-class-path $drivers
}

# 管理
function admin()
{
    ps aux | egrep "spark.deploy.master.Master|spark.deploy.worker.Worker"

    # Master WebUI: http://hdpc1-mn02:8080/
    # Worker WebUI: http://hdpc1-sn001:4040/
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
    # -k 配置ssh免密码登录
    # -s [init/start/stop/restart] 启动/停止集群
    # -v debug模式
    while getopts "c:h:iks:v" name; do
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
            k)
                ssh_flag=1;;
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

    # 配置ssh免密码登录
    [[ $ssh_flag ]] && log_fn config_ssh

    # 安装scala
    log_fn install_scala

    # 安装集群
    [[ $install_flag ]] && log_fn install

    # 启动集群
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"