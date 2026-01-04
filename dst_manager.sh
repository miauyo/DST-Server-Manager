#!/bin/bash

# DST Server Manager
# Author: Trae AI
# Description: Automated management script for DST dedicated servers on macOS/Linux

# ================= Configuration =================

# SteamCMD Installation Path (Will try to download if not installed)
STEAMCMD_DIR="$HOME/steamcmd"
STEAMCMD_EXEC="$STEAMCMD_DIR/steamcmd.sh"

# Game Installation Directory
INSTALL_DIR="$HOME/dst_server"

# Detect OS
OS_NAME=$(uname -s)

# Cluster Directory (Default macOS location)
# Note: Klei's default save path on macOS is usually ~/Documents/Klei/DoNotStarveTogether
# On Linux it is usually ~/.klei/DoNotStarveTogether
if [ "$OS_NAME" = "Darwin" ]; then
    CLUSTER_DIR="$HOME/Documents/Klei/DoNotStarveTogether"
else
    CLUSTER_DIR="$HOME/.klei/DoNotStarveTogether"
fi

# Your Cluster Name (Folder name)
CLUSTER_NAME="MyDediServer"

# App ID (Don't Starve Together Dedicated Server)
APP_ID=343050

# Backup Directory
BACKUP_DIR="$HOME/dst_backups"

# Auto Backup Configuration
ENABLE_AUTO_BACKUP=true
BACKUP_INTERVAL=3600 # 1 hour in seconds

# Resolve script absolute path for auto-backup
SCRIPT_PATH=$(cd "$(dirname "$0")"; pwd)/$(basename "$0")

# ===========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    printf "${GREEN}[INFO] %s${NC}\n" "$1"
}

log_warn() {
    printf "${YELLOW}[WARN] %s${NC}\n" "$1"
}

log_error() {
    printf "${RED}[ERROR] %s${NC}\n" "$1"
}

# 检查依赖
check_dependencies() {
    if [ ! -f "$STEAMCMD_EXEC" ]; then
        log_warn "SteamCMD 未找到，准备安装..."
        mkdir -p "$STEAMCMD_DIR"
        cd "$STEAMCMD_DIR"
        
        if [ "$OS_NAME" = "Darwin" ]; then
            curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz" | tar zxvf -
        else
            curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
        fi
        
        if [ -f "$STEAMCMD_EXEC" ]; then
            log_info "SteamCMD 安装成功。"
        else
            log_error "SteamCMD 安装失败，请手动安装。"
            exit 1
        fi
    fi
}

# 安装/更新服务器
update_server() {
    log_info "开始安装/更新 DST 服务器..."
    check_dependencies
    
    "$STEAMCMD_EXEC" +force_install_dir "$INSTALL_DIR" +login anonymous +app_update $APP_ID validate +quit
    
    if [ $? -eq 0 ]; then
        log_info "服务器更新完成。"
    else
        log_error "服务器更新失败。"
    fi
}

# 启动服务器
start_server() {
    log_info "正在启动服务器 ($CLUSTER_NAME)..."
    
    # 检查可执行文件
    if [ "$OS_NAME" = "Darwin" ]; then
        # macOS 可能的路径
        BIN_PATH="$INSTALL_DIR/bin/dontstarve_dedicated_server_nullrenderer.app/Contents/MacOS/dontstarve_dedicated_server_nullrenderer"
        
        # 如果上面的路径不存在，尝试 Linux 风格的路径（有时 SteamCMD 在 macOS 上也会下载这种）
        if [ ! -f "$BIN_PATH" ]; then
             BIN_PATH="$INSTALL_DIR/bin/dontstarve_dedicated_server_nullrenderer"
        fi
        
        # macOS 需要设置一些库路径
        export DYLD_LIBRARY_PATH="$INSTALL_DIR/bin:$INSTALL_DIR/bin/lib"
    else
        BIN_PATH="$INSTALL_DIR/bin/dontstarve_dedicated_server_nullrenderer"
    fi

    if [ ! -f "$BIN_PATH" ]; then
        log_error "服务器可执行文件未找到: $BIN_PATH"
        log_warn "请先运行更新命令。"
        return
    fi

    # 检查 Cluster 是否存在
    if [ ! -d "$CLUSTER_DIR/$CLUSTER_NAME" ]; then
        log_warn "Cluster 目录不存在: $CLUSTER_DIR/$CLUSTER_NAME"
        log_warn "请确保你已经生成了 cluster_token.txt 并配置了 cluster.ini"
        # 这里可以添加自动生成配置的逻辑，但为了安全起见，先只提示
    fi

    # 使用 screen 或 tmux 在后台运行 (这里使用 screen)
    if ! command -v screen > /dev/null 2>&1; then
        log_error "未找到 'screen' 命令，请先安装 screen。"
        return
    fi

    # 启动 Master
    screen -dmS "dst_master" "$BIN_PATH" -console -cluster "$CLUSTER_NAME" -shard Master
    log_info "Master 分片已在 screen 会话 'dst_master' 中启动。"

    # 启动 Caves
    screen -dmS "dst_caves" "$BIN_PATH" -console -cluster "$CLUSTER_NAME" -shard Caves
    log_info "Caves 分片已在 screen 会话 'dst_caves' 中启动。"

    # 启动自动备份
    if [ "$ENABLE_AUTO_BACKUP" = "true" ]; then
         if screen -list | grep -q "dst_backup"; then
             log_warn "自动备份进程已在运行。"
         else
             # Ensure script is executable
             if [ ! -x "$SCRIPT_PATH" ]; then
                 chmod +x "$SCRIPT_PATH"
             fi
             
             screen -dmS "dst_backup" /bin/bash -c "while true; do sleep $BACKUP_INTERVAL; \"$SCRIPT_PATH\" backup; done"
             log_info "自动备份已启动 (间隔: ${BACKUP_INTERVAL}秒)。"
         fi
    fi
}

