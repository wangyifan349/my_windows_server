#!/bin/bash

# 确保脚本以root权限运行
# 检查当前是否为root用户
if [ "$(id -u)" != "0" ]; then
    echo "该脚本需要root权限，现在将尝试以root权限重新运行脚本。"
    # 使用sudo重新执行当前脚本
    sudo bash "$0" "$@"
    # 退出当前的脚本
    exit $?
fi

# 停止并禁用unattended-upgrades服务
systemctl stop unattended-upgrades
systemctl disable unattended-upgrades

# 修改APT配置以阻止自动更新
APT_AUTO_UPGRADE_CONF="/etc/apt/apt.conf.d/20auto-upgrades"
if [ -f "$APT_AUTO_UPGRADE_CONF" ]; then
    echo "APT::Periodic::Update-Package-Lists \"0\";" | tee $APT_AUTO_UPGRADE_CONF
    echo "APT::Periodic::Download-Upgradeable-Packages \"0\";" | tee -a $APT_AUTO_UPGRADE_CONF
    echo "APT::Periodic::AutocleanInterval \"0\";" | tee -a $APT_AUTO_UPGRADE_CONF
    echo "APT::Periodic::Unattended-Upgrade \"0\";" | tee -a $APT_AUTO_UPGRADE_CONF
else
    echo "$APT_AUTO_UPGRADE_CONF 文件不存在。创建文件并设置禁止自动更新。"
    echo "APT::Periodic::Update-Package-Lists \"0\";" | tee $APT_AUTO_UPGRADE_CONF
    echo "APT::Periodic::Download-Upgradeable-Packages \"0\";" | tee -a $APT_AUTO_UPGRADE_CONF
    echo "APT::Periodic::AutocleanInterval \"0\";" | tee -a $APT_AUTO_UPGRADE_CONF
    echo "APT::Periodic::Unattended-Upgrade \"0\";" | tee -a $APT_AUTO_UPGRADE_CONF
fi

# apt-daily.timer 和 apt-daily-upgrade.timer: 这些是用于触发APT的日常更新和升级任务的定时器。
# 它们不会发送个人数据，但会自动下载和安装更新。
systemctl stop apt-daily.timer
systemctl disable apt-daily.timer
systemctl stop apt-daily-upgrade.timer
systemctl disable apt-daily-upgrade.timer

# PackageKit: 是一个用于处理软件包的工具，可以在后台执行更新。
# 它可能会向软件仓库发送查询以检查更新，但不会发送个人数据。
systemctl stop packagekit.service
systemctl disable packagekit.service
systemctl stop packagekit-offline-update.service
systemctl disable packagekit-offline-update.service

# Update Notifier: 用于通知桌面用户有可用的软件更新。
# 这个服务不会发送数据，但会在本地检查更新。
systemctl stop update-notifier.service
systemctl disable update-notifier.service

# snapd.refresh.timer: 如果您使用Snap包，该定时器用于触发自动更新。
# 它将检查Snap Store中的更新，但不会发送个人数据。
systemctl stop snapd.refresh.timer
systemctl disable snapd.refresh.timer

# unattended-upgrades.service: 用于自动安装安全更新。
# 这个服务不会发送个人数据，但会自动下载和安装安全更新。
systemctl stop unattended-upgrades.service
systemctl disable unattended-upgrades.service

# apport.service: Ubuntu中的错误报告系统，自动收集崩溃报告和错误信息。
# 如果用户同意，这些信息可以被发送到Ubuntu开发者以帮助改进软件。
systemctl stop apport.service
systemctl disable apport.service
# 永久禁用Apport
sed -i 's/enabled=1/enabled=0/' /etc/default/apport

# popularity-contest: 用于收集匿名的软件使用统计信息，并发送给Ubuntu开发者。
# 这个信息有助于决定哪些软件包应该被优先考虑。
apt-get remove --purge popularity-contest -y

# whoopsie.service: 一个错误报告工具，将崩溃报告发送至Ubuntu的错误追踪系统。
# 这些报告可以包含关于软件错误的信息，但不应该包含个人数据，除非用户在报告中包含了。
systemctl stop whoopsie.service
systemctl disable whoopsie.service

# motd-news: Message of the Day新闻服务，显示登录时的新闻和信息。
# 它不会发送个人数据，但会从Ubuntu服务器获取信息。
sed -i 's/enabled=1/enabled=0/' /etc/default/motd-news

# ubuntu-report: 服务会发送系统硬件和软件统计信息到Canonical。
# 这些信息用于改善Ubuntu，但如果你不希望分享，可以禁用。
ubuntu-report -f send no
apt reove ubuntu-report -y
#可以删除它。

# canonical-livepatch: 服务允许在不重启的情况下应用内核安全更新。
# 它会向Canonical发送一些系统信息以管理更新，但不包括个人数据。
canonical-livepatch disable

# systemd-timesyncd: 网络时间同步服务，保持系统时间准确。
# 它会与时间服务器通信进行时间同步，但不会发送个人数据。
systemctl stop systemd-timesyncd
systemctl disable systemd-timesyncd
#某些 systemd 服务可能会收集和发送使用数据。要查看和管理 systemd 服务
#systemctl list-units --type=service


#popularity-contest，这个程序会周期性地报告您使用的软件包的匿名统计信息。
sudo dpkg-reconfigure popularity-contest


# 禁用Snap自动更新（如果Snap已安装）
if command -v snap &> /dev/null; then
    # 设定更新频率为每年的1月和7月的第一个星期二
    sudo snap set system refresh.timer=fri,23:59
else
    echo "Snap未安装，跳过Snap自动更新的禁用。"
fi

