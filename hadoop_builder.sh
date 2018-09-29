#!/bin/bash
#
# Author: superz
# Date: 2016-03-25
# Description: hadoop-2.7 源码编译
# Dependency: yum


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# 版本
HADOOP_VERSION=2.7.7
JDK_VERSION=1.8.0_181
MAVEN_VERSION=3.5.4
ANT_VERSION=1.10.5
FINDBUGS_VERSION=3.0.1
PROTOBUF_VERSION=2.5.0
SNAPPY_VERSION=1.1.3

# 环境变量
JAVA_HOME=/usr/java/current
MAVEN_HOME=/usr/maven/current
ANT_HOME=/usr/ant/current
FINDBUGS_HOME=/usr/findbugs/current

# hadoop 源码包
HADOOP_SRC_PKG=hadoop-${HADOOP_VERSION}-src.tar.gz
# hadoop 源码包下载地址
HADOOP_SRC_URL=https://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-${HADOOP_VERSION}/$HADOOP_SRC_PKG

# jdk 安装包
JDK_PKG=jdk-8u181-linux-x64.tar.gz

# maven 安装包
MAVEN_PKG=apache-maven-${MAVEN_VERSION}-bin.tar.gz
# maven 安装包下载地址
MAVEN_URL=http://mirrors.cnnic.cn/apache/maven/maven-${MAVEN_VERSION:0:1}/${MAVEN_VERSION}/binaries/$MAVEN_PKG

# ant 安装包
ANT_PKG=apache-ant-${ANT_VERSION}-bin.tar.gz
# ant 安装包下载地址
ANT_URL=http://apache.fayea.com/ant/binaries/$ANT_PKG

# findbugs 安装包
FINDBUGS_PKG=findbugs-${FINDBUGS_VERSION}.tar.gz
# findbugs 安装包下载地址
FINDBUGS_URL=http://tenet.dl.sourceforge.net/project/findbugs/findbugs/${FINDBUGS_VERSION}/$FINDBUGS_PKG

# protobuf 安装包
PROTOBUF_PKG=protobuf-${PROTOBUF_VERSION}.tar.gz

# snappy 安装包
SNAPPY_PKG=snappy-${SNAPPY_VERSION}.tar.gz
# snappy 安装包下载地址
SNAPPY_URL=https://github.com/google/snappy/releases/download/${SNAPPY_VERSION}/$SNAPPY_PKG


# 安装 jdk
function install_jdk()
{
    $JAVA_HOME/bin/java -version > /dev/null 2>&1 ||
    (
        cd $DIR
        if [[ -f $JDK_PKG ]]; then
            # 创建安装目录
            local install_dir=`dirname $JAVA_HOME`
            mkdir -p $install_dir
            # 解压到安装目录
            tar -zxf $JDK_PKG -C $install_dir

            # 创建软连接
            local jdk_name=jdk${JDK_VERSION}
            local base_name=`basename $JAVA_HOME`
            if [[ "$jdk_name" != "$base_name" ]]; then
                ln -snf $install_dir/$jdk_name $JAVA_HOME
            fi

            # 添加环境变量
            sed -i '/^# jdk config start/,/^# jdk config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # jdk config start' /etc/profile
            sed -i "$ a export JAVA_HOME=$JAVA_HOME" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$JAVA_HOME/bin" /etc/profile
            sed -i '$ a # jdk config end' /etc/profile
        else
            log "Can not find jdk $JDK_VERSION package"
            return 1
        fi
    )
}

