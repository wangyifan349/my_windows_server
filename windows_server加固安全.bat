# PowerShell脚本 - Windows Server  安全性配置
#虚拟机测试下再用吧，某种程度加固windows server服务器。


# 检查脚本是否以管理员身份运行
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # 以管理员权限重新启动脚本
    Write-Warning "您没有管理员权限运行此脚本！请以管理员身份重新运行此脚本！"
    if ($psISE) {
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
        $newProcess.Arguments = $myInvocation.MyCommand.Definition;
        $newProcess.Verb = "runas";
        [System.Diagnostics.Process]::Start($newProcess);
        $psISE.CurrentPowerShellTab.Close($false)
    } else {
        Start-Process PowerShell -ArgumentList "-File", ('"' + $myInvocation.MyCommand.Definition + '"'), "-Verb", "RunAs"
    }
    exit
}

############################
netsh advfirewall firewall add rule name="Allow RDP Inbound" dir=in action=allow protocol=TCP localport=3389
netsh advfirewall firewall add rule name="Allow RDP Outbound" dir=out action=allow protocol=TCP localport=3389
echo RDP firewall rules added.
#############################为了保险，确保执行了这条命令，防止短了连接。

# 关闭不安全或安全性较差的服务
$servicesToDisable = @("telnet", "RemoteRegistry", "lmhosts")
foreach ($service in $servicesToDisable) {
    try {
        Write-Host "Disabling service: $service"
        Set-Service -Name $service -StartupType Disabled
        Stop-Service -Name $service -Force
    } catch {
        Write-Host "Error disabling service: $service"
    }
}

# 询问用户需要允许的端口，逗号分隔
$userInput = Read-Host "Please enter the ports you want to allow, separated by commas (e.g., 80,443)"
$allowedPorts = $userInput -split ',' | ForEach-Object { $_.Trim() }

# 配置Windows防火墙 - 重置并设置规则
Write-Host "Resetting Windows Firewall to default..."
netsh advfirewall reset

Write-Host "Blocking all inbound connections except those allowed..."

netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound

#放行3389端口
REM 添加一条防火墙规则，允许TCP 3389端口的入站连接（远程桌面）
netsh advfirewall firewall add rule name="Allow RDP Inbound" dir=in action=allow protocol=TCP localport=3389
REM 添加一条防火墙规则，允许TCP 3389端口的出站连接（远程桌面）
netsh advfirewall firewall add rule name="Allow RDP Outbound" dir=out action=allow protocol=TCP localport=3389

echo RDP firewall rules added.

foreach ($port in $allowedPorts) {
    if ($port -match '^\d+$') {
        Write-Host "正在允许入站端口：$port"
        netsh advfirewall firewall add rule name="Allow Port $port" dir=in action=allow protocol=TCP localport=$port
    } else {
        Write-Host "无效的端口号：$port。跳过..."
    }
}

# 最小化系统日志记录
# 输出信息到控制台，通知用户正在减少事件日志大小
Write-Host "Minimizing event logging..."

# 定义一个数组，包含需要修改的日志名称
$logNames = @("Application", "Security", "System", "Setup")

# 遍历数组中的每个日志名称
foreach ($logName in $logNames) {
    # 使用wevtutil命令行工具设置指定日志的存储属性
    # 关闭日志的自动备份功能，并将最大大小设置为最小（1024字节）
    wevtutil sl $logName /retention:false /maxsize:1024
}
#这只会留有很少的记录。

# 禁用不必要的审计策略
auditpol /set /category:"*" /success:disable /failure:disable
#如果不需要系统还原点，可以禁用系统还原功能
Disable-ComputerRestore -Drive "C:\"
#如果不需要错误报告服务，可以将其禁用
Stop-Service WerSvc
Set-Service -Name WerSvc -StartupType Disabled

