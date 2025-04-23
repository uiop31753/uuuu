#!/bin/bash

set -e

# frp版本
FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep tag_name | cut -d '"' -f 4)
ARCH="amd64"
INSTALL_DIR="/usr/local/frp"
SERVICE_NAME=""
BINARY_NAME=""
CONF_FILE=""

info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# 选择安装类型
echo "👉 你要安装 FRP 的哪种模式？"
echo "1) frps（服务端 - 运行在公网服务器）"
echo "2) frpc（客户端 - 运行在内网机器）"
read -p "请输入选项 [1/2]: " choice

if [[ "$choice" == "1" ]]; then
  MODE="frps"
  SERVICE_NAME="frps"
  BINARY_NAME="frps"
  CONF_FILE="frps.ini"
elif [[ "$choice" == "2" ]]; then
  MODE="frpc"
  SERVICE_NAME="frpc"
  BINARY_NAME="frpc"
  CONF_FILE="frpc.ini"
else
  error "无效选项！退出"
  exit 1
fi

info "✨ 安装 FRP [$MODE] 最新版本：$FRP_VERSION"

# 下载 FRP
cd /tmp
FRP_FILE="frp_${FRP_VERSION#v}_linux_${ARCH}.tar.gz"
wget -q --show-progress https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/${FRP_FILE}
tar -xzf $FRP_FILE
cd frp_${FRP_VERSION#v}_linux_${ARCH}

# 安装目录
sudo mkdir -p $INSTALL_DIR
sudo chmod +x ${BINARY_NAME}
sudo cp ${BINARY_NAME} $INSTALL_DIR
rm -f ${BINARY_NAME}

# 配置文件
if [ "$MODE" == "frps" ]; then
  sudo tee $INSTALL_DIR/frps.ini > /dev/null <<EOF
[common]
bind_port =5244
dashboard_port = 5426
dashboard_user = ''
dashboard_pwd = ''
EOF
else
  sudo tee $INSTALL_DIR/frpc.ini > /dev/null <<EOF
[common]
server_addr = ''
server_port =''

[ssh]
type = tcp
local_port = 22
remote_port = 6022
EOF
fi

# 设置 systemd 服务
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=FRP ${MODE^^} Service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/${BINARY_NAME} -c ${INSTALL_DIR}/${CONF_FILE}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

info "🎉 FRP [$MODE] 安装完成并已启动"
info "👉 配置文件位置：$INSTALL_DIR/$CONF_FILE"
info "👉 修改配置后使用：sudo systemctl restart $SERVICE_NAME"