# 安装 maven
function install_maven()
{
    $MAVEN_HOME/bin/mvn -v > /dev/null 2>&1 ||
    (
        cd $DIR
        if [[ ! -f $MAVEN_PKG ]]; then
            # 下载
            wget $MAVEN_URL
        fi

        # 创建安装目录
        local install_dir=`dirname $MAVEN_HOME`
        mkdir -p $install_dir
        # 解压到安装目录
        tar -zxf $MAVEN_PKG -C $install_dir

        # 创建软连接
        local maven_name=apache-maven-${MAVEN_VERSION}
        local base_name=`basename $MAVEN_HOME`
        if [[ "$maven_name" != "$base_name" ]]; then
            ln -snf $install_dir/$maven_name $MAVEN_HOME
        fi

        # 添加环境变量
        sed -i '/^# maven config start/,/^# maven config end/d' /etc/profile
        sed -i '$ G' /etc/profile
        sed -i '$ a # maven config start' /etc/profile
        sed -i "$ a export MAVEN_HOME=$MAVEN_HOME" /etc/profile
        sed -i "$ a export PATH=\$PATH:\$MAVEN_HOME/bin" /etc/profile
        sed -i '$ a # maven config end' /etc/profile
    )
}

# 安装 ant
function install_ant()
{
    $ANT_HOME/bin/ant -version > /dev/null 2>&1 ||
    (
        cd $DIR
        if [[ ! -f $ANT_PKG ]]; then
            # 下载
            wget $ANT_URL
        fi

        # 创建安装目录
        local install_dir=`dirname $ANT_HOME`
        mkdir -p $install_dir
        # 解压到安装目录
        tar -zxf $ANT_PKG -C $install_dir

        # 创建软连接
        local ant_name=apache-ant-${ANT_VERSION}
        local base_name=`basename $ANT_HOME`
        if [[ "$ant_name" != "$base_name" ]]; then
            ln -snf $install_dir/$ant_name $ANT_HOME
        fi

        # 添加环境变量
        sed -i '/^# ant config start/,/^# ant config end/d' /etc/profile
        sed -i '$ G' /etc/profile
        sed -i '$ a # ant config start' /etc/profile
        sed -i "$ a export ANT_HOME=$ANT_HOME" /etc/profile
        sed -i "$ a export PATH=\$PATH:\$ANT_HOME/bin" /etc/profile
        sed -i '$ a # ant config end' /etc/profile
    )
}

# 安装 findbugs
function install_findbugs()
{
    $FINDBUGS_HOME/bin/findbugs -version > /dev/null 2>&1 ||
    (
        cd $DIR
        if [[ ! -f $FINDBUGS_PKG ]]; then
            # 下载
            wget $FINDBUGS_URL
        fi

        # 创建安装目录
        local install_dir=`dirname $FINDBUGS_HOME`
        mkdir -p $install_dir
        # 解压到安装目录
        tar -zxf $FINDBUGS_PKG -C $install_dir

        # 创建软连接
        local findbugs_name=findbugs-$FINDBUGS_VERSION
        local base_name=`basename $FINDBUGS_HOME`
        if [[ "$findbugs_name" != "$base_name" ]]; then
            ln -snf $install_dir/$findbugs_name $FINDBUGS_HOME
        fi

        # 添加环境变量
        sed -i '/^# findbugs config start/,/^# findbugs config end/d' /etc/profile
        sed -i '$ G' /etc/profile
        sed -i '$ a # findbugs config start' /etc/profile
        sed -i "$ a export FINDBUGS_HOME=$FINDBUGS_HOME" /etc/profile
        sed -i "$ a export PATH=\$PATH:\$FINDBUGS_HOME/bin" /etc/profile
        sed -i '$ a # findbugs config end' /etc/profile
    )
}

# 安装 protobuf
function install_protobuf()
{
    protoc --version > /dev/null 2>&1 ||
    (
        cd $DIR
        if [[ -f $PROTOBUF_PKG ]]; then
            #解压
            tar -zxf $PROTOBUF_PKG
            cd protobuf-$PROTOBUF_VERSION
            # 配置
            ./configure
            # 编译安装
            make && make install
            # 删除编译目录
            cd $DIR
            rm -rf protobuf-$PROTOBUF_VERSION
        else
            log "Can not find protobuf $PROTOBUF_VERSION package"
            return 1
        fi
    )
}

