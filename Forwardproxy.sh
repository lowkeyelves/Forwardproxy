#!/bin/bash

# 脚本常量
CADDY_SERVICE="/etc/systemd/system/caddy.service"
CADDY_CONFIG="/etc/caddy/caddy.json"

# 安装Caddy
function install_caddy(){
  
  # 配置BBR加速
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p

  # 更新软件源
  sudo apt update  

  # 安装所需软件
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
  cat <<EOF > $CADDY_CONFIG
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
EOF

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

# 主菜单
function main_menu(){

  cat <<EOF
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

  EOF

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

# 运行脚本
main_menu
