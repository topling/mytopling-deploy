#!/bin/bash

UPDATE_KERNEL_HEADERS=${UPDATE_KERNEL_HEADERS:-0}
headers=$(rpm -qa kernel-* | grep headers | grep -E "headers-(5\.([4-9]|[1-9][0-9]+)|[6-9]\.)")
if [ $UPDATE_KERNEL_HEADERS -ne 0 ]; then
    if [ -n "$headers" ]; then
        echo "已安装支持 io_uring 内核头文件，无需升级"
    else
        # 安装内核头文件
        echo "安装内核头文件以编译支持 io_uring"
        yum install elrepo-release -y;
        yum -y --disablerepo="*" --enablerepo="elrepo-kernel" install kernel-ml-headers --allowerasing
    fi
else
    if [ -n "$headers" ]; then
    echo "已安装支持 io_uring 内核头文件，无需升级"
    else
        filename=`realpath $0`
        echo -e "\e[33mWarning: 未安装支持 io_uring 内核头文件，编译后将不支持io_uring。\e[0m"
        echo "执行 UPDATE_KERNEL_HEADERS=1 bash $filename 自动安装对应内核头文件并编译。"
        echo "三秒后开始编译不支持 io_uring 的版本"
        sleep 3
    fi
fi


sudo yum config-manager --set-enabled powertools
yum install epel-release -y
sudo yum install -y liburing-devel git gflags-devel libcurl-devel \
    libaio-devel cmake nfs-utils openssl-devel ncurses-devel libtirpc-devel \
    rpcgen bison libudev-devel gcc-toolset-12-gcc-c++
source  scl_source enable gcc-toolset-12
HOME=`pwd`

git clone https://github.com/topling/toplingdb.git --depth 1
cd toplingdb
git submodule update --init --recursive
ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts # silent git
make -j`nproc` DEBUG_LEVEL=0 shared_lib UPDATE_REPO=0
sudo make install-shared PREFIX=/mnt/mynfs/opt

cd $HOME
git clone https://github.com/topling/mytopling.git --depth 1
cd mytopling
git submodule update --init --recursive
# build.sh 会调用 cmake 生成编译文件到 build-rls 目录（Release 版）
bash build.sh -DTOPLING_LIB_DIR=/mnt/mynfs/opt/lib \
              -DCMAKE_INSTALL_PREFIX=/mnt/mynfs/opt
# 编译代码
cd build-rls
make -j`nproc`
sudo make install
# download scripts
cd /mnt/mynfs/opt
git clone https://github.com/topling/mytopling-deploy.git