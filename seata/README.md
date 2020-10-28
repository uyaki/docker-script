# seata + nacos + postgresql
> 本文档实现版本为[seata-v1.3.0](https://github.com/seata/seata/releases/tag/v1.3.0)，结合[nacos-1.3.0](https://github.com/alibaba/nacos/releases/tag/1.3.0)，postgresql实现，其余集成方式不扩展
## sql脚本位置

- client 端
    - AT 模式脚本 [client/at](https://github.com/seata/seata/blob/develop/script/client/at/db)
    - Saga 模式脚本 [client/saga](https://github.com/seata/seata/blob/develop/script/client/saga/db)
- server 端
    - 通用脚本[server/db](https://github.com/seata/seata/blob/develop/script/server/db)

## 配置文件

- 下载配置文件： [config-center](https://github.com/seata/seata/blob/develop/script/config-center)

```bash
/config-center
├── apollo
|  └── apollo-config.sh
├── consul
|  └── consul-config.sh
├── etcd3
|  └── etcd3-config.sh
├── nacos
|  ├── nacos-config.py
|  └── nacos-config.sh
├── zk
|  └── zk-config.sh
├── README.md
└── config.txt
```
```
cp -R config-center/nacos script/nacos
cp config-center/config.txt script/config.txt
```
- 修改 ./script/config.txt

- 需要修改的配置

|server|client|
|---|---|
|store.mode: file,db|config.type: file、nacos 、apollo、zk、consul、etcd3、custom|
|#only db:|#only file:|
|store.db.driverClassName|service.default.grouplist|
|store.db.url|	#All:|
|store.db.user|service.vgroupMapping.my_test_tx_group|
|store.db.password|service.disableGlobalTransaction|

```properties
## store.mode
store.mode=db
## db配置
store.db.dbType=postgresql
store.db.driverClassName=org.postgresql.Driver
store.db.url=jdbc:postgresql://127.0.0.1:5432/seata_db
store.db.user=pg_user
store.db.password=pg_password
## config.type
config.type=nacos
## service.vgroupMapping.my_test_tx_group，vgroupMapping 为小驼峰形式，my_test_tx_group 替换成对应的事务分组，建议设置为${serverName-group}，可以配置多个
service.vgroupMapping.seata-server=default
service.vgroupMapping.order-service-group=default
service.vgroupMapping.storage-service-group=default
service.vgroupMapping.seata-api-group=default
## 关闭全局事务
service.disableGlobalTransaction=false
```

- 使用sh脚本将修改好的配置发布到nacos

```bash
## 命令格式
$ sh ${SEATAPATH}/script/config-center/nacos/nacos-config.sh -h localhost -p 8848 -g SEATA_GROUP -t 5a3c7d6c-f497-4d68-a71a-2e5e3340b3ca -u username -w password
## 示例(使用默认nacos/nacos的账密时，无需设置-u、-w)
$ sh ./nacos/nacos-config.sh -h localhost -p 8848 -g SEATA_GROUP -t 5a3c7d6c-f497-4d68-a71a-2e5e3340b3ca
```
- 参数说明

|参数|说明|
|---|---|
| -h | host |
| -p | port 默认 8848 |
| -g | 配置 grouping, 默认值 'SEATA_GROUP'|
| -t | 指定nacos的namespace ID ，默认值''|
| -u | nacos的username, 默认值 ''|
| -w | nacos的password, 默认值 ''|

## 修改启动配置
> 文件位置：`/config/registry.conf`
```json
registry {
  # file 、nacos 、eureka、redis、zk、consul、etcd3、sofa
  type = "nacos"

  nacos {
    application = "seata-server"
    serverAddr = "127.0.0.1:8848"
    group = "seata_server"
    namespace = "fec1b49f-5596-406c-832f-1264a1caddfd"
    cluster = "default"
    username = ""
    password = ""
  }
}

config {
  # file、nacos 、apollo、zk、consul、etcd3
  type = "nacos"

  nacos {
    serverAddr = "127.0.0.1:8848"
    namespace = "fec1b49f-5596-406c-832f-1264a1caddfd"
    group = "seata_server"
    username = ""
    password = ""
  }
}

```
## 启动nacos-server
```yml
version: "3"
services:
  seata-server:
    image: seataio/seata-server:1.3.0
    container_name: seata-server
    hostname: seata-server
    ports:
      - "8091:8091"
    volumes:
      - ${PWD}/config:/root/seata-config
    environment:
      - SEATA_PORT=8091
      - STORE_MODE=file
      # 可选, 指定配置文件位置, 如 file:/root/registry, 将会加载 /root/registry.conf 作为配置文件
      # 如果需要同时指定 file.conf文件，需要将registry.conf的config.file.name的值改为类似file:/root/file.conf
      - SEATA_CONFIG_NAME=file:/root/seata-config/registry
```
