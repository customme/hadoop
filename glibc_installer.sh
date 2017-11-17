#!/bin/bash
#
# Author: superz
# Date: 2016-03-25
# Description: glibc安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


GLIBC_MIRROR=http://ftp.gnu.org/gnu/glibc
GLIBC_VERSION=2.14
GLIBC_NAME=glibc-$GLIBC_VERSION
GLIBC_PKG=${GLIBC_NAME}.tar.gz
GLIBC_URL=$GLIBC_MIRROR/$GLIBC_PKG


# 安装
function install()
{
    # 下载glibc
    if [[ ! -f $GLIBC_PKG ]]; then
        wget $GLIBC_URL
    fi

    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            yum -y -q install gcc

            tar -zxf $GLIBC_PKG
            mkdir -p ${GLIBC_NAME}-build
            cd ${GLIBC_NAME}-build

            export CFLAGS="-g -O2"
            ../$GLIBC_NAME/configure --prefix=/usr --disable-profile --enable-add-ons --with-headers=/usr/include --with-binutils=/usr/bin

            make && make install
        else
            autoscp "$admin_passwd" $GLIBC_PKG ${admin_user}@${ip}:~/$GLIBC_PKG

            autossh "$admin_passwd" ${admin_user}@${ip} "yum -y -q install gcc"

            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $GLIBC_PKG;mkdir -p ${GLIBC_NAME}-build;cd ${GLIBC_NAME}-build"

            autossh "$admin_passwd" ${admin_user}@${ip} "export CFLAGS=\"-g -O2\";../$GLIBC_NAME/configure --prefix=/usr --disable-profile --enable-add-ons --with-headers=/usr/include --with-binutils=/usr/bin"

            autossh "$admin_passwd" ${admin_user}@${ip} "make && make install"
        fi
    done
}

function main()
{
    install
}
main "$@"