#!/bin/bash
#
# hadoop集群迁移


source /etc/profile
source ~/.bash_profile


# 本机ip
LOCAL_IP=`ifconfig eth0 2> /dev/null | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1`
if [[ -z "$LOCAL_IP" ]]; then
    LOCAL_IP=`ifconfig ens3 2> /dev/null | grep "inet " | awk '{print $2}'`
fi

# 源集群active NameNode
SRC_CLUSTER=hdfs://10.10.20.99:8020
# 目标集群active NameNode
TAR_CLUSTER=hdfs://10.10.10.111:9000
# 源hive服务器
# 主机名 用户名 密码
SRC_HIVE_SERVER=(10.10.20.99 hive hive123)
# 源hbase服务器
# 主机名 用户名 密码
SRC_HBASE_SERVER=(10.10.20.99 hbase hbase123)

if [[ "$LOCAL_IP" =~ 192.168 ]]; then
    SRC_CLUSTER=hdfs://192.168.1.227:8020
    TAR_CLUSTER=hdfs://192.168.1.209:9000
    SRC_HIVE_SERVER=(192.168.1.227 hive 123456)
    SRC_HBASE_SERVER=(192.168.1.227 hbase 123456)
fi

# 待备份hdfs文件
BACKUP_FILES="/hbase
/hive"
# 备份本地目录
BACKUP_DIR=/work/data/backup

# 待迁移hdfs文件
# 源文件 目标文件
HDFS_FILES="/account
/addapp
/allapp
/event
/imei
/station
/t_information_third_party
/update
/userapp
/visit"

# 待迁移hive表
# 源库名 目标库名 表名,表名
HIVE_TABLES="default default account,addapp,allapp,client_update,event,event_minute,imei,push,stat_we_info,t_information_third_party,userapp,version"
# 从hive导出表存放hdfs目录
HIVE_EXPORT_DIR=/tmp/hive/export
# distcp复制到目标hdfs目录
HIVE_IMPORT_DIR=/tmp/hive/import

# 待迁移hbase表
# table versions
HBASE_TABLES="user_profile 1
user_recommend 100"
# 从hbase导出表存放hdfs目录
HBASE_EXPORT_DIR=/tmp/hbase/export
# distcp复制到目标hdfs目录
HBASE_IMPORT_DIR=/tmp/hbase/import

# 记录日志
function log()
{
    echo "$(date +'%F %T') [ $@ ]"
}

# hdfs文件备份到本地
# 注意: 如果本地文件已经存在，会先删除
function hdfs_backup()
{
    log "Backup hdfs files"
    echo "$BACKUP_FILES" | while read file_name; do
        # 如果本地文件存在先删除
        rm -rf $BACKUP_DIR/`basename $file_name`
        log "Execute cmd: hdfs dfs -get $file_name $BACKUP_DIR"
        hdfs dfs -get $file_name $BACKUP_DIR
        log "Get hdfs file: $file_name successfully"
    done
}

# hdfs文件迁移
# 注意: 文件已经存在且大小不一致时，会更新
function hdfs_migrate()
{
    log "Migrate hdfs files"
    echo "$HDFS_FILES" | while read src_file tar_file; do
        log "Execute cmd: hadoop distcp -update ${SRC_CLUSTER}$src_file ${TAR_CLUSTER}${tar_file:-$src_file}"
        hadoop distcp -update ${SRC_CLUSTER}$src_file ${TAR_CLUSTER}${tar_file:-$src_file}
        log "Distcp hdfs file: ${SRC_CLUSTER}$src_file ${TAR_CLUSTER}${tar_file:-$src_file} successfully"
    done
}

# hive表迁移
# 注意: 会自动建表，如果表已经存在，会先删除
function hive_migrate()
{
    log "Migrate hive tables"
    echo "$HIVE_TABLES" | while read src_db tar_db tables; do
        echo "$tables" | tr , '\n' | while read table; do
            hive_export_dir=$HIVE_EXPORT_DIR/$src_db/$table
            log "Hive export dir: $hive_export_dir"
            # 删除hdfs目录如果存在
            ./autossh.exp ${SRC_HIVE_SERVER[2]} ${SRC_HIVE_SERVER[1]}@${SRC_HIVE_SERVER[0]} "hdfs dfs -rm -r -f -skipTrash $hive_export_dir"
            # 导出hive表到hdfs
            ./autossh.exp ${SRC_HIVE_SERVER[2]} ${SRC_HIVE_SERVER[1]}@${SRC_HIVE_SERVER[0]} "hive --database $src_db -S -e \"EXPORT TABLE $table TO '$hive_export_dir';\""
            log "Export hive table: $table successfully"

            # 目录授权
            ./autossh.exp ${SRC_HIVE_SERVER[2]} ${SRC_HIVE_SERVER[1]}@${SRC_HIVE_SERVER[0]} "hdfs dfs -chmod -R 777 $hive_export_dir"

            hive_import_dir=$HIVE_IMPORT_DIR/$tar_db/$table
            log "Hive import dir: $hive_import_dir"
            # 删除hdfs目录如果存在
            hdfs dfs -rm -r -f -skipTrash $hive_import_dir
            # 复制hdfs文件到目标集群
            log "Execute cmd: hadoop distcp -update ${SRC_CLUSTER}$hive_export_dir ${TAR_CLUSTER}$hive_import_dir"
            hadoop distcp -update ${SRC_CLUSTER}$hive_export_dir ${TAR_CLUSTER}$hive_import_dir
            log "Distcp hdfs file: ${SRC_CLUSTER}$hive_export_dir ${TAR_CLUSTER}$hive_import_dir successfully"

            # 创建目标数据库
            hive -S -e "CREATE DATABASE IF NOT EXISTS $tar_db;"
            # 删除表如果存在
            hive --database $tar_db -S -e "DROP TABLE IF EXISTS $table;"
            # 导入目标表
            hive --database $tar_db -S -e "IMPORT TABLE $table FROM '$hive_import_dir';"
            log "Import hive table: $table successfully"
        done
    done
}

