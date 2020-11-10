#!/bin/sh
mkdir -p /opt/script;
cd /opt/script;
## 安装docker
wget https://get.docker.com -q -O - > docker-script.sh;
chmod 777 docker-script.sh;
sh docker-script.sh;
## 启动docker
systemctl start docker;
## 安装docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose;
sudo chmod +x /usr/local/bin/docker-compose;
## 安装dive
curl -OL https://github.com/wagoodman/dive/releases/download/v0.9.2/dive_0.9.2_linux_amd64.rpm;
rpm -i dive_0.9.2_linux_amd64.rpm;