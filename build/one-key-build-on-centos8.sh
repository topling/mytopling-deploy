#!/bin/bash
sudo yum config-manager --set-enabled powertools # 有些 linux 发行版不需要此行
sudo yum install -y liburing-devel git gcc-c++ gflags-devel libcurl-devel \
    libaio-devel cmake nfs-utils openssl-devel ncurses-devel libtirpc-devel \
    rpcgen bison libudev-devel
HOME=`pwd`

git clone https://github.com/topling/toplingdb.git --depth 1
cd toplingdb
git submodule update --init --recursive
ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts # silent git
make -j`nproc` DEBUG_LEVEL=0 shared_lib
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