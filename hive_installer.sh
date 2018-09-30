#!/bin/bash
#
# Author: superz
# Date: 2015-12-08
# Description: hive集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# hive集群配置信息
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="10.10.10.61 yygz-61.gzserv.com root 123456 hive123 metastore,hiveserver2
10.10.10.64 yygz-64.gzserv.com root 123456 hive123 metastore,hiveserver2
10.10.10.65 yygz-65.gzserv.com root 123456 hive123 hive-client
10.10.10.66 yygz-66.gzserv.com root 123456 hive123 hive-client
10.10.10.67 yygz-67.gzserv.com root 123456 hive123 hive-client"
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
HOSTS="192.168.1.178 hdpc1-mn01 root 123456 123456 metastore,hiveserver2
192.168.1.179 hdpc1-mn02 root 123456 123456 metastore,hiveserver2
192.168.1.227 hdpc1-sn001 root 123456 123456 hive-client
192.168.1.229 hdpc1-sn002 root 123456 123456 hive-client
192.168.1.230 hdpc1-sn003 root 123456 123456 hive-client"
fi

# hive镜像
HIVE_MIRROR=http://mirror.bit.edu.cn/apache/hive
HIVE_NAME=apache-hive-${HIVE_VERSION}-bin
# hive安装包名
HIVE_PKG=${HIVE_NAME}.tar.gz
# hive安装包下载地址
HIVE_URL=$HIVE_MIRROR/hive-$HIVE_VERSION/$HIVE_PKG

# 当前用户名，所属组
THE_USER=$HIVE_USER
THE_GROUP=$HIVE_GROUP

# hive日志文件名
HIVE_LOG_FILE=hive.log

# 用户hive配置文件目录
CONF_DIR=$CONF_DIR/hive


