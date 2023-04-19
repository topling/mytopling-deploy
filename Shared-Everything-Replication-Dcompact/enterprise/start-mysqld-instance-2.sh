#!/bin/bash

existing=`pgrep mysqld`
if [ $? -eq 0 ] ; then
	echo There is a running mysqld process: $existing
	exit 1
fi

MY_HOME=`dirname $0`
MY_HOME=`realpath $MY_HOME/../../..`
SCRIPTS_HOME=`realpath $(dirname $0)`

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

MYTOPLING_DATA_DIR=/mnt/mynfs/datadir/mytopling-instance-1
MYTOPLING_SLAVE_DATA_DIR=/mnt/mynfs/datadir/mytopling-instance-2
MYTOPLING_LOG_DIR=/mnt/mynfs/infolog/mytopling-instance-2

if ! getent group mysql >/dev/null; then
  groupadd -g 27 mysql
fi
if ! getent passwd mysql >/dev/null; then
  useradd mysql -u 27 -g 27 --no-create-home -s /sbin/nologin
fi
MYSQL_SOCK_DIR=/var/lib/mysql
mkdir -p $MYSQL_SOCK_DIR # for sock file
export LD_LIBRARY_PATH=/mnt/mynfs/opt/lib

if [ ! -d mnt/mynfs/dataidr/mytopling-instance-2 ];then
  rm -rf /mnt/mynfs/{infolog,datadir}/mytopling-instance-2
  mkdir -p /mnt/mynfs/{datadir,infolog}/mytopling-instance-2
  cp -a $MYTOPLING_DATA_DIR/* $MYTOPLING_SLAVE_DATA_DIR/
  sed -i "s/^server-uuid.*/server-uuid=`uuidgen`/g" $MYTOPLING_SLAVE_DATA_DIR/auto.cnf
  mkdir $MYTOPLING_LOG_DIR/stdlog -p
  touch $MYTOPLING_LOG_DIR/stdlog/{stdout,stderr}
  cp $MY_HOME/share/web/{index.html,style.css} /mnt/mynfs/infolog/mytopling-instance-2
  chown mysql:mysql -R /mnt/mynfs/{datadir,infolog}/mytopling-instance-2 # must
  chown mysql:mysql -R /var/lib/mysql
fi


common_args=(
  --server-id=2
  --gtid-mode=ON
  --enforce-gtid-consistency=ON
  --socket=$MYSQL_SOCK_DIR/mysql.sock
  --user=mysql
  --datadir=${MYTOPLING_SLAVE_DATA_DIR}
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


sudo sysctl -w fs.file-max=33554432
sudo sysctl -w fs.nr_open=2097152
sudo sysctl -w vm.max_map_count=8388608
ulimit -n 100000  # normal user
ulimit -n 1000000 # root user

# 检测可执行文件:
binary_path="/mnt/mynfs/opt/lib/librocksdb.so"
symbol_name="_ZN7rocksdb10tzb_detail13g_startupTimeE"
line=`nm -D $binary_path | grep  $symbol_name`
# Check if the symbol does not exist in the binary file
if [ $(echo $line | awk '{print NF}') -eq 2 ]; then
echo -e "\033[1;31mWarning:\033[0m 您正尝试使用社区版二进制文件运行企业版配置文件，联系我们(contact@topling.cn)获取企业版二进制文件"
echo -e "\033[1;31mWarning:\033[0m You're trying to use a community edition binary file to run an enterprise edition configuration file. Contact us for the correct enterprise edition binary file."
echo "mailto:contact@topling.cn to get an enterprise version"
echo ""
fi
$MY_HOME/bin/mysqld ${common_args[@]} ${binlog_args[@]} ${rocksdb_args[@]} $@ \
  1> $MYTOPLING_LOG_DIR/stdlog/stdout \
  2> $MYTOPLING_LOG_DIR/stdlog/stderr &
sleep 1
echo mysqld started successfully and put into background
tail /mnt/mynfs/infolog/mytopling-instance-2/stdlog/stderr
