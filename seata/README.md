# seata + nacos + postgresql
> 本文档实现版本为[seata-v1.3.0](https://github.com/seata/seata/releases/tag/v1.3.0)，结合[nacos-1.3.0](https://github.com/alibaba/nacos/releases/tag/1.3.0)，postgresql实现，其余集成方式不扩展

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

> 登录nacos创建seata的namespace

```bash
## 命令格式
$ sh ${SEATAPATH}/script/config-center/nacos/nacos-config.sh -h ${nacos-ip} -p ${nacos-port} -g ${nacos-group} -t ${nacos-namespace} -u ${nacos-username} -w ${nacos-password}
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

## 数据库初始化

### 服务端DB（上诉配置的DB）

```properties
store.db.dbType=postgresql
store.db.driverClassName=org.postgresql.Driver
store.db.url=jdbc:postgresql://127.0.0.1:5432/seata_db
store.db.user=pg_user
store.db.password=pg_password
```

通用脚本[server/db](https://github.com/seata/seata/blob/develop/script/server/db)

```sql
-- -------------------------------- The script used when storeMode is 'db' --------------------------------
-- the table to store GlobalSession data
CREATE TABLE IF NOT EXISTS public.global_table
(
    xid                       VARCHAR(128) NOT NULL,
    transaction_id            BIGINT,
    status                    SMALLINT     NOT NULL,
    application_id            VARCHAR(32),
    transaction_service_group VARCHAR(32),
    transaction_name          VARCHAR(128),
    timeout                   INT,
    begin_time                BIGINT,
    application_data          VARCHAR(2000),
    gmt_create                TIMESTAMP(0),
    gmt_modified              TIMESTAMP(0),
    CONSTRAINT pk_global_table PRIMARY KEY (xid)
);

CREATE INDEX idx_gmt_modified_status ON public.global_table (gmt_modified, status);
CREATE INDEX idx_transaction_id ON public.global_table (transaction_id);

-- the table to store BranchSession data
CREATE TABLE IF NOT EXISTS public.branch_table
(
    branch_id         BIGINT       NOT NULL,
    xid               VARCHAR(128) NOT NULL,
    transaction_id    BIGINT,
    resource_group_id VARCHAR(32),
    resource_id       VARCHAR(256),
    branch_type       VARCHAR(8),
    status            SMALLINT,
    client_id         VARCHAR(64),
    application_data  VARCHAR(2000),
    gmt_create        TIMESTAMP(6),
    gmt_modified      TIMESTAMP(6),
    CONSTRAINT pk_branch_table PRIMARY KEY (branch_id)
);

CREATE INDEX idx_xid ON public.branch_table (xid);

-- the table to store lock data
CREATE TABLE IF NOT EXISTS public.lock_table
(
    row_key        VARCHAR(128) NOT NULL,
    xid            VARCHAR(96),
    transaction_id BIGINT,
    branch_id      BIGINT       NOT NULL,
    resource_id    VARCHAR(256),
    table_name     VARCHAR(32),
    pk             VARCHAR(36),
    gmt_create     TIMESTAMP(0),
    gmt_modified   TIMESTAMP(0),
    CONSTRAINT pk_lock_table PRIMARY KEY (row_key)
);

CREATE INDEX idx_branch_id ON public.lock_table (branch_id);
```


### 客户端DB

> 请在实际服务配置连接的DB里面执行脚本

- AT 模式脚本 [client/at](https://github.com/seata/seata/blob/develop/script/client/at/db)

```sql
-- for AT mode you must to init this sql for you business database. the seata server not need it.
CREATE TABLE IF NOT EXISTS public.undo_log
(
    id            SERIAL       NOT NULL,
    branch_id     BIGINT       NOT NULL,
    xid           VARCHAR(100) NOT NULL,
    context       VARCHAR(128) NOT NULL,
    rollback_info BYTEA        NOT NULL,
    log_status    INT          NOT NULL,
    log_created   TIMESTAMP(0) NOT NULL,
    log_modified  TIMESTAMP(0) NOT NULL,
    CONSTRAINT pk_undo_log PRIMARY KEY (id),
    CONSTRAINT ux_undo_log UNIQUE (xid, branch_id)
);

CREATE SEQUENCE IF NOT EXISTS undo_log_id_seq INCREMENT BY 1 MINVALUE 1 ;
```

- Saga 模式脚本 [client/saga](https://github.com/seata/seata/blob/develop/script/client/saga/db)

```sql
-- -------------------------------- The script used for sage  --------------------------------
CREATE TABLE IF NOT EXISTS public.seata_state_machine_def
(
    id               VARCHAR(32)  NOT NULL,
    name             VARCHAR(128) NOT NULL,
    tenant_id        VARCHAR(32)  NOT NULL,
    app_name         VARCHAR(32)  NOT NULL,
    type             VARCHAR(20),
    comment_         VARCHAR(255),
    ver              VARCHAR(16)  NOT NULL,
    gmt_create       TIMESTAMP(3) NOT NULL,
    status           VARCHAR(2)   NOT NULL,
    content          TEXT,
    recover_strategy VARCHAR(16),
    CONSTRAINT pk_seata_state_machine_def PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.seata_state_machine_inst
(
    id                  VARCHAR(128)                NOT NULL,
    machine_id          VARCHAR(32)                NOT NULL,
    tenant_id           VARCHAR(32)                NOT NULL,
    parent_id           VARCHAR(128),
    gmt_started         TIMESTAMP(3)               NOT NULL,
    business_key        VARCHAR(48),
    start_params        TEXT,
    gmt_end             TIMESTAMP(3) DEFAULT now(),
    excep               BYTEA,
    end_params          TEXT,
    status              VARCHAR(2),
    compensation_status VARCHAR(2),
    is_running          BOOLEAN,
    gmt_updated         TIMESTAMP(3) DEFAULT now() NOT NULL,
    CONSTRAINT pk_seata_state_machine_inst PRIMARY KEY (id),
    CONSTRAINT unikey_buz_tenant UNIQUE (business_key, tenant_id)
)
;
CREATE TABLE IF NOT EXISTS public.seata_state_inst
(
    id                       VARCHAR(48)  NOT NULL,
    machine_inst_id          VARCHAR(128)  NOT NULL,
    name                     VARCHAR(128) NOT NULL,
    type                     VARCHAR(20),
    service_name             VARCHAR(128),
    service_method           VARCHAR(128),
    service_type             VARCHAR(16),
    business_key             VARCHAR(48),
    state_id_compensated_for VARCHAR(50),
    state_id_retried_for     VARCHAR(50),
    gmt_started              TIMESTAMP(3) NOT NULL,
    is_for_update            BOOLEAN,
    input_params             TEXT,
    output_params            TEXT,
    status                   VARCHAR(2)   NOT NULL,
    excep BYTEA,
    gmt_end                  TIMESTAMP(3) DEFAULT now(),
    CONSTRAINT pk_seata_state_inst PRIMARY KEY (id, machine_inst_id)
);
```

## 修改启动配置

> 文件位置：`/config/registry.conf`

```conf
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
