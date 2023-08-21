#!/bin/bash

# 在系统中创建 cf 命令脚本
cat > /usr/local/bin/cf <<EOF
#!/bin/bash

while : 
do
  echo "Caddy 后续操作:"
  echo "1. 重启Caddy"
  echo "2. 停止Caddy"
  echo "3. 卸载Caddy"
  echo "4. 退出"

  read -p "请输入选项[1-4]:" choice

  case \$choice in
    1)
      sudo systemctl restart caddy
      echo "Caddy已重启!"  
      ;;
    2)
      sudo systemctl stop caddy
      echo "Caddy已停止!"
      ;;
    3)
      sudo systemctl stop caddy
      sudo rm -rf /usr/bin/caddy
      sudo rm -rf /etc/caddy
      sudo rm /etc/systemd/system/caddy.service
      echo "Caddy已卸载!"
      ;;
    4)
      exit 0
      ;;
    *)
      echo "无效选项,请重试!" 
      ;;
  esac
done
EOF

sudo chmod +x /usr/local/bin/cf

# 更新系统
sudo apt update
sudo apt -y upgrade

# 启用 BBR  
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 交互菜单
while :
do
  echo "请选择:"
  echo "1. 安装Caddy"
  echo "2. 退出"

  read -p "请输入选项[1-2]:" choice
  case $choice in
    1)  
      # 安装 Caddy  
      wget -O /usr/bin/caddy_linux_amd64 https://dl.lamp.sh/files/caddy_linux_amd64
      sudo mv /usr/bin/caddy_linux_amd64 /usr/bin/caddy
      sudo chmod +x /usr/bin/caddy
      
      # 创建目录
      sudo mkdir -p /etc/caddy /var/www/html
      
      # Caddyfile 模板
      sudo tee /etc/caddy/Caddyfile <<EOF 
      {domain}:80 {
        redir https://{domain}  
      }

      {domain}:443 {
        gzip
        timeouts none  
        tls {email}
        root /var/www/html

        forwardproxy {
          basicauth {username} {password}
          hide_ip
		  probe_resistance amazon.com
        }
      }
      EOF

      # 读取用户输入
      read -p "请输入域名:" domain
      read -p "请输入邮箱:" email
      read -p "请输入用户名:" username
      read -p "请输入密码:" password

      # 替换模板变量
      sudo sed -i "s#{domain}#$domain#g" /etc/caddy/Caddyfile
      sudo sed -i "s#{email}#$email#g" /etc/caddy/Caddyfile
      sudo sed -i "s#{username}#$username#g" /etc/caddy/Caddyfile
      sudo sed -i "s#{password}#$password#g" /etc/caddy/Caddyfile

      # 创建 caddy 用户和组
      sudo groupadd --system caddy
      sudo useradd --system --gid caddy --create-home --home-dir /var/lib/caddy --shell /usr/sbin/nologin --comment "Caddy web server" caddy

      # 创建站点目录并授权  
      mkdir -p /var/www/html
      sudo chown -R caddy:caddy /var/www/html

      # 安装 caddy 服务
      sudo tee /etc/systemd/system/caddy.service <<EOF
      [Unit]
      Description=Caddy
      After=network.target network-online.target
      Requires=network-online.target

      [Service]
      User=caddy
      Group=caddy
      ExecStart=/usr/bin/caddy -conf /etc/caddy/Caddyfile -agree=true
      ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
      TimeoutStopSec=5s
      LimitNOFILE=1048576
      LimitNPROC=512
      PrivateTmp=true
      ProtectSystem=full
      AmbientCapabilities=CAP_NET_BIND_SERVICE

      [Install]
      WantedBy=multi-user.target
      EOF

      # 开启端口
      sudo ufw allow 22
      sudo ufw allow 80
      sudo ufw allow 443
      sudo ufw allow 443/udp
      sudo ufw enable

      # 安装 Caddy
      sudo systemctl start caddy

      # 等待证书申请
      sleep 15

      if [ -f "/etc/ssl/certs/ca-certificates.crt" ]; then
        echo "证书申请成功!"
      else
        echo "证书申请失败,请检查域名和邮箱是否正确!" 
      fi

      ;;

    2)
      exit 0
      ;;

    *)
      echo "无效选项,请重试!"  
      ;;
  esac
done

# 后续操作菜单
while :
do

  # 直接退出
  exit 0

done
