#!/bin/bash

# 定义容器名
NAME='peer2profit'

# 自定义字体彩色，read 函数，安装依赖函数
red(){ echo -e "\033[31m\033[01m$1$2\033[0m"; }
green(){ echo -e "\033[32m\033[01m$1$2\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1$2\033[0m"; }
reading(){ read -rp "$(green "$1")" "$2"; }

# 必须以root运行脚本
check_root(){
  [[ $(id -u) != 0 ]] && red " The script must be run as root, you can enter sudo -i and then download and run again." && exit 1
}

# 判断系统，并选择相应的指令集
check_operating_system(){
  CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)"
       "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)"
       "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
       "$(grep . /etc/redhat-release 2>/dev/null)"
       "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')"
      )

  for i in "${CMD[@]}"; do SYS="$i" && [[ -n $SYS ]] && break; done

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|amazon linux|alma|rocky")
  RELEASE=("Debian" "Ubuntu" "CentOS")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove")

  for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
  done

  [[ -z $SYSTEM ]] && red " ERROR: The script supports Debian, Ubuntu, CentOS or Alpine systems only.\n" && exit 1
}

# 判断宿主机的 IPv4 或双栈情况,没有拉取不了 docker
check_ipv4(){
  ! curl -s4m8 ip.sb | grep -q '\.' && red " ERROR：The host must have IPv4. " && exit 1
}

# 判断 CPU 架构
check_virt(){
  ARCHITECTURE=$(uname -m)
  case "$ARCHITECTURE" in
    aarch64 ) ARCH=arm64v8;;
    x64|x86_64 ) ARCH=latest;;
    * ) red " ERROR: Unsupported architecture: $ARCHITECTURE\n" && exit 1;;
  esac
}

# 输入 p2pclient 的个人 信息
input_token(){
  [ -z $P2PEMAIL ] && reading " Enter your Email, if you do not find it, open https://p2pr.me/164225539661e2d42426a2f: " P2PEMAIL
}

container_build(){
  # 宿主机安装 docker
  green "\n Install docker.\n "
  if ! systemctl is-active docker >/dev/null 2>&1; then
    echo -e " \n Install docker \n " 
    if [ $SYSTEM = "CentOS" ]; then
      ${PACKAGE_INSTALL[int]} yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo &&
      ${PACKAGE_INSTALL[int]} docker-ce docker-ce-cli containerd.io
      systemctl enable --now docker
    else
      ${PACKAGE_INSTALL[int]} docker.io
    fi
  fi

  # 删除旧容器（如有）
  docker ps -a | awk '{print $NF}' | grep -qw "$NAME" && yellow " Remove the old peer2profit container.\n " && docker rm -f "$NAME" >/dev/null 2>&1

  # 创建容器
  yellow " Create the peer2profit container.\n "
  docker rm -f peer2profit || true && docker run -d --restart always -e P2P_EMAIL="$P2PEMAIL" --name peer2profit peer2profit/peer2profit_linux:latest >/dev/null 2>&1

  # 创建 Towerwatch
  [[ ! $(docker ps -a) =~ watchtower ]] && yellow " Create TowerWatch.\n " && docker run -d --name watchtower --restart always -p 2095:8080 -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --cleanup >/dev/null 2>&1
}

# 显示结果
result(){
  green " Finish \n"
}

# 卸载
uninstall(){
  docker rm -f $(docker ps -a | grep -w "$NAME" | awk '{print $1}')
  docker rmi -f $(docker images | grep peer2profit/peer2profit_linux | awk '{print $3}')
  green "\n Uninstall containers and images complete.\n"
  sudo kill -9 $(pidof p2pclient)
  exit 0
}

# 传参
while getopts "UuM:m:" OPTNAME; do
  case "$OPTNAME" in
    'U'|'u' ) uninstall;;
    'M'|'m' ) P2PEMAIL=$OPTARG;;
  esac
done

# 主程序
check_root
check_operating_system
check_ipv4
check_virt
input_token
ARCHH=$(uname -m)
case "$ARCHH" in
x86_64 ) ARCHITECTUREH="amd64";;
* ) ARCHITECTUREH="i386";;
esac
if [ $SYSTEM = "CentOS" ]; then
    yum update
    yum install -y wget
    rm -rf *p2pclient*
    rpm -e p2pclient
    wget https://github.com/spiritLHLS/peer2profit-one-click-command-installation/raw/main/p2pclient-0.61-1.el8.x86_64.rpm
    rpm -ivh p2pclient-0.61-1.el8.x86_64.rpm
    nohup p2pclient -l "$P2PEMAIL" >/dev/null 2>&1 &
    rm -rf p2pclient-0.61-1.el8.x86_64.rp
else
    apt-get update
    apt-get install sudo -y
    apt-get install curl -y
    apt-get install wget -y
    sudo dpkg -P p2pclient
    if [ $ARCHITECTUREH = "amd64" ]; then
        rm -rf *p2p*
        wget https://github.com/spiritLHLS/peer2profit-one-click-command-installation/raw/main/p2pclient_0.60_amd64.deb
        dpkg -i p2pclient_0.60_amd64.deb
        nohup p2pclient -l "$P2PEMAIL" >/dev/null 2>&1 &
        rm -rf p2pclient_0.60_amd64.deb*
    else
        rm -rf *p2p*
        wget https://github.com/spiritLHLS/peer2profit-one-click-command-installation/raw/main/p2pclient_0.60_i386.deb
        dpkg -i p2pclient_0.60_i386.deb
        nohup p2pclient -l "$P2PEMAIL" >/dev/null 2>&1 &
        rm -rf p2pclient_0.60_i386.deb*
    fi
    if [ $? -ne 0 ]; then
        container_build
    else
        echo ""
    fi
fi
result
