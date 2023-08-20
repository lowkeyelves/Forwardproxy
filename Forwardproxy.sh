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
  sudo chmod +x caddy  
  sudo mv caddy /usr/bin/
  sudo mkdir /etc/caddy
  sudo touch /etc/caddy/Caddy.json

  # 创建caddy用户和组
  sudo groupadd caddy
  sudo useradd -g caddy caddy

  # 创建caddy.service
  caddy_service="[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target

[Service]
User=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/caddy.json
ExecReload=/usr/bin/caddy reload --config /etc/caddy/caddy.json
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
"
echo "$caddy_service" | sudo tee $CADDY_SERVICE > /dev/null
  
}

# 卸载Caddy
function uninstall_caddy(){

  sudo rm -rf /usr/bin/caddy
  sudo rm -rf /etc/caddy
  sudo rm -rf $CADDY_SERVICE

}

# 配置Caddy
function configure_caddy(){
  
# 开启端口
  sudo ufw allow 22
  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw allow 443/udp
  sudo ufw enable

  
  # 读取用户输入
  read -p "请输入域名:" domain
  read -p "请输入邮箱:" email  
  read -p "请输入用户名:" proxy_user
  read -p "请输入密码:" proxy_pass

  # 生成配置
  cat <<EFC > $CADDY_CONFIG
{
    "admin": {"disabled": true},
    "apps": {
        "http": {
            "servers": {
                "srv0": {
                    "listen": [":443"],
                    "logs": {},
                    "routes": [{
                        "handle": [{
                            "handler": "forward_proxy",
                            "hide_ip": true,  
                            "hide_via": true,
                            "auth_user": "$proxy_user", 
                            "auth_pass": "$proxy_pass"  
                        }]
                    }, 
                    {
                    "match": [{"host": ["$domain"]}],  
                    "handle": [{
                        "handler": "file_server",
                        "root": "/var/www/$domain"   
                    }],
                    "terminal": false
                    }],
                    "tls_connection_policies": [{
                        "match": {"sni": ["$domain"]}  
                    }],
                    "experimental_http3": true,     
                    "allow_h2c": false      
                }
            }
        },
        "tls": {
            "automation": {
                "policies": [{
                    "subjects": ["$domain"],  
                    "issuer": {
                        "email": "$email",  
                        "module": "acme"
                    }
                }]
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

# 重启Caddy
function restart_caddy(){
  sudo systemctl restart caddy
}

# 停止Caddy
function stop_caddy(){
  sudo systemctl stop caddy
}  

# 查看Caddy状态
function check_status(){
  sudo systemctl status caddy
}

# 切换BBR状态
function toggle_bbr(){

  # 判断BBR状态
  bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')

  if [ "$bbr_status" == "bbr" ]; then
    # 关闭BBR
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=cubic" | sudo tee -a /etc/sysctl.conf
  else
    # 开启BBR
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
  fi

  # 应用更改
  sudo sysctl -p
  
}

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
  read -p "请输入选择:" option

  case $option in
  1)
    install_caddy
    ;;
  2)
    uninstall_caddy
    ;;
  3) 
    configure_caddy
    ;;
  4)
    restart_caddy  
    ;;
  5)
    stop_caddy
    ;;
  6)
    check_status
    ;;
  7)
    exit 0
    ;;  
  8) 
    main_menu
    ;;
  9)
    toggle_bbr
    ;;
  *)
    echo "无效选择,请重试!"
    main_menu  
    ;;
  esac

}


  
# 运行主菜单
main_menu
