#!/bin/bash

# 获取本机所有IP地址
localIPs=$(ip addr |grep "inet " |awk '{print $2}' |awk -F"/" '{print $1}')

TARGET_HOST="mytopling-instance-1.mytopling.in"
dnsIP=`ping -c 1 $TARGET_HOST | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p'`

# 判断dnsIP是否在本机IP列表中
for ip in $localIPs; do
  if [ "$ip" == "$dnsIP" ]; then
    /mnt/mynfs/opt/bin/mysql -S /var/lib/mysql/mysql.sock -uroot <<EOF
CREATE USER IF NOT EXISTS 'sync'@'%' IDENTIFIED BY 'sync';
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'sync'@'%';
flush privileges;
EOF
    exit 0
  fi
done
echo "mytopling-instance-1.mytopling.in非本机IP"
