#!/bin/bash
#
# Author: superz
# Date: 2015-11-20
# Description: 常用工具类
# Dependency: yum autossh autoscp


source ./config.sh
# 测试环境
if [[ "$LOCAL_IP" =~ 192.168 ]]; then
    source ./config-test.sh
fi


# 记录日志
function log()
{
    echo "$(date +'%F %T') [ $@ ]"
}

# 在方法执行前后记录日志
function log_fn()
{
    log "Call function [ $@ ] begin"
    $@
    log "Call function [ $@ ] end"
}

# 记录详细日志
function debug()
{
    if [[ -n "$debug_flag" && $debug_flag -eq 1 ]]; then
        log "$@"
    fi
}

# 函数功能尚未实现
function todo_fn()
{
    warn "Function: ${FUNCNAME[1]} is yet to be implemented"
}

# 键值对转换成xml标签
# 不包含空行和注释行
function map2xml()
{
    awk -F '=' '$0 !~ /^[[:space:]]*$/ && $0 !~ /^#/ {
        printf("  <property>\n")
        printf("    <name>%s</name>\n",$1)
        printf("    <value>%s</value>\n",$2)
        printf("  </property>\n")
    }'
}

# 生成xml配置
function config_xml()
{
    local xml_file="$1"
    local base_file=`basename $xml_file`
    local prop_file=$CONF_DIR/${base_file/.xml/.cfg}

    # 删除默认配置
    sed -i '/<property>/,/<\/property>/d' $xml_file
    # 删除注释行
    sed -i '/^[[:space:]]*<!--.*-->[[:space:]]*/d' $xml_file

    # 把<configuration>前面的注释拆成单独行
    sed -i 's/\(.\{1,\}\)\(<configuration>\).*/\1\n\2/' $xml_file

    # 键值对转xml
    cat $prop_file | map2xml > ${base_file}.tmp

    # 插入配置信息
    sed -i "/<configuration>/r ${base_file}.tmp" $xml_file

    rm -f ${base_file}.tmp
}

# 执行(本地/远程)命令
function exec_cmd()
{
    debug "Execute command at host: $ip"
    if [[ "$ip" = "$LOCAL_IP" ]]; then
        $@
    else
        autossh "$admin_passwd" ${admin_user}@${ip} "$@"
    fi
}

# 安装环境
function install_env()
{
    # 出错立即退出
    set -e
    # expect wget
    yum -y -q install expect
    yum -y -q install wget

    # 出错不要立即退出
    set +e
    # 删除别名
    unalias cp mv rm

    # 出错立即退出
    set -e
    # autossh autoscp
    if [[ ! -e /usr/bin/autossh ]]; then
        cp -f ${DIR:-`pwd`}/autossh.exp /usr/lib/
        ln -sf /usr/lib/autossh.exp /usr/bin/autossh
        chmod +x /usr/bin/autossh
    fi
    if [[ ! -e /usr/bin/autoscp ]]; then
        cp -f ${DIR:-`pwd`}/autoscp.exp /usr/lib/
        ln -sf /usr/lib/autoscp.exp /usr/bin/autoscp
        chmod +x /usr/bin/autoscp
    fi

    # 出错不要立即退出
    set +e
    # 删除别名
    echo "$HOSTS" | grep -v $LOCAL_IP | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "unalias cp mv rm"
    done
}

# 检测java环境
function check_java()
{
    debug "Check java environment of host: $ip"
    if [[ "$ip" = "$LOCAL_IP" ]]; then
        $JAVA_HOME/bin/java -version
    else
        autossh "$admin_passwd" ${admin_user}@${ip} "$JAVA_HOME/bin/java -version"
    fi
}

# 检测防火墙
function check_firewall()
{
    debug "Check iptables of host: $ip"
    if [[ "$ip" = "$LOCAL_IP" ]]; then
        if [[ $SYS_VERSION =~ ^7 ]]; then
            systemctl status firewalld
        else
            service iptables status
        fi
    else
        if [[ $SYS_VERSION =~ ^7 ]]; then
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl status firewalld"
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "service iptables status"
        fi
    fi

    debug "Check SELinux of host: $ip"
    if [[ "$ip" = "$LOCAL_IP" ]]; then
        sestatus
    else
        autossh "$admin_passwd" ${admin_user}@${ip} "sestatus"
    fi
}

