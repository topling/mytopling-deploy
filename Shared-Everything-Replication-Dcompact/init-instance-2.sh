#!/bin/bash

IP=`hostname -I`
TARGET_HOST="mytopling-instance-2.mytopling.in"
TARGET_IP=`ping -c 1 $TARGET_HOST | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p'`


if [ $IP -ne $TARGET_IP ]; then
    echo "实例错误,需要在$TARGET_HOST($TARGET_IP)上运行" 
    echo "当前主机为:$IP"
    exit 1;
fi

/mnt/mynfs/bin/mysql -S /var/lib/mysql/mysql.sock -uroot <<EOF 2>/dev/null
reset slave;
change master to MASTER_HOST='mytopling-instance-1.mytopling.in',MASTER_USER='sync',MASTER_PASSWORD='sync',MASTER_AUTO_POSITION=1;
CREATE USER IF NOT EXISTS 'sync'@'%' IDENTIFIED BY 'sync';
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'sync'@'%';
flush privileges;
EOF