# 创建hive相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建hive临时文件目录
            if [[ -n "$HIVE_TMP_DIR" ]]; then
                mkdir -p $HIVE_TMP_DIR
                chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_TMP_DIR
                chmod -R g+w $HIVE_TMP_DIR
            fi

            # 创建hive日志文件目录
            if [[ -n "$HIVE_LOG_DIR" ]]; then
                mkdir -p $HIVE_LOG_DIR
                chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_LOG_DIR
            fi
        else
            if [[ -n "$HIVE_TMP_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HIVE_TMP_DIR;chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_TMP_DIR;chmod -R g+w $HIVE_TMP_DIR"
            fi

            if [[ -n "$HIVE_LOG_DIR" ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HIVE_LOG_DIR;chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_LOG_DIR"
            fi
        fi
    done
}

# 设置hive环境变量
function set_env()
{
    debug "Set hive environment variables"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Set hive environment variables at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# hive config start/,/^# hive config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # hive config start' /etc/profile
            sed -i "$ a export HIVE_HOME=$HIVE_HOME" /etc/profile
            sed -i "$ a export HIVE_CONF_DIR=$HIVE_CONF_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$HIVE_HOME/bin" /etc/profile
            sed -i '$ a # hive config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hive config start/,/^# hive config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hive config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HIVE_HOME=$HIVE_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HIVE_CONF_DIR=$HIVE_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$HIVE_HOME/bin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hive config end' /etc/profile"
        fi
    done
}

# hive 配置
function hive_config()
{
    # Server
    echo "
javax.jdo.option.ConnectionURL=jdbc:mysql://yygz-64.gzserv.com:3306/hive?createDatabaseIfNotExist=true
javax.jdo.option.ConnectionDriverName=com.mysql.jdbc.Driver
javax.jdo.option.ConnectionUserName=hive
javax.jdo.option.ConnectionPassword=hive123
hive.metastore.warehouse.dir=$HIVE_DB_DIR
hive.support.concurrency=true
"

    # MetaStore HA
    echo "
hive.cluster.delegation.token.store.class=org.apache.hadoop.hive.thrift.ZooKeeperTokenStore
"

    local zookeepers=`echo "$HOSTS" | awk '$6 ~ /zookeeper/ {printf("%s,",$2)}' | sed 's/,$//'`

    # HiveServer2 HA
    echo "
hive.server2.support.dynamic.service.discovery=true
hive.server2.zookeeper.namespace=hiveserver2
hive.zookeeper.quorum=$zookeepers
hive.zookeeper.session.timeout=1200000
"

    # Client
    echo "
hive.exec.scratchdir=/hive/tmp
hive.exec.local.scratchdir=$HIVE_TMP_DIR
hive.querylog.location=$HIVE_LOG_DIR/query
hive.server2.logging.operation.log.location=$HIVE_LOG_DIR/operation
"

    local metastores=`echo "$HOSTS" | awk '$6 ~ /metastore/ {printf("%s:%s,",$2,"'$HIVE_METASTORE_PORT'")}' | sed 's/,$//'`

    # MetaStore HA
    echo "
hive.metastore.uris=thrift://$metastores
"
}

# 配置hive
function config_hive()
{
    # 修改hive-env.sh
    cp $HIVE_NAME/conf/hive-env.sh.template $HIVE_NAME/conf/hive-env.sh

    # jvm heap
    sed -i "$ a if [[ \"\$SERVICE\" = \"cli\" || \"\$SERVICE\" = \"beeline\" ]]; then" $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   if [ -z \"\$DEBUG\" ]; then" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a     export HADOOP_OPTS=\"\$HADOOP_OPTS ${HIVE_CLIENT_HEAP} -XX:NewRatio=12 -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:+UseParNewGC -XX:-UseGCOverheadLimit\"" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/    /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   else" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a     export HADOOP_OPTS=\"\$HADOOP_OPTS ${HIVE_CLIENT_HEAP} -XX:NewRatio=12 -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:-UseGCOverheadLimit\"" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/    /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   fi" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a elif [ \"\$SERVICE\" = \"metastore\" ]; then" $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   if [ -z \"\$DEBUG\" ]; then" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a     export HADOOP_OPTS=\"\$HADOOP_OPTS ${HIVE_METASTORE_HEAP} -XX:NewRatio=12 -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:+UseParNewGC -XX:-UseGCOverheadLimit\"" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/    /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   else" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a     export HADOOP_OPTS=\"\$HADOOP_OPTS ${HIVE_METASTORE_HEAP} -XX:NewRatio=12 -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:-UseGCOverheadLimit\"" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/    /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   fi" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a elif [ \"\$SERVICE\" = \"hiveserver2\" ]; then" $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   if [ -z \"\$DEBUG\" ]; then" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a     export HADOOP_OPTS=\"\$HADOOP_OPTS ${HIVE_SERVER2_HEAP} -XX:NewRatio=12 -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:+UseParNewGC -XX:-UseGCOverheadLimit\"" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/    /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   else" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a     export HADOOP_OPTS=\"\$HADOOP_OPTS ${HIVE_SERVER2_HEAP} -XX:NewRatio=12 -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:-UseGCOverheadLimit\"" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/    /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a   fi" $HIVE_NAME/conf/hive-env.sh
    sed -i '$s/^/  /' $HIVE_NAME/conf/hive-env.sh
    sed -i "$ a fi" $HIVE_NAME/conf/hive-env.sh

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HIVE_NAME/conf/hive-env.sh

    # 修改bin/hive
    sed -i '/  sparkAssemblyPath/s/^/#/' $HIVE_NAME/bin/hive

    if [[ $HIVE_VERSION =~ ^1 ]]; then
        cp $HIVE_NAME/conf/hive-log4j.properties.template $HIVE_NAME/conf/hive-log4j.properties
        cp $HIVE_NAME/conf/hive-exec-log4j.properties.template $HIVE_NAME/conf/hive-exec-log4j.properties
        cp $HIVE_NAME/conf/beeline-log4j.properties.template $HIVE_NAME/conf/beeline-log4j.properties

        # 日志
        if [[ -n "$HIVE_LOG_DIR" ]]; then
            sed -i "s@\(hive\.log\.dir=\).*@\1${HIVE_LOG_DIR}@" $HIVE_NAME/conf/hive-log4j.properties
            sed -i "s@\(hive\.log\.dir=\).*@\1${HIVE_LOG_DIR}@" $HIVE_NAME/conf/hive-exec-log4j.properties
        fi
    elif [[ $HIVE_VERSION =~ ^2 ]]; then
        cp $HIVE_NAME/conf/hive-log4j2.properties.template $HIVE_NAME/conf/hive-log4j2.properties
        cp $HIVE_NAME/conf/hive-exec-log4j2.properties.template $HIVE_NAME/conf/hive-exec-log4j2.properties
        cp $HIVE_NAME/conf/beeline-log4j2.properties.template $HIVE_NAME/conf/beeline-log4j2.properties
    fi

    # 读取hive-site.cfg文件配置hive-site.xml
    if [[ ! -f $HIVE_NAME/conf/hive-site.xml ]]; then
        cp $HIVE_NAME/conf/hive-default.xml.template $HIVE_NAME/conf/hive-site.xml
    fi
    hive_config | config_xml $HIVE_NAME/conf/hive-site.xml

    # mysql驱动
    ls $LIB_DIR/mysql-connector-java-*.jar | xargs -r -I {} cp {} $HIVE_NAME/lib
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 下载hive
    if [[ ! -f $HIVE_PKG ]]; then
        debug "Download hive from: $HIVE_URL"
        wget $HIVE_URL
    fi

    # 解压hive安装包
    tar -zxf $HIVE_PKG

    # 配置hive
    config_hive

    # 压缩配置好的hive
    mv -f $HIVE_PKG ${HIVE_PKG}.o
    tar -zcf $HIVE_PKG $HIVE_NAME

    # 安装hive
    debug "Install hive"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Install hive at host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建hive安装目录
            mkdir -p $HIVE_INSTALL_DIR

            # 安装hive
            rm -rf $HIVE_INSTALL_DIR/$HIVE_NAME
            mv -f $HIVE_NAME $HIVE_INSTALL_DIR
            chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_INSTALL_DIR
            if [[ `basename $HIVE_HOME` != $HIVE_NAME ]]; then
                ln -snf $HIVE_INSTALL_DIR/$HIVE_NAME $HIVE_HOME
            fi

            # 给hive.log文件授权
            touch $HIVE_LOG_DIR/$HIVE_LOG_FILE
            chmod g+w $HIVE_LOG_DIR/$HIVE_LOG_FILE

            # 配置文件
            if [[ $HIVE_CONF_DIR != $HIVE_HOME/conf ]]; then
                mkdir -p $HIVE_CONF_DIR
                mv -f $HIVE_HOME/conf/* $HIVE_CONF_DIR
                chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_CONF_DIR
            fi
        else
            autoscp "$admin_passwd" $HIVE_PKG ${admin_user}@${ip}:~/$HIVE_PKG
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $HIVE_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HIVE_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HIVE_INSTALL_DIR/$HIVE_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HIVE_NAME $HIVE_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_INSTALL_DIR"
            if [[ `basename $HIVE_HOME` != $HIVE_NAME ]]; then
                autossh "$owner_passwd" ${HIVE_USER}@${ip} "ln -snf $HIVE_INSTALL_DIR/$HIVE_NAME $HIVE_HOME"
            fi

            autossh "$admin_passwd" ${admin_user}@${ip} "touch $HIVE_LOG_DIR/$HIVE_LOG_FILE"
            autossh "$admin_passwd" ${admin_user}@${ip} "chmod g+w $HIVE_LOG_DIR/$HIVE_LOG_FILE"

            if [[ $HIVE_CONF_DIR != $HIVE_HOME/conf ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HIVE_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HIVE_HOME/conf/* $HIVE_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_CONF_DIR"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $HIVE_NAME

    # 创建hive相关目录
    create_dir

    # 设置hive环境变量
    set_env
}

# 初始化
function init()
{
    # 创建临时文件目录
    su -l $HDFS_USER -c "hdfs dfs -mkdir -p /tmp"
    su -l $HDFS_USER -c "hdfs dfs -chmod -R 777 /tmp"

    # 创建hdfs hive数据存储目录
    if [[ -n "$HIVE_DB_DIR" ]]; then
        su -l $HDFS_USER -c "hdfs dfs -mkdir -p $HIVE_DB_DIR"
        su -l $HDFS_USER -c "hdfs dfs -chown -R ${HIVE_USER}:${HIVE_GROUP} $HIVE_DB_DIR"
        su -l $HDFS_USER -c "hdfs dfs -chmod -R g+w $HIVE_DB_DIR"
    fi

    if [[ -n "$YARN_STAG_DIR" ]]; then
        su -l $HDFS_USER -c "hdfs dfs -mkdir -p $YARN_STAG_DIR/$HIVE_USER"
        su -l $HDFS_USER -c "hdfs dfs -chown -R ${HIVE_USER}:${HIVE_GROUP} $YARN_STAG_DIR/$HIVE_USER"
        su -l $HDFS_USER -c "hdfs dfs -chmod -R g+x $YARN_STAG_DIR"
    fi

    # 启动hive集群
    start
}

# 启动hive集群
function start()
{
    # 启动metastore
    debug "Start hive metastore service"
    echo "$HOSTS" | grep metastore | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Start hive metastore service at host: $ip"
        autossh "$owner_passwd" ${HIVE_USER}@${ip} "$HIVE_HOME/bin/hive --service metastore -v"
    done

    # 启动hiveserver2
    debug "Start hive hiveserver2 service"
    echo "$HOSTS" | grep hiveserver2 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Start hive hiveserver2 service at host: $ip"
        autossh "$owner_passwd" ${HIVE_USER}@${ip} "$HIVE_HOME/bin/hive --service hiveserver2"
    done
}

# 停止hive集群
function stop()
{
    debug "Stop hive cluster"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        debug "Stop hive at host: $ip"
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"HiveServer2|HiveMetaStore\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
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
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"HiveMetaStore|HiveServer2\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HIVE_HOME $HIVE_CONF_DIR $HIVE_TMP_DIR $HIVE_LOG_DIR /tmp/hsperfdata_$HIVE_USER /tmp/Jetty_*"
    done
}

# 测试
function test()
{
: '
    # 基本测试
    DROP TABLE IF EXISTS test;
    CREATE TABLE test (id INT, name STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t';
    LOAD DATA LOCAL INPATH 'test.txt' INTO TABLE test;
'

    # hive整合hbase
    # 支持：hive insert select/drop, hbase put/delete
    # 不支持：hive truncate
    aux_jars=`ls $HIVE_HOME/lib/hive-hbase-handler-*.jar`","`ls $HIVE_HOME/lib/zookeeper-*.jar`","`ls $HIVE_HOME/lib/guava-*.jar`
    aux_jars=$aux_jars","`ls $HBASE_HOME/lib/protobuf-java-*.jar`","`ls $HBASE_HOME/lib/hbase-client-*.jar`","`ls $HBASE_HOME/lib/hbase-common-*.jar | grep -v test`
    hive --auxpath $aux_jars -hiveconf hbase.zookeeper.quorum=hdpc1-sn001,hdpc1-sn002,hdpc1-sn003 --hiveconf hive.root.logger=DEBUG,console

'
    CREATE TABLE hbase_hive (key INT, value STRING) STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler' WITH SERDEPROPERTIES ('hbase.columns.mapping' = ':key,cf1:val') TBLPROPERTIES ('hbase.table.name' = 'hive_hbase');

    # 从hive导入数据
    INSERT INTO hbase_hive SELECT id, name FROM test;

    # 从hbase插入数据
    put 'hive_hbase','999','cf1:val','hadoop-2.7.2 + hbase-1.1.3 + hive-1.2.1'
'

    # hive中文乱码问题
'
    -- 修改数据库默认字符集
    ALTER DATABASE hive CHARACTER SET latin1;
    -- 修改字段注释字符集
    ALTER TABLE COLUMNS_V2 MODIFY COLUMN COMMENT VARCHAR(256) CHARACTER SET utf8;
    -- 修改表注释字符集
    ALTER TABLE TABLE_PARAMS MODIFY COLUMN PARAM_VALUE VARCHAR(2000) CHARACTER SET utf8;
    -- 修改分区注释字符集
    ALTER TABLE PARTITION_KEYS MODIFY COLUMN PKEY_COMMENT VARCHAR(2000) CHARACTER SET utf8;
'
}

# 管理
function admin()
{
    ps aux | grep HiveServer2

    # 打印xml配置信息
    print_config < $HIVE_CONF_DIR/hive-site.xml
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