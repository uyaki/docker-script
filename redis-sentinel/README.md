# redis sentinel

## 目录结构

```
/xxx/docker-script/redis-sentinel
├── redis
|  └── docker-compose.yml
└── sentinel
   ├── docker-compose.yml
   ├── sentinel.conf
   ├── sentinel1.conf
   ├── sentinel2.conf
   └── sentinel3.conf
```

## redis集群

redis/docker-compose.yml

```yml
version: '3'
services:
  master:
    image: redis:6.0.5
    container_name: redis-master
    command: redis-server  --requirepass 123456  --masterauth 123456
    ports:
      - 6380:6379
  slave1:
    image: redis:6.0.5
    container_name: redis-slave-1
    ports:
      - 6381:6379
    command:  redis-server --slaveof redis-master 6379 --masterauth 123456  --requirepass 123456
  slave2:
    image: redis:6.0.5
    container_name: redis-slave-2
    ports:
      - 6382:6379
    command: redis-server --slaveof redis-master 6379 --masterauth 123456 --requirepass 123456
```

启动

```sh
$ docker-compose up -d
```
## redis-sentinel

1. 查看主节点的network信息
```sh
# 一步到位
$ docker inspect $(docker ps -f "name=redis-master" | awk '{print $1}' | tail -n +2)

# 分步查看
$ docker ps
$ docker inspect 主节点容器id
```
核心信息如下：
```json
"Networks": {
    "redis_default": {
        ...,
        "IPAddress": "172.20.0.3",
        ...
    }
}
```
2. 添加配置文件 sentinel.conf
```conf
port 26379
dir /tmp
# Redis 监控一个叫做 mymaster 的运行在 172.20.0.2:6379 的 master，投票达到 2 则表示 master 挂掉了。
sentinel monitor mymaster 172.20.0.3 6379 2
# 设置主节点的密码
sentinel auth-pass mymaster 123456
# 在一段时间范围内 sentinel 向 master 发送的心跳 PING 没有回复则认为 master 不可用了
sentinel down-after-milliseconds mymaster 30000
# 设置在故障转移之后，同时可以重新配置使用新 master 的 slave 的数量。
# 数字越低，更多的时间将会用故障转移完成，但是如果 slaves 配置为服务旧数据，你可能不希望所有的 slave 同时重新同步 master。
# 因为主从复制对于 slave 是非阻塞的，当停止从 master 加载批量数据时有一个片刻延迟。
# 通过设置选项为 1，确信每次只有一个 slave 是不可到达的。
sentinel parallel-syncs mymaster 1
# 180 秒内 mymaster 还没活过来，则认为 master 宕机了
sentinel failover-timeout mymaster 180000
sentinel deny-scripts-reconfig yes
```
```sh
$ cp sentinel.conf sentinel1.conf
$ cp sentinel.conf sentinel2.conf
$ cp sentinel.conf sentinel3.conf
```

3. sentinel/docker-compose.yml

```yml
version: '3'
services:
  sentinel1:
    image: redis:6.0.5
    container_name: redis-sentinel-1
    ports:
      - 26379:26379
    command: redis-sentinel /usr/local/etc/redis/sentinel.conf
    volumes:
      - ./sentinel1.conf:/usr/local/etc/redis/sentinel.conf
  sentinel2:
    image: redis:6.0.5
    container_name: redis-sentinel-2
    ports:
    - 26380:26379
    command: redis-sentinel /usr/local/etc/redis/sentinel.conf
    volumes:
      - ./sentinel2.conf:/usr/local/etc/redis/sentinel.conf
  sentinel3:
    image: redis:6.0.5
    container_name: redis-sentinel-3
    ports:
      - 26381:26379
    command: redis-sentinel /usr/local/etc/redis/sentinel.conf
    volumes:
      - ./sentinel3.conf:/usr/local/etc/redis/sentinel.conf
networks:
  default:
    external:
      name: redis_default
```

4. 启动
```sh
$ docker-compose up -d
```

## 故障转移测试

- 查看master，9c813004f662 为master容器ID

```sh
$ docker exec -it 9c813004f662 bash
root@9c813004f662:/data# redis-cli
127.0.0.1:6379> auth 123456
OK
127.0.0.1:6379> info

...
# Replication
role:master
connected_slaves:2
slave0:ip=172.20.0.2,port=6379,state=online,offset=10316,lag=1
slave1:ip=172.20.0.4,port=6379,state=online,offset=10316,lag=1
....

```

- 停止master节点，查看slave节点，4126f8ab7705 为slave容器ID

```sh
$ docker stop 9c813004f662
$ docker exec -it 4126f8ab7705 bash
root@4126f8ab7705:/data# redis-cli
127.0.0.1:6379> auth 123456
OK
127.0.0.1:6379> info
# Replication
role:master
connected_slaves:1
slave0:ip=172.20.0.4,port=6379,state=online,offset=18495,lag=1
```