echo "所有自动更新已禁用。"
# 停止并禁用账户服务守护进程 (accounts-daemon.service)
# 用途: 管理用户账户信息。如果不需要动态地更改用户账户，可以禁用。
sudo systemctl stop accounts-daemon.service
sudo systemctl disable accounts-daemon.service

# 停止并禁用 Avahi mDNS/DNS-SD 服务发现守护进程 (avahi-daemon.service)
# 用途: 实现网络服务发现。如果不需要局域网内的设备发现，可以禁用。
sudo systemctl stop avahi-daemon.service
sudo systemctl disable avahi-daemon.service

# 停止并禁用蓝牙守护进程 (bluetooth.service)
# 用途: 管理蓝牙硬件和提供蓝牙服务。如果不使用蓝牙设备，可以禁用。
sudo systemctl stop bluetooth.service
sudo systemctl disable bluetooth.service

sudo cat > /etc/systemd/resolved.conf <<EOF
[Resolve]          # 开始 [Resolve] 部分，指定解析器的设置
DNS=1.1.1.1 1.0.0.1 208.67.222.222 208.67.220.220 8.8.8.8
DNSOverTLS=yes     # 启用 DNS-over-TLS，加密 DNS 查询以提高隐私
DNSSEC=true        # 启用 DNSSEC，增加对 DNS 响应的验证，防止伪造
EOF                # 结束 heredoc，上述文本被写入 /etc/systemd/resolved.conf

# 启用 systemd-resolved 服务，使其在系统启动时自动运行
sudo systemctl enable systemd-resolved
# 立即启动 systemd-resolved 服务
sudo systemctl start systemd-resolved
# 重新加载 systemd 的配置文件，以便它知道有关新服务的信息
sudo systemctl daemon-reload
# 重新启动 systemd-resolved 服务，以应用最近的配置更改
sudo systemctl restart systemd-resolved

# 重启网络服务
#systemctl restart networking

# 更新rsyslog配置以仅记录紧急和警告级别的日志
cat > /etc/rsyslog.conf <<'EOF'
# /etc/rsyslog.conf configuration file for rsyslog
# For more information install rsyslog-doc and see
# /usr/share/doc/rsyslog-doc/html/configuration/index.html

# 仅记录紧急和警告级别的消息
*.emerg;*.alert                        /var/log/critical

# 忽略其他级别的消息
*.info;*.notice;*.warn;*.err;*.crit;*.debug     ~
EOF

# 重启rsyslog服务以应用配置更改
systemctl restart rsyslog

# 更新systemd-journald配置以仅记录紧急和警告级别的日志
cat > /etc/systemd/journald.conf <<'EOF'
# /etc/systemd/journald.conf
[Journal]
# 设置日志级别
MaxLevelStore=alert
MaxLevelSyslog=alert
MaxLevelKMsg=alert
MaxLevelConsole=alert
MaxLevelWall=alert
EOF


logs=(
  "/var/log/syslog"
  "/var/log/kern.log"
  "/var/log/auth.log"
  "/var/log/apt/history.log"
  "/var/log/dpkg.log"
)

# 删除指定日志文件及其相关的历史和.gz压缩文件
for log in "${logs[@]}"
do
  # 删除当前日志文件
  if sudo rm -f "$log"; then
    echo "已成功删除文件: $log"
  else
    echo "没有权限删除文件: $log"
    echo "请输入密码以获取权限并删除文件..."
    if sudo rm -f "$log"; then
      echo "已成功删除文件: $log"
    else
      echo "无法删除文件: $log"
    fi
  fi

  # 删除日志历史文件和.gz压缩文件
  dir=$(dirname "$log")
  filename=$(basename "$log")
  history_and_gz_files=$(ls -1 "$dir/$filename".* 2>/dev/null | grep -E '\.gz$|\.1$')

  for history_and_gz_file in $history_and_gz_files
  do
    if sudo rm -f "$history_and_gz_file"; then
      echo "已成功删除文件: $history_and_gz_file"
    else
      echo "没有权限删除文件: $history_and_gz_file"
      echo "请输入密码以获取权限并删除文件..."
      if sudo rm -f "$history_and_gz_file"; then
        echo "已成功删除文件: $history_and_gz_file"
      else
        echo "无法删除文件: $history_and_gz_file"
      fi
    fi
  done
done



# 重启systemd-journald服务以应用配置更改
systemctl restart systemd-journald

# 检查是否是 Debian 系统
if [[ -e /etc/debian_version ]]; then
    # 是 Debian 系统，创建 APT pinning 配置文件
    PIN_FILE="/etc/apt/preferences.d/pin-kernel"
    
    echo "检测到 Debian 系统。正在设置 APT pinning 来阻止内核自动更新。"
    
    # 写入配置以阻止内核包更新
    cat <<EOF >"$PIN_FILE"
Package: linux-image-*
Pin: release *
Pin-Priority: -1

Package: linux-headers-*
Pin: release *
Pin-Priority: -1
EOF
    
    echo "APT pinning 配置已写入 $PIN_FILE。"
else
    echo "未检测到 Debian 系统。没有执行任何操作。"
fi
apt remove  ubuntu-report  -y


#systemctl list-units --state=running
#当前正在运行的程序
#如果你想查看所有的服务（无论它们是否在运行）
#systemctl list-units --type=service --all

#apt install ufw -y
#apt install tor torsocks
#wget https://github.com/XTLS/Xray-install/raw/main/install-release.sh
#使用代理分流功能，完全禁止ubuntu的流量通过即可直接拦截所有的ubuntu系统的流量。具体开发请参考xray、trojan-go分流规则。ufw配置。
#我们不太可能去查询所有的服务项那些发送了哪些遥感，通过xray直接禁止全部debian、ubuntu的全部域名，是最好的办法。但注意，这并不意味着你的设备是隐私的，因为你的设备自动产生了大量记录。
