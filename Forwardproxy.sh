#!/bin/bash

# 脚本常量
CADDY_SERVICE="/etc/systemd/system/caddy.service"
CADDY_CONFIG="/etc/caddy/caddy.json" 

# 安装Caddy
function install_caddy(){

  # 配置BBR
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p

  # 安装需要的软件
  sudo apt update
  sudo apt install software-properties-common
  sudo add-apt-repository ppa:longsleep/golang-backports
  sudo apt install golang-go

  # 安装xcaddy
  sudo go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

  # 编译caddy
  sudo ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@latest

  # 设置权限
  sudo chmod +x ~/go/bin/caddy  
  sudo mv ~/go/bin/caddy /usr/local/bin/

  # 创建caddy用户和组
  sudo groupadd caddy
  sudo useradd -g caddy caddy

  # 创建caddy.service
  caddy_service="[Unit]\nDescription=Caddy\nDocumentation=https://caddyserver.com/docs/\nAfter=network.target network-online.target\nRequires=network-online.target\n\n[Service]\nUser=caddy\nGroup=caddy\nExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile\nExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile\nTimeoutStopSec=5s\nLimitNOFILE=1048576\nLimitNPROC=512\nPrivateTmp=true\nProtectSystem=full\nAmbientCapabilities=CAP_NET_BIND_SERVICE\n\n[Install]\nWantedBy=multi-user.target"

  echo "$caddy_service" | sudo tee $CADDY_SERVICE > /dev/null
  
}

# 卸载Caddy
function uninstall_caddy(){

  sudo rm -rf /usr/local/bin/caddy
  sudo rm -rf /etc/caddy
  sudo rm -rf $CADDY_SERVICE

}

# 配置Caddy
function configure_caddy(){
  
  # 开启端口
  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw allow 443/udp
  sudo ufw enable

  # 创建配置目录
  sudo mkdir -p /etc/caddy
  
  # 读取用户输入
  read -p "请输入域名:" domain
  read -p "请输入邮箱:" email  
  read -p "请输入用户名:" proxy_user
  read -p "请输入密码:" proxy_pass

  # 生成配置
  cat <<EFC > $CADDY_CONFIG
{
  "apps": {
    "http": {
      "servers": {
        "srv0": {
          "listen": [":443"], 
          "routes": [
            {
              "handle": [
                {
                  "handler": "forward_proxy",
                  "hide_ip": true,
                  "hide_via": true,
                  "auth_user": "$proxy_user",
                  "auth_pass": "$proxy_pass"
                }
              ]
            },
            {
              "match": [
                {
                  "host": ["$domain"]
                }
              ],
              "handle": [
                {
                  "handler": "file_server",
                  "root": "/var/www/$domain"
                }
              ]
            }
          ]
        }
      }
    },
    "tls": {
      "automation": {        
        "policies": [
          {            
            "subjects": ["$domain"],
            "issuer": {
              "email": "$email",
              "module": "acme"
            }
          }
        ]
      }
    }
  }  
}
EFC

  # 设置网站目录权限
  sudo mkdir -p /var/www/$domain
  sudo chown -R caddy:caddy /var/www/$domain  

  # 重载Caddy服务
  sudo systemctl restart caddy

  # 等待证书申请
  echo "等待证书申请完成..."
  sleep 15

  # 检查申请结果
  if [ -d "/etc/ssl/caddy/$domain" ]; then
    echo "证书申请成功!"
  else
    echo "证书申请失败!"
  fi  

}

# 其他函数(原封不动复制) 
...

# 主菜单显示
function main_menu(){

cat <<EFC  
Caddy 一键安装脚本

1. 安装Caddy
2. 卸载Caddy
3. 配置Caddy

4. 重启Caddy  
5. 停止Caddy
6. 查看状态

7. 退出脚本
8. 重新进入菜单
9. 开启/关闭BBR加速

EFC

# 读取选择
...

}
  
# 运行主菜单
main_menu
