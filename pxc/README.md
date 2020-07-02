# mysql-pxc 部署模式
## docker

```bash
$ mkdir pxc
$ cd pxc
$ mkdir data master follower
# 创建数据卷
$ cd data
$ mkdir v1 v2 v3
# 设置权限
$ chmod 777 v1 v2 v3
```

```bash
$ cd ../../pxc/master
$ vim docker-compose.yml
```

```yaml
version: '3'
services:
  pxc01:
    restart: always
    image: percona/percona-xtradb-cluster:5.7
    container_name: pxc01
    privileged: true
    ports:
      - 13306:3306
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - CLUSTER_NAME=pxc
    volumes:
      - ../data/v1:/var/lib/mysql

networks:
  default:
    external:
      name: mysql_network
```

```bash
$ cd /usr/local/docker/pxc/follower
$ vim docker-compose.yml
```

```yaml
version: '3'
services:
  pxc02:
    restart: always
    image: percona/percona-xtradb-cluster:5.7
    container_name: pxc02
    privileged: true
    ports:
      - 13307:3306
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - CLUSTER_NAME=pxc
      - CLUSTER_JOIN=pxc01
    volumes:
      - ../data/v2:/var/lib/mysql

  pxc03:
    restart: always
    image: percona/percona-xtradb-cluster:5.7
    container_name: pxc03
    privileged: true
    ports:
      - 13308:3306
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - CLUSTER_NAME=pxc
      - CLUSTER_JOIN=pxc01
    volumes:
      - ../data/v3:/var/lib/mysql

networks:
  default:
    external:
      name: mysql_network
```

> 一定要等到 master 节点起来，在进行启动 follower 节点不然会出现各个节点之间不能相互注册


##  查看 PXC 集群是否相互注册成功
```mysql
show status like 'wsrep_cluster%'
```