# 关闭防火墙
function stop_firewall()
{
    debug "Stop iptables of host: $ip"
    if [[ "$ip" = "$LOCAL_IP" ]]; then
        if [[ $SYS_VERSION =~ ^7 ]]; then
            systemctl stop firewalld.service
            systemctl disable firewalld.service
        else
            service iptables stop
            chkconfig iptables off
        fi

        # 关闭SELinux
        setenforce 0
        sed -i 's/^\(SELINUX=\).*/\1disabled/' /etc/selinux/config
    else
        if [[ $SYS_VERSION =~ ^7 ]]; then
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl stop firewalld.service"
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl disable firewalld.service"
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "service iptables stop"
            autossh "$admin_passwd" ${admin_user}@${ip} "chkconfig iptables off"
        fi

        autossh "$admin_passwd" ${admin_user}@${ip} "setenforce 0"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i 's/^\(SELINUX=\).*/\1disabled/' /etc/selinux/config"
    fi
}

# 同步时间
function sync_clock()
{
    if [[ "$ip" = "$LOCAL_IP" ]]; then
        # 安装ntpdate
        yum -y -q install ntpdate
        # 系统时钟
        ntpdate $TIME_SERVER
        # 硬件时钟
        hwclock -w
    else
        autossh "$admin_passwd" ${admin_user}@${ip} "yum -y -q install ntpdate"
        autossh "$admin_passwd" ${admin_user}@${ip} "ntpdate $TIME_SERVER"
        autossh "$admin_passwd" ${admin_user}@${ip} "hwclock -w"
    fi
}

# 检测环境
# 1、检测java环境
# 2、关闭防火墙
# 3、同步时间
function detect_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        # 检测java环境
        check_java

        # 关闭防火墙
        stop_firewall || log "Failed to stop iptables of host: $ip"

        # 同步时间
        sync_clock
    done
}

# 安装jdk
function install_jdk()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Install jdk of host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 卸载openjdk
            rpm -qa | grep openjdk | xargs -r rpm -e --nodeps

            $JAVA_HOME/bin/java -version > /dev/null 2>&1 ||
            (
                if [[ `file $JAVA_PKG` =~ RPM ]]; then
                    rpm -i --quiet $JAVA_PKG
                else
                    tar -zxf $JAVA_PKG
                    mkdir -p $JAVA_INSTALL_DIR
                    mv -f $JAVA_NAME $JAVA_INSTALL_DIR
                    ln -snf $JAVA_INSTALL_DIR/$JAVA_NAME $JAVA_HOME
                fi

                sed -i '/^# jdk config start/,/^# jdk config end/d' /etc/profile
                sed -i '$ G' /etc/profile
                sed -i '$ a # jdk config start' /etc/profile
                sed -i "$ a export JAVA_HOME=$JAVA_HOME" /etc/profile
                sed -i "$ a export PATH=\$PATH:\$JAVA_HOME/bin" /etc/profile
                sed -i '$ a # jdk config end' /etc/profile
            )
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "rpm -qa | grep openjdk | xargs -r rpm -e --nodeps"

            autossh "$admin_passwd" ${admin_user}@${ip} "$JAVA_HOME/bin/java -version" > /dev/null 2>&1 ||
            (
                autoscp "$admin_passwd" $JAVA_PKG ${admin_user}@${ip}:$JAVA_PKG
                if [[ `file $JAVA_PKG` =~ RPM ]]; then
                    autossh "$admin_passwd" ${admin_user}@${ip} "rpm -i --quiet $JAVA_PKG"
                else
                    autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $JAVA_PKG"
                    autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $JAVA_INSTALL_DIR"
                    autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $JAVA_NAME $JAVA_INSTALL_DIR"
                    autossh "$admin_passwd" ${admin_user}@${ip} "ln -snf $JAVA_INSTALL_DIR/$JAVA_NAME $JAVA_HOME"
                fi

                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# jdk config start/,/^# jdk config end/d' /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # jdk config start' /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export JAVA_HOME=$JAVA_HOME\" /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$JAVA_HOME/bin\" /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # jdk config end' /etc/profile"
            )
        fi
    done
}

# 安装scala
function install_scala()
{
    # 下载scala
    if [[ ! -f $SCALA_PKG ]]; then
        wget $SCALA_URL
    fi

    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Install scala of host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            $SCALA_HOME/bin/scala -version > /dev/null 2>&1 ||
            (
                tar -zxf $SCALA_PKG
                mkdir -p $SCALA_INSTALL_DIR
                mv -f $SCALA_NAME $SCALA_INSTALL_DIR
                ln -snf $SCALA_INSTALL_DIR/$SCALA_NAME $SCALA_HOME

                sed -i '/^# scala config start/,/^# scala config end/d' /etc/profile
                sed -i '$ G' /etc/profile
                sed -i '$ a # scala config start' /etc/profile
                sed -i "$ a export SCALA_HOME=$SCALA_HOME" /etc/profile
                sed -i "$ a export PATH=\$PATH:\$SCALA_HOME/bin" /etc/profile
                sed -i '$ a # scala config end' /etc/profile
            )
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "$SCALA_HOME/bin/scala -version" > /dev/null 2>&1 ||
            (
                autoscp "$admin_passwd" $SCALA_PKG ${admin_user}@${ip}:~/$SCALA_PKG
                autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $SCALA_PKG"
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $SCALA_INSTALL_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $SCALA_NAME $SCALA_INSTALL_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "ln -snf $SCALA_INSTALL_DIR/$SCALA_NAME $SCALA_HOME"

                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# scala config start/,/^# scala config end/d' /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # scala config start' /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export SCALA_HOME=$SCALA_HOME\" /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$SCALA_HOME/bin\" /etc/profile"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # scala config end' /etc/profile"
            )
        fi
    done
}

