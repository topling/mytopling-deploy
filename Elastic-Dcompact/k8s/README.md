
现有 ToplingDB 接入方案:
## 1. 修改每个实例的 json 文件中的 `CompactionExecutorFactory.dcompact.params.instance_name` 全局唯一。如果每个机器的主机名唯一，可以使用主机名作为`instance_name`。此可以使用 sed 替换:
```bash
sed -i "s|instance_name|\"instance_name\":\"`hostname`\",|g" side-plugin*.json
```
## 2. 修改 hoster_root 以及 nfs_mnt_src
这两个参数对应数据库的某个目录，和NFS上的某个目录。NFS两个路径的挂载后，应当映射到同一个位置。

一个简单的方案是，都映射到 MySQL 的 datadir 位置。

需要将side-plugin.json中的值做如下修改:
```json
{
//...
"nfs_mnt_src": "<nfs-server-host>:/path/to/entry", // 指向 datadir的目录位置，比如
"hoster_root": "/mnt/local/mount/point", // MySQL 数据库目录的dataidr位置，典型的如 /mnt/mynfs/datadir/mytopling-instance-1
"nfs_mnt_opt": "nolock,noatime", // 推荐添加这两个参数，也可以自定义其他有效的参数
//...
}
```
在配置完成后，如果我们创建一个文件 `newfile`,那么 `<nfs-server-host>:/path/to/entry/newfile` 和 `/mnt/local/mount/point/nfwfile` 应该为同一个文件

## 3. 修改dcompact 转发目标
若 k8s 的 node 的 hostname 分别为 node01.mytopling.in , ode02.dcompact.mytopling.in 等，那么可以进行如下修改
找到`CompactionExecutorFactory.dcompact.params.http_worker`数组
将请此数组改为以下形式:
```jsonc
"http_workers": [
    {
    "url": "http://node01.mytopling.in:30000",
    "base_url": "http://node01.mytopling.in:30001",
    "web_url": "http://node01.mytopling.in:30001"
    },
    {
    "url": "http://node02.dcompact.mytopling.in:30000",
    "base_url": "http://node02.dcompact.mytopling.in:30001",
    "web_url": "http://node02.dcompact.mytopling.in:30001"
    },
    {
    "url": "http://node03.dcompact.mytopling.in:30000",
    "base_url": "http://node03.dcompact.mytopling.in:30001",
    "web_url": "http://node03.dcompact.mytopling.in:30001"
    },
    //...
]
```
这里使用 30000/30001 端口是因为 k8s 默认不开放 30000 以下端口