# 安装 snappy
function install_snappy()
{
    if [[ ! -f /usr/local/lib/libsnappy.a ]]; then
        cd $DIR
        if [[ ! -f $SNAPPY_PKG ]]; then
            # 下载
            wget $SNAPPY_URL
        fi

        #解压
        tar -zxf $SNAPPY_PKG
        cd snappy-$SNAPPY_VERSION
        # 配置
        ./configure
        # 编译安装
        make && make install
        # 删除编译目录
        cd $DIR
        rm -rf snappy-$SNAPPY_VERSION
    fi
}

# 安装依赖
function install_deps()
{
    # Native libraries
    yum install -y -q gcc gcc-c++ automake autoconf libtool cmake lzo-devel zlib-devel openssl-devel ncurses-devel wget

    # ProtocolBuffer 2.5.0 (required)
    # 选择源码编译安装
#    yum install -y -q protobuf-devel protobuf-compiler

    # Optional packages
    # Snappy compression
    # 选择源码编译安装
#    yum install -y -q snappy snappy-devel
    # Bzip2
    yum install -y -q bzip2 bzip2-devel
    # Jansson (C Library for JSON)
    yum install -y -q jansson-devel
    # Linux FUSE
    yum install -y -q fuse fuse-devel

    # jdk
    install_jdk

    # maven
    install_maven

    # ant
    install_ant

    # findbugs
    install_findbugs

    # protobuf
    install_protobuf

    # snappy
    install_snappy
}

# 卸载依赖
function remove_deps()
{
    # 卸载 protobuf snappy yum安装包
    rpm -qa | grep -E "protobuf|snappy" | xargs -r rpm -e --nodeps

    # 卸载 protoc 编译安装包
    find /usr/local/lib -name "libprotoc*" | xargs -r rm -rf
    which protoc && rm -f `which protoc`

    # 卸载 snappy 编译安装包
    find /usr/local/lib -name "libsnappy.*" | xargs -r rm -rf

    # 卸载 jdk
    find `dirname $JAVA_HOME` -mindepth 1 -maxdepth 1 -type d -name "*jdk*" | xargs -r rm -rf
    rm -rf $JAVA_HOME

    # 卸载 maven
    find `dirname $MAVEN_HOME` -mindepth 1 -maxdepth 1 -type d -name "*maven*" | xargs -r rm -rf
    rm -rf $MAVEN_HOME

    # 卸载 ant
    find `dirname $ANT_HOME` -mindepth 1 -maxdepth 1 -type d -name "*ant*" | xargs -r rm -rf
    rm -rf $ANT_HOME

    # 卸载 findbugs
    find `dirname $FINDBUGS_HOME` -mindepth 1 -maxdepth 1 -type d -name "*findbugs*" | xargs -r rm -rf
    rm -rf $FINDBUGS_HOME
}

# 编译
function build()
{
    cd $DIR
    if [[ ! -f $HADOOP_SRC_PKG ]]; then
        # 下载
        wget $HADOOP_SRC_URL
    fi

    # 解压
    rm -rf hadoop-${HADOOP_VERSION}-src
    tar -zxf $HADOOP_SRC_PKG
    cd hadoop-${HADOOP_VERSION}-src
    # 编译
    $MAVEN_HOME/bin/mvn clean package -DskipTests -Pdist,native -Dtar -Dbundle.snappy -Dsnappy.lib=/usr/local/lib
    # 拷贝到标准目录
    cp -f hadoop-dist/target/hadoop-${HADOOP_VERSION}.tar.gz /usr/local/src
}

# 验证
function check()
{
    cd $DIR
    hadoop-${HADOOP_VERSION}-src/hadoop-dist/target/hadoop-${HADOOP_VERSION}/bin/hadoop checknative
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-b build hadoop] [-i install dependency] [-u uninstall dependency]"
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    while getopts "bciu" name; do
        case "$name" in
            b)
                build_flag=1;;
            c)
                check_flag=1;;
            i)
                install_flag=1;;
            u)
                uninstall_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 卸载依赖
    [[ $uninstall_flag ]] && remove_deps

    # 安装依赖
    [[ $install_flag ]] && install_deps

    # 编译
    [[ $build_flag ]] && build

    # 验证
    [[ $check_flag ]] && check
}
main "$@"