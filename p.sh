#!/bin/csh
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && exit 1

ARCH=$(uname -m)
case "$ARCH" in
x86_64 ) ARCHITECTURE="amd64";;
* ) ARCHITECTURE="i386";;
esac

# 传参
while getopts "UuM:m:" OPTNAME; do
  case "$OPTNAME" in
    'U'|'u' ) uninstall;;
    'M'|'m' ) P2PEMAIL=$OPTARG;;
  esac
done

# 输入 p2pclient 的个人 信息
input_token(){
  [ -z $P2PEMAIL ] && reading " Enter your Email, if you do not find it, open https://p2pr.me/164225539661e2d42426a2f: " P2PEMAIL
}

SPP=$(./etc/os-release && echo "$VERSION_ID")

sudo kill -9 $(pidof p2pclient)

if [ $SYSTEM = "CentOS" ]; then
    yum update
    yum install -y wget
    rm -rf *p2pclient*
    rpm -e p2pclient
    wget https://github.com/spiritLHLS/Hang-up-items/raw/main/p2pclient-0.61-1.el8.x86_64.rpm
    rpm -ivh p2pclient-0.61-1.el8.x86_64.rpm
    nohup p2pclient -l "$P2PEMAIL" >/dev/null 2>&1 &
    rm -rf p2pclient-0.61-1.el8.x86_64.rp
else
    apt-get update
    apt-get install sudo -y
    apt-get install curl -y
    apt-get install wget -y
    sudo dpkg -P p2pclient
    if [ $ARCHITECTURE = "amd64" ]; then
        rm -rf *p2p*
        wget https://github.com/spiritLHLS/Hang-up-items/raw/main/p2pclient_0.60_amd64.deb
        dpkg -i p2pclient_0.60_amd64.deb
        nohup p2pclient -l "$P2PEMAIL" >/dev/null 2>&1 &
        rm -rf p2pclient_0.60_amd64.deb*
    else
        rm -rf *p2p*
        wget https://github.com/spiritLHLS/Hang-up-items/raw/main/p2pclient_0.60_i386.deb
        dpkg -i p2pclient_0.60_i386.deb
        nohup p2pclient -l "$P2PEMAIL" >/dev/null 2>&1 &
        rm -rf p2pclient_0.60_i386.deb*
    fi
    if [ $? -ne 0 ]; then
        ! systemctl is-active docker >/dev/null 2>&1 && green " \n Install docker \n " && curl -sSL get.docker.com | sh
        systemctl is-enabled docker | grep -qv enabled && systemctl enable --now docker
        docker rm -f peer2profit || true && docker run -d --restart always -e P2P_EMAIL="$P2PEMAIL" --name peer2profit peer2profit/peer2profit_linux:latest 
    else
        echo "succeed"
    fi
fi

rm -rf p.sh
rm -- "$0"

