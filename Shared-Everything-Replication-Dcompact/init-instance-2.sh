#!/bin/bash

# 获取本机所有IP地址
localIPs=$(ip addr |grep "inet " |awk '{print $2}' |awk -F"/" '{print $1}')

TARGET_HOST="mytopling-instance-2.mytopling.in"
dnsIP=`ping -c 1 $TARGET_HOST | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p'`

# 判断dnsIP是否在本机IP列表中
for ip in $localIPs; do
  if [ "$ip" == "$dnsIP" ]; then
    /mnt/mynfs/opt/bin/mysql -S /var/lib/mysql/mysql.sock -uroot <<EOF
reset slave;
change master to MASTER_HOST='mytopling-instance-1.mytopling.in',MASTER_USER='sync',MASTER_PASSWORD='sync',MASTER_AUTO_POSITION=1;
start slave;
EOF
    exit 0
fi
done

# 如果未找到，输出错误信息并退出
echo "$TARGET_HOST 非本机IP"
exit 1