# 清除系统过去的事件日志
foreach ($logName in $logNames) {
    Write-Host "Clearing $logName log..."
    try {
        wevtutil cl $logName
    } catch {
        Write-Host "Error clearing $logName log"
    }
}
#诊断策略服务 - 用于问题诊断和报告。
net stop "DPS"
sc config "DPS" start= disabled
#数据收集和发布服务 - 收集系统信息供性能监控。
net stop "WdiServiceHost"
sc config "WdiServiceHost" start= disabled
#远程注册表服务 - 允许远程用户修改注册表。
net stop "RemoteRegistry"
sc config "RemoteRegistry" start= disabled

#防火墙服务 - 记录防火墙活动。

net stop "MpsSvc"
sc config "MpsSvc" start= disabled
#安全中心服务 - 监控安全设置和推荐。

net stop "wscsvc"
sc config "wscsvc" start= disabled
#Windows 更新服务 - 记录更新安装的历史。

net stop "wuauserv"
sc config "wuauserv" start= disabled
#任务计划程序 - 可能被用来记录或触发定时任务。

net stop "Task Scheduler"
sc config "Schedule" start= disabled

#Windows 事件日志服务 - 负责记录系统和应用程序事件。
net stop "Windows Event Log"
sc config "eventlog" start= disabled


# 完成
Write-Host "Script execution completed."

# 警告信息：停止和禁用事件日志服务可能有风险
Write-Host "WARNING: 关闭日至可能造成风险。"

# 定义一个数组，包含可能需要停止和禁用的服务名称
$serviceNames = @("EventLog", "wevtsvc", "Wecsvc", "EventSystem")


# 遍历数组中的每个服务名称
foreach ($serviceName in $serviceNames) {
    # 输出当前正在停止的服务名称
    Write-Host "正在停止服务：$serviceName"
    # 尝试停止服务
    try {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        Write-Host "服务已停止：$serviceName"
    } catch {
        Write-Host "停止服务失败：$serviceName"
    }
    # 输出当前正在禁用的服务名称
    Write-Host "正在禁用服务：$serviceName"
    # 尝试禁用服务
    try {
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
        Write-Host "服务已禁用：$serviceName"
    } catch {
        Write-Host "禁用服务失败：$serviceName"
    }
}
# 输出信息表示脚本执行完毕
Write-Host "事件日志服务已停止并禁用。"
############################
netsh advfirewall firewall add rule name="Allow RDP Inbound" dir=in action=allow protocol=TCP localport=3389
netsh advfirewall firewall add rule name="Allow RDP Outbound" dir=out action=allow protocol=TCP localport=3389
echo RDP firewall rules added.
#############################为了保险，确保再执行这条命令
# 启用并启动Windows Defender服务
$defenderServiceName = "WinDefend"

# 检查Windows Defender服务是否存在
if (Get-Service -Name $defenderServiceName -ErrorAction SilentlyContinue) {
    try {
        # 将Windows Defender服务设置为自动启动
        Set-Service -Name $defenderServiceName -StartupType Automatic
        Write-Host "Windows Defender服务已设置为自动启动。"

        # 如果Windows Defender服务尚未运行，则启动该服务
        if ((Get-Service -Name $defenderServiceName).Status -ne 'Running') {
            Start-Service -Name $defenderServiceName
            Write-Host "Windows Defender服务已启动。"
        } else {
            Write-Host "Windows Defender服务已经在运行。"
        }
    } catch {
        Write-Error "启用或启动Windows Defender服务时发生错误: $_"
    }
} else {
    Write-Warning "此系统上未找到Windows Defender服务。"
}
# 设置遥感服务的启动类型为禁用
Set-Service -Name DiagTrack -StartupType Disabled
# 停止遥感服务
Stop-Service -Name DiagTrack -Force
# 设置Windows Update服务的启动类型为禁用
Set-Service -Name wuauserv -StartupType Disabled
# 停止Windows Update服务，这些可能对安全造成负面影响，最好确保有镜像备份。
Stop-Service -Name wuauserv -Force