# 判断用户是否存在
function exist_user()
{
    grep "^$1:" /etc/passwd
}

# 创建用户
function create_user()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Create user: $THE_USER, group: $THE_GROUP on host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            groupadd -f $THE_GROUP
            if [[ -z `exist_user $THE_USER` ]]; then
                useradd $THE_USER -g $THE_GROUP
            fi
            echo "$owner_passwd" | passwd --stdin $THE_USER
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "groupadd -f $THE_GROUP"
            if [[ -z `exist_user $THE_USER` ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "useradd $THE_USER -g $THE_GROUP"
            fi
            autossh "$admin_passwd" ${admin_user}@${ip} "echo $owner_passwd | passwd --stdin $THE_USER"
        fi
    done
}

# 删除用户
function delete_user()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Delete user: $THE_USER from host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            userdel -rf $THE_USER
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $THE_USER"
        fi
    done
}

# 修改hostname
function modify_hostname()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Modify hostname of host: $ip to: $hostname"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 修改hostname
            sed -i "s/^\(HOSTNAME=\).*/\1${hostname}/i" /etc/sysconfig/network
            # 使之立即生效
            hostname $hostname
        else
            # 修改hostname
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"s/\(HOSTNAME=\).*/\1${hostname}/i\" /etc/sysconfig/network"
            # 使之立即生效
            autossh "$admin_passwd" ${admin_user}@${ip} "hostname $hostname"
        fi
    done
}

# 添加host
function add_host()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        echo "$HOSTS" | while read _ip _hostname _admin_user _admin_passwd _others; do
            debug "Add host record: $_ip $_hostname to host: $ip"
            if [[ "$ip" = "$LOCAL_IP" ]]; then
                # 添加host
                sed -i "/${_ip} ${_hostname}/d" /etc/hosts
                sed -i "$ a ${_ip} ${_hostname}" /etc/hosts
            else
                # 添加host
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"/${_ip} ${_hostname}/d\" /etc/hosts"
                autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a ${_ip} ${_hostname}\" /etc/hosts"
            fi
        done
    done
}

# 备份重要文件
function backup()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        debug "Backup files: /etc/sysconfig/network /etc/hosts /etc/profile of host: $ip"
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            cp -f /etc/sysconfig/network /etc/sysconfig/network.bak
            cp -f /etc/hosts /etc/hosts.bak
            cp -f /etc/profile /etc/profile.bak
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "cp -f /etc/sysconfig/network /etc/sysconfig/network.bak"
            autossh "$admin_passwd" ${admin_user}@${ip} "cp -f /etc/hosts /etc/hosts.bak"
            autossh "$admin_passwd" ${admin_user}@${ip} "cp -f /etc/profile /etc/profile.bak"
        fi
    done
}

