# rabbitmq
## 通用脚本
[docker-compose脚本](https://github.com/uyaki/docker-script/blob/master/rabbitmq/docker-compose.yml)
## 集成delayed插件
下载对应版本的插件 [rabbitmq-delayed-message-exchange](https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/tag/v3.8.0)
### 部署后安装插件
```bash
# 拷贝到rabbitmq容器 e52d0e3251fe 中
$ docker cp /path/to/rabbitmq_delayed_message_exchange-3.8.0.ez e52d0e3251fe:/plugins
# 进入容器
$ docker exec -it e52d0e3251fe /bin/bash
# 启用插件
$ rabbitmq-plugins enable rabbitmq_delayed_message_exchange
#查看
$ rabbitmq-plugins list
# 重新启动容器
$ docker restart e52d0e3251fe
```
### 自定义Dockerfile
```Dockerfile
FROM rabbitmq:3.8-management
COPY rabbitmq_delayed_message_exchange-3.8.0.ez /plugins
RUN rabbitmq-plugins enable --offline rabbitmq_mqtt rabbitmq_federation_management rabbitmq_stomp rabbitmq_delayed_message_exchange
```