# 停止服务器
stop_server() {
    log_info "正在停止服务器..."
    
    # 向 screen 会话发送 c_shutdown() 命令
    if screen -list | grep -q "dst_master"; then
        screen -S "dst_master" -p 0 -X stuff "c_shutdown(true)^M"
        log_info "已向 Master 发送关闭信号..."
    fi
    
    if screen -list | grep -q "dst_caves"; then
        screen -S "dst_caves" -p 0 -X stuff "c_shutdown(true)^M"
        log_info "已向 Caves 发送关闭信号..."
    fi

    # 等待一会儿让其保存
    log_info "等待服务器保存并关闭 (10秒)..."
    sleep 10
    
    # 强制杀死残留进程 (可选)
    # pkill -f dontstarve_dedicated_server_nullrenderer
}

# 备份存档
backup_server() {
    log_info "开始备份存档..."
    
    if [ ! -d "$CLUSTER_DIR/$CLUSTER_NAME" ]; then
        log_error "找不到存档目录: $CLUSTER_DIR/$CLUSTER_NAME"
        return
    fi
    
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/${CLUSTER_NAME}_backup_$TIMESTAMP.tar.gz"
    
    tar -czf "$BACKUP_FILE" -C "$CLUSTER_DIR" "$CLUSTER_NAME"
    
    if [ $? -eq 0 ]; then
        log_info "备份成功: $BACKUP_FILE"
        # 保留最近 7 天的备份，删除旧的
        find "$BACKUP_DIR" -name "${CLUSTER_NAME}_backup_*.tar.gz" -mtime +7 -delete
    else
        log_error "备份失败。"
    fi
}

# 查看状态
status_server() {
    if screen -list | grep -q "dst_master"; then
        printf "Master: ${GREEN}运行中${NC}\n"
    else
        printf "Master: ${RED}未运行${NC}\n"
    fi
    
    if screen -list | grep -q "dst_caves"; then
        printf "Caves:  ${GREEN}运行中${NC}\n"
    else
        printf "Caves:  ${RED}未运行${NC}\n"
    fi
}

# 菜单
show_menu() {
    echo "=============================="
    echo "   DST 服务器管理脚本"
    echo "=============================="
    echo "1. 启动服务器 (Start)"
    echo "2. 停止服务器 (Stop)"
    echo "3. 重启服务器 (Restart)"
    echo "4. 更新/安装服务器 (Update)"
    echo "5. 备份存档 (Backup)"
    echo "6. 查看状态 (Status)"
    echo "0. 退出 (Exit)"
    echo "=============================="
    printf "请输入选项: "
    read choice
    
    case $choice in
        1) start_server ;;
        2) stop_server ;;
        3) stop_server; sleep 5; start_server ;;
        4) update_server ;;
        5) backup_server ;;
        6) status_server ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

# 主逻辑
# 如果有参数，直接执行对应函数
if [ $# -gt 0 ]; then
    case "$1" in
        start) start_server ;;
        stop) stop_server ;;
        restart) stop_server; sleep 5; start_server ;;
        update) update_server ;;
        backup) backup_server ;;
        status) status_server ;;
        *) echo "用法: $0 {start|stop|restart|update|backup|status}" ;;
    esac
else
    # 否则显示交互菜单
    while true; do
        show_menu
        echo "按回车键继续..."
        read dummy
    done
fi