# hbase表迁移
# 注意: 会自动建表
function hbase_migrate()
{
    log "Migrate hbase tables"
    # 创建导出hbase表到hdfs目录
    ./autossh.exp ${SRC_HBASE_SERVER[2]} ${SRC_HBASE_SERVER[1]}@${SRC_HBASE_SERVER[0]} "hdfs dfs -mkdir -p $HBASE_EXPORT_DIR"

    echo "$HBASE_TABLES" | while read table versions; do
        hbase_export_dir=$HBASE_EXPORT_DIR/$table
        # 删除文件如果存在
        ./autossh.exp ${SRC_HBASE_SERVER[2]} ${SRC_HBASE_SERVER[1]}@${SRC_HBASE_SERVER[0]} "hdfs dfs -rm -r -f -skipTrash $hbase_export_dir"
        # 导出表到hdfs目录
        log "Execute cmd: hbase org.apache.hadoop.hbase.mapreduce.Export $table $hbase_export_dir $versions"
        ./autossh.exp ${SRC_HBASE_SERVER[2]} ${SRC_HBASE_SERVER[1]}@${SRC_HBASE_SERVER[0]} "hbase org.apache.hadoop.hbase.mapreduce.Export $table $hbase_export_dir $versions"
        log "Export hbase table: $table successfully"

        # 目录授权
        ./autossh.exp ${SRC_HBASE_SERVER[2]} ${SRC_HBASE_SERVER[1]}@${SRC_HBASE_SERVER[0]} "hdfs dfs -chmod -R 777 $hbase_export_dir"

        hbase_import_dir=$HBASE_IMPORT_DIR/$table
        # 删除文件如果存在
        hdfs dfs -rm -r -f -skipTrash $hbase_import_dir
        # 复制hdfs文件到目标集群
        log "Execute cmd: hadoop distcp -update ${SRC_CLUSTER}$hbase_export_dir ${TAR_CLUSTER}$hbase_import_dir"
        hadoop distcp -update ${SRC_CLUSTER}$hbase_export_dir ${TAR_CLUSTER}$hbase_import_dir
        log "Distcp hdfs file: ${SRC_CLUSTER}$hbase_export_dir ${TAR_CLUSTER}$hbase_import_dir successfully"

        # 获取表定义
        table_ddl=`./autossh.exp ${SRC_HBASE_SERVER[2]} ${SRC_HBASE_SERVER[1]}@${SRC_HBASE_SERVER[0]} "echo \"desc '$table'\" | hbase shell" | grep "{.* => .*}" | sed "s/, TTL => 'FOREVER'//g;s/ SECONDS (.*)//g"`
        log "Table ddl: $table_ddl"
        # 创建目标表
        echo "create '$table', $table_ddl" | hbase shell

        # 导入hdfs文件到hbase表
        log "Execute cmd: hbase org.apache.hadoop.hbase.mapreduce.Import $table $hbase_import_dir"
        hbase org.apache.hadoop.hbase.mapreduce.Import $table $hbase_import_dir
        log "Import hbase table: $table successfully"
    done
}

# hbase集群之间表复制
# 只会复制最新版本的数据
function hbase_copytable()
{
    local hbase_zk=yygz-208.gzserv.com,yygz-209.gzserv.com,yygz-210.gzserv.com:2181:/hbase

    echo "$HBASE_TABLES" | while read table versions; do
        hbase org.apache.hadoop.hbase.mapreduce.CopyTable --peer.adr=$hbase_zk $table
    done
}

function hive_copy()
{
    echo "$HIVE_TABLES" | while read src_db tar_db tables; do
        echo "$tables" | tr , '\n' | while read table; do
            if [[ $src_db = default ]]; then
                hive_data_dir=/hive/$table
            else
                hive_data_dir=/hive/${src_db}.db/$table
            fi

            hive_import_dir=$HIVE_IMPORT_DIR/$tar_db/$table
            log "Hive import dir: $hive_import_dir"
            # 删除hdfs目录如果存在
            hdfs dfs -rm -r -f -skipTrash $hive_import_dir
            # 复制hdfs文件到目标集群
            log "Execute cmd: hadoop distcp -update ${SRC_CLUSTER}$hive_data_dir ${TAR_CLUSTER}$hive_import_dir"
            hadoop distcp -update ${SRC_CLUSTER}$hive_data_dir ${TAR_CLUSTER}$hive_import_dir
            log "Distcp hdfs file: ${SRC_CLUSTER}$hive_data_dir ${TAR_CLUSTER}$hive_import_dir successfully"

            # 清空表
            log "Truncate hive table: $table"
            hive --database $tar_db -S -e "TRUNCATE TABLE $table;"

            log "Load data into hive table: $table"
            hdfs dfs -ls $hive_import_dir | sed '1d' | awk '{
                split($NF,arr,"=")
                printf("LOAD DATA INPATH '\''%s'\'' INTO TABLE '$table' PARTITION (`date` = '\''%s'\'');\n",$NF,arr[2])
            }' > $table.sql
            hive --database $tar_db -f $table.sql
        done
    done
}

function hdfs_check()
{
    local table="$1"

    hdfs dfs -ls /hive/$table | sed '1d' | awk '{print $NF}' | while read file_name; do
        hdfs dfs -du -s -h $file_name
    done
}

function main()
{
    set -e

#    hdfs_backup

#    hdfs_migrate

#    hive_migrate

    hive_copy

    hbase_migrate
}
main "$@"