# 配置ssh免密码登录
function config_ssh()
{
    # 出错立即退出
    set -e

    # 生成ssh密钥文件，并拷贝远程主机公钥到本地
    debug "Generate ssh key and copy to local host"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Generate ssh key of host: $ip"
        autossh "$owner_passwd" ${THE_USER}@${ip} "rm -rf ~/.ssh/"
        autossh "$owner_passwd" ${THE_USER}@${ip} "ssh-keygen -N '' -t rsa -f ~/.ssh/id_rsa -q"

        if [[ "$ip" != "$LOCAL_IP" ]]; then
            su -l $THE_USER -c "autoscp $owner_passwd ${THE_USER}@${ip}:~/.ssh/id_rsa.pub ~/.ssh/id_rsa.pub.$ip"
            su -l $THE_USER -c "cat ~/.ssh/id_rsa.pub.$ip >> ~/.ssh/id_rsa.pub.merge"

            # 删除临时文件
            su -l $THE_USER -c "rm -f ~/.ssh/id_rsa.pub.$ip"
        fi
    done

    # 合并本地公钥文件
    debug "Merge ssh public key of local host"
    su -l $THE_USER -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/id_rsa.pub.merge"
    su -l $THE_USER -c "cat ~/.ssh/id_rsa.pub.merge >> ~/.ssh/authorized_keys"
    su -l $THE_USER -c "chmod 600 ~/.ssh/authorized_keys"

    # 复制公钥文件到集群中各节点
    debug "Copy ssh public key to remote host of the cluster"
    echo "$HOSTS" | grep -v "$LOCAL_IP" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Copy ssh public key to host: $ip"
        # 复制到远程主机
        su -l $THE_USER -c "autoscp $owner_passwd ~/.ssh/id_rsa.pub.merge ${THE_USER}@${ip}:~/.ssh/"

        # 合并公钥文件
        autossh "$owner_passwd" ${THE_USER}@${ip} "cat ~/.ssh/id_rsa.pub.merge >> ~/.ssh/authorized_keys"
        autossh "$owner_passwd" ${THE_USER}@${ip} "chmod 600 ~/.ssh/authorized_keys"

        # 删除临时文件
        autossh "$owner_passwd" ${THE_USER}@${ip} "rm -f ~/.ssh/id_rsa.pub.merge"
    done
    # 删除临时文件
    su -l $THE_USER -c "rm -f ~/.ssh/id_rsa.pub.merge"

    # 生成known_hosts记录
    debug "Make known hosts record"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        debug "Make known hosts record at host: $ip"
        echo "$HOSTS" | while read _ip _hostname _admin_user _admin_passwd _owner_passwd _others; do
            autossh "$owner_passwd" ${THE_USER}@${ip} "ssh -o StrictHostKeyChecking=no ${THE_USER}@${_hostname} pwd"
        done
    done
}

# 初始化集群
function init()
{
    start
}

# 重启集群
function restart()
{
    stop
    start
}

# 卸载hadoop
function clean_hadoop()
{
    jps="JournalNode|DataNode|NameNode|ResourceManager|DFSZKFailoverController|NodeManager|JobHistoryServer"
    dirs="$HADOOP_HOME $HADOOP_CONF_DIR $HADOOP_TMP_DIR $HADOOP_LOG_DIR $HADOOP_DATA_DIR /tmp/hsperfdata_* /tmp/Jetty_* /tmp/hadoop-* /tmp/*_resources"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $dirs"
        autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $HDFS_USER"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hadoop config start/,/^# hadoop config end/d' /etc/profile"
    done
}

# 卸载zookeeper
function clean_zookeeper()
{
    jps="QuorumPeerMain"
    dirs="$ZK_HOME $ZK_CONF_DIR $ZK_DATA_DIR $ZK_LOG_DIR"
    echo "$HOSTS" | grep zookeeper | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $dirs"
        autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $ZK_USER"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# zookeeper config start/,/^# zookeeper config end/d' /etc/profile"
    done
}

# 卸载hbase
function clean_hbase()
{
    jps="HMaster|HRegionServer"
    dirs="$HBASE_HOME $HBASE_CONF_DIR $HBASE_TMP_DIR $HBASE_LOG_DIR"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $dirs"
        autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $HBASE_USER"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hbase config start/,/^# hbase config end/d' /etc/profile"
    done
}

# 卸载hive
function clean_hive()
{
    jps="HiveMetaStore|HiveServer2"
    dirs="$HIVE_HOME $HIVE_CONF_DIR $HIVE_TMP_DIR $HIVE_LOG_DIR"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $dirs"
        autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $HIVE_USER"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hive config start/,/^# hive config end/d' /etc/profile"
    done
}

# 卸载spark
function clean_spark()
{
    jps="spark.deploy.master.Master|spark.deploy.worker.Worker"
    dirs="$SPARK_HOME $SPARK_CONF_DIR $SPARK_TMP_DIR $SPARK_LOG_DIR"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $dirs"
        autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $SPARK_USER"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# spark config start/,/^# spark config end/d' /etc/profile"
    done
}

# 卸载kafka
function clean_kafka()
{
    jps="kafka.Kafka"
    dirs="$KAFKA_HOME $KAFKA_LOG_DIR"
    echo "$HOSTS" | grep kafka | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $dirs"
        autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $KAFKA_USER"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# kafka config start/,/^# kafka config end/d' /etc/profile"
    done
}

# 卸载storm
function clean_storm()
{
    jps=""
    dirs=""
    echo "$HOSTS" | grep storm | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $dirs"
        autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $STORM_USER"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# storm config start/,/^# storm config end/d' /etc/profile"
    done
}

# 一键清理
function clean_all()
{
    clean_hbase
    clean_hive
    clean_spark
    clean_hadoop
    clean_zookeeper
    clean_kafka
    clean_storm
}

# 打印xml配置
function print_config()
{
    egrep "<name>|<value>" | sed 's/.*<name>\(.*\)<\/name>.*/\1/;s/.*<value>\(.*\)<\/value>.*/\1/' | awk '{if(NR % 2 == 1){printf("%s=",$0)}else{print $0}}'
}
