#!/bin/bash

existing=`pgrep mysqld`
if [ $? -eq 0 ] ; then
	echo There is a running mysqld process: $existing
	exit 1
fi

MY_HOME=`dirname $0`
MY_HOME=`realpath $MY_HOME/../../..`
SCRIPTS_HOME=`realpath $(dirname $0)

if [ ! -f $MY_HOME/bin/mysqld ]; then
  echo $0 must be in $SCRIPTS_HOME, file $MY_HOME/bin/mysqld must exits >&2
  exit 1
fi

export ROCKSDB_KICK_OUT_OPTIONS_FILE=1
export TOPLING_SIDEPLUGIN_CONF=$SCRIPTS_HOME/side-plugin-2.json

export DictZipBlobStore_zipThreads=$((`nproc`/2))

#export JsonOptionsRepo_DebugLevel=2
#export csppDebugLevel=0
export TOPLINGDB_CACHE_SST_FILE_ITER=1
export BULK_LOAD_DEL_TMP=1

MYTOPLING_DATA_DIR=/mnt/mynfs/datadir/mytopling-instance-2
MYTOPLING_LOG_DIR=/mnt/mynfs/infolog/mytopling-instance-2
rm -rf ${MYTOPLING_DATA_DIR}/.rocksdb/job-*
if ! getent group mysql >/dev/null; then
  groupadd -g 27 mysql
fi
if ! getent passwd mysql >/dev/null; then
  useradd mysql -u 27 -g 27 --no-create-home -s /sbin/nologin
fi
MYSQL_SOCK_DIR=/var/lib/mysql
mkdir -p $MYSQL_SOCK_DIR # for sock file
export LD_LIBRARY_PATH=/mnt/mynfs/opt/lib
if [ ! -e /mnt/mynfs/datadir/mytopling-instance-2/.rocksdb/IDENTITY ]; then
  if [ -e /mnt/mynfs/datadir ]; then
    echo "Dir '/mnt/mynfs/datadir' exists, but '/mnt/mynfs/datadir/mytopling-instance-2/.rocksdb/IDENTITY' does not exists"
    read -p 'Are you sure delete /mnt/mynfs/datadir and re-initialize database? yes(y)/no(n)' yn
    if [ "$yn" != "y" ]; then
      exit 1
    fi
    rm -rf /mnt/mynfs/{log-bin,wal,infolog}
    rm -rf /mnt/mynfs/datadir/mytopling-instance-2/* 
    rm -rf /mnt/mynfs/datadir/mytopling-instance-2/.rocksdb  
  fi
  mkdir -p /mnt/mynfs/{datadir,log-bin,wal,infolog}/mytopling-instance-2
  chown mysql:mysql -R /mnt/mynfs/{datadir,log-bin,wal}/mytopling-instance-2
  /mnt/mynfs/opt/bin/mysqld --initialize-insecure --skip-grant-tables \
      --datadir=/mnt/mynfs/datadir/mytopling-instance-2
  mkdir $MYTOPLING_LOG_DIR/stdlog -p
  touch $MYTOPLING_LOG_DIR/stdlog/{stdout,stderr}
  cp $MY_HOME/share/web/{index.html,style.css} /mnt/mynfs/infolog/mytopling-instance-2
  chown mysql:mysql -R /mnt/mynfs/{datadir,log-bin,wal,infolog}/mytopling-instance-2 # must
  chown mysql:mysql -R $MYSQL_SOCK_DIR
fi


common_args=(
  --server-id=2
  --gtid-mode=ON
  --enforce-gtid-consistency=ON
  --socket=$MYSQL_SOCK_DIR/mysql.sock
  --user=mysql
  --datadir=${MYTOPLING_DATA_DIR}
  --bind-address=0.0.0.0
  --disabled_storage_engines=myisam
  --host_cache_size=644
  --internal_tmp_mem_storage_engine=MEMORY
  --join_buffer_size=1048576
  --key_buffer_size=16777216
  --max_binlog_size=524288000
  --max_connections=8000
  --max_heap_table_size=67108864
  --read_buffer_size=1048576
  --skip_name_resolve=ON
  --table_open_cache=8192
  --thread_cache_size=200
  --enable_optimizer_cputime_with_wallclock=on
  --optimizer_switch=mrr=on,mrr_cost_based=off
  --performance_schema=off
  --default_authentication_plugin=mysql_native_password
  --secure_file_priv=''
  --transaction_isolation=READ-COMMITTED
  --sync_binlog=0
  --innodb_flush_log_at_trx_commit=2
  --read_only
  --replica_parallel_workers=0
)

rocksdb_args=(
  --plugin-load=ha_rocksdb_se.so
  --rocksdb --default-storage-engine=rocksdb
  --rocksdb_datadir=${MYTOPLING_DATA_DIR}/.rocksdb
  --rocksdb_allow_concurrent_memtable_write=on
  --rocksdb_force_compute_memtable_stats=off
  --rocksdb_reuse_iter=on # 此选项打开时，长期空闲的数据库连接会导致内存泄露，请谨慎使用
  --rocksdb_write_policy=write_committed
  --rocksdb_mrr_batch_size=32 --rocksdb_async_queue_depth=32
  --rocksdb_lock_wait_timeout=10
  --rocksdb_print_snapshot_conflict_queries=1
  --rocksdb_flush_log_at_trx_commit=2
  --rocksdb_write_disable_wal=ON
)

binlog_args=(
  # 使用 binlog-ddl-only 时 MyTopling 可配置为基于共享存储的多副本集群，
  # 但此配置下 MyTopling 不能做为传统 MySQL 主从中的上游数据库，因为此
  # 配置下 binlog 只会记录 DDL 操作
  # --binlog-ddl-only=ON
  --disable-log-bin
  --binlog-order-commits=ON
)

# 修复引擎监控日志链接
sudo ln -sf $MYTOPLING_LOG_DIR $MYTOPLING_LOG_DIR/.rocksdb
sudo ln -sf $MYTOPLING_LOG_DIR/mnt_mynfs_datadir_mytopling-instance-2_.rocksdb_LOG \
           $MYTOPLING_LOG_DIR/LOG
rm -rf ${MYTOPLING_DATA_DIR}/.rocksdb/job*
rm -f /tmp/Topling-*

sudo sysctl -w fs.file-max=33554432
sudo sysctl -w fs.nr_open=2097152
sudo sysctl -w vm.max_map_count=8388608
ulimit -n 100000  # normal user
ulimit -n 1000000 # root user

$MY_HOME/bin/mysqld ${common_args[@]} ${binlog_args[@]} ${rocksdb_args[@]} $@ \
  1> $MYTOPLING_LOG_DIR/stdlog/stdout \
  2> $MYTOPLING_LOG_DIR/stdlog/stderr &
sleep 1
echo mysqld started successfully and put into background
tail /mnt/mynfs/infolog/mytopling-instance-2/stdlog/stderr
