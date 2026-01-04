# DST Server Manager

**DST Server Manager** is an automated management script for Don't Starve Together dedicated servers on macOS/Linux.
(这是一个用于 macOS/Linux 的自动化管理脚本，帮助你轻松安装、启动、停止和备份饥荒联机版专用服务器。)

## 📋 Features
- **Auto Dependency Installation**: Automatically downloads and configures SteamCMD.
- **One-Click Update**: Install or update DST dedicated server.
- **Dual Shard Support**: Automatically starts Master (Forest) and Caves shards.
- **Graceful Shutdown**: Sends save and exit signals to prevent rollback.
- **Auto Backup**: Packs and backups save files.
- **Status Monitoring**: Check server running status.

## 🚀 Quick Start

### 1. Configuration
Open `dst_manager.sh` and modify the configuration variables at the top:
```bash
CLUSTER_NAME="MyDediServer" # Your cluster folder name
```

### 2. Permissions
Run in terminal:
```bash
chmod +x dst_manager.sh
```

### 3. Install Server
Run the script and select **4. Update**:
```bash
./dst_manager.sh
# Then enter 4
```
Or run directly:
```bash
./dst_manager.sh update
```

### 4. Prepare Server Configuration (Crucial!)
Before starting, ensure you have the configuration files in the cluster directory.
**macOS Path**: `~/Documents/Klei/DoNotStarveTogether/MyDediServer`

You need to prepare the following files:
- `cluster.ini`: Cluster configuration
- `cluster_token.txt`: Server token (Get from Klei Account page)
- `Master/server.ini`: Master shard config
- `Caves/server.ini`: Caves shard config

> 💡 **Tip**: You can create a world on your local game client first, then copy the generated cluster folder to the server.

### 5. Start Server
```bash
./dst_manager.sh start
```

### 6. Common Commands
```bash
./dst_manager.sh stop    # Stop server
./dst_manager.sh restart # Restart server
./dst_manager.sh backup  # Backup server
./dst_manager.sh status  # Check status
```

## 🛠 Troubleshooting
- **Q: `screen` command not found?**
  - macOS comes with screen. Linux users run `sudo apt install screen` or `sudo yum install screen`.
- **Q: Server failed to start?**
  - Check if `cluster_token.txt` is correct.
  - Check log files (usually in `Master/server_log.txt` and `Caves/server_log.txt`).

---
Happy surviving in the Constant! 🕷️🌲🔥
