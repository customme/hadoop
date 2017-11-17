#!/bin/bash
#
# Author: superz
# Date: 2016-03-25
# Description: hadoop编译
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
MAVEN_VERSION=3.5.0
ANT_VERSION=1.9.9
FINDBUGS_VERSION=3.0.1
PROTOBUF_VERSION=2.5.0

# 安装目录
MAVEN_INSTALL_DIR=$BASE_INSTALL_DIR/maven
ANT_INSTALL_DIR=$BASE_INSTALL_DIR/ant
FINDBUGS_INSTALL_DIR=$BASE_INSTALL_DIR/findbugs

# 环境变量
MAVEN_HOME=$MAVEN_INSTALL_DIR/current
ANT_HOME=$ANT_INSTALL_DIR/ant/current
FINDBUGS_HOME=$FINDBUGS_INSTALL_DIR/current

# maven安装包
MAVEN_NAME=apache-maven-${MAVEN_VERSION}
MAVEN_PKG=${MAVEN_NAME}-bin.tar.gz
MAVEN_URL=http://mirrors.cnnic.cn/apache/maven/maven-${MAVEN_VERSION:0:1}/${MAVEN_VERSION}/binaries/$MAVEN_PKG

# ant安装包
ANT_NAME=apache-ant-${ANT_VERSION}
ANT_PKG=${ANT_NAME}-bin.tar.gz
ANT_URL=http://apache.fayea.com//ant/binaries/$ANT_PKG

# findbugs安装包
FINDBUGS_NAME=findbugs-$FINDBUGS_VERSION
FINDBUGS_PKG=${FINDBUGS_NAME}.tar.gz
FINDBUGS_URL=http://tenet.dl.sourceforge.net/project/findbugs/findbugs/${FINDBUGS_VERSION}/$FINDBUGS_PKG

# protobuf安装包
PROTOBUF_NAME=protobuf-$PROTOBUF_VERSION
PROTOBUF_PKG=${PROTOBUF_NAME}.tar.gz


# 安装
function install()
{
    yum -y -q install gcc gcc-c++ cmake lzo-devel zlib-devel openssl-devel ncurses-devel automake autoconf libtool bzip2 libbz2-dev

    # maven
    if [[ ! -f $MAVEN_PKG ]]; then
        wget $MAVEN_URL

        tar -zxf $MAVEN_PKG
        mkdir -p $MAVEN_INSTALL_DIR
        mv -f $MAVEN_NAME $MAVEN_INSTALL_DIR
        ln -snf $MAVEN_INSTALL_DIR/$MAVEN_NAME $MAVEN_HOME

        sed -i '/^# maven config start/,/^# maven config end/d' /etc/profile
        sed -i '$ G' /etc/profile
        sed -i '$ a # maven config start' /etc/profile
        sed -i "$ a export MAVEN_HOME=$MAVEN_HOME" /etc/profile
        sed -i "$ a export PATH=\$PATH:\$MAVEN_HOME/bin" /etc/profile
        sed -i '$ a # maven config end' /etc/profile
    fi

    # ant
    if [[ ! -f $ANT_PKG ]]; then
        wget $ANT_URL

        tar -zxf $ANT_PKG
        mkdir -p $ANT_INSTALL_DIR
        mv -f $ANT_NAME $ANT_INSTALL_DIR
        ln -snf $ANT_INSTALL_DIR/$ANT_NAME $ANT_HOME

        sed -i '/^# ant config start/,/^# ant config end/d' /etc/profile
        sed -i '$ G' /etc/profile
        sed -i '$ a # ant config start' /etc/profile
        sed -i "$ a export ANT_HOME=$ANT_HOME" /etc/profile
        sed -i "$ a export PATH=\$PATH:\$ANT_HOME/bin" /etc/profile
        sed -i '$ a # ant config end' /etc/profile
    fi

    # findbugs
    if [[ ! -f $FINDBUGS_PKG ]]; then
        wget $FINDBUGS_URL

        tar -zxf $FINDBUGS_PKG
        mkdir -p $FINDBUGS_INSTALL_DIR
        mv -f $FINDBUGS_NAME $FINDBUGS_INSTALL_DIR
        ln -snf $FINDBUGS_INSTALL_DIR/$FINDBUGS_NAME $FINDBUGS_HOME

        sed -i '/^# findbugs config start/,/^# findbugs config end/d' /etc/profile
        sed -i '$ G' /etc/profile
        sed -i '$ a # findbugs config start' /etc/profile
        sed -i "$ a export FINDBUGS_HOME=$FINDBUGS_HOME" /etc/profile
        sed -i "$ a export PATH=\$PATH:\$FINDBUGS_HOME/bin" /etc/profile
        sed -i '$ a # findbugs config end' /etc/profile
    fi

    # protobuf
    if [[ -f $PROTOBUF_PKG ]]; then
        tar -zxf $PROTOBUF_PKG

        cd $PROTOBUF_NAME
        ./configure
        make && make install
    fi
}

# 构建
function build()
{
    mvn clean package -DskipTests -Pdist,native,docs -Dtar -Dsnappy.lib=/usr/local/lib -Dbundle.snappy
}

function main()
{
    install

    build
}
main "$@"