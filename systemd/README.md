# Systemd Services for Terranote

This directory contains systemd service files for managing Terranote services on Linux systems.

## Services

- `terranote-adapter-telegram.service` - Telegram adapter service
- `terranote-core.service` - Core API service

## Installation

### Option 1: Using the installation script (Recommended)

The script can be run as `root` or with a user that has `sudo` privileges:

```bash
# As user with sudo (e.g., angoca)
cd /home/terranote/terranote-infra
git pull
bash systemd/install-services.sh

# Or as root
sudo bash systemd/install-services.sh
```

### Option 2: Manual installation

#### 1. Copy service files to systemd directory

```bash
sudo cp systemd/*.service /etc/systemd/system/
```

#### 2. Reload systemd configuration

```bash
sudo systemctl daemon-reload
```

#### 3. Enable services to start on boot

```bash
sudo systemctl enable terranote-adapter-telegram
sudo systemctl enable terranote-core
```

#### 4. Start services

```bash
sudo systemctl start terranote-adapter-telegram
sudo systemctl start terranote-core
```

## Management

### Check service status

```bash
sudo systemctl status terranote-adapter-telegram
sudo systemctl status terranote-core
```

### View logs (journald)

```bash
# Follow logs in real-time
sudo journalctl -u terranote-adapter-telegram -f
sudo journalctl -u terranote-core -f

# View last 100 lines
sudo journalctl -u terranote-adapter-telegram -n 100
sudo journalctl -u terranote-core -n 100

# View logs since today
sudo journalctl -u terranote-adapter-telegram --since today
sudo journalctl -u terranote-core --since today

# View logs with JSON output (for structured logs)
sudo journalctl -u terranote-adapter-telegram -o json-pretty
```

### Restart services

```bash
sudo systemctl restart terranote-adapter-telegram
sudo systemctl restart terranote-core
```

### Stop services

```bash
sudo systemctl stop terranote-adapter-telegram
sudo systemctl stop terranote-core
```

### Disable services (prevent auto-start)

```bash
sudo systemctl disable terranote-adapter-telegram
sudo systemctl disable terranote-core
```

## Logging with journald

All services are configured to use systemd's journald for logging. Logs are automatically:

- **Captured**: All stdout/stderr output is captured by journald
- **Structured**: JSON logs from Pino are preserved
- **Rotated**: journald handles log rotation automatically
- **Persistent**: Logs are stored in `/var/log/journal/` (if persistent logging is enabled)

### Enable persistent logging

By default, journald may store logs only in memory. To enable persistent storage:

```bash
# Create journal directory
sudo mkdir -p /var/log/journal
sudo chown root:systemd-journal /var/log/journal
sudo chmod 2755 /var/log/journal

# Restart journald
sudo systemctl restart systemd-journald
```

### Configure journald retention

Edit `/etc/systemd/journald.conf`:

```ini
[Journal]
Storage=persistent
SystemMaxUse=500M
SystemKeepFree=1G
SystemMaxFileSize=100M
MaxRetentionSec=1month
```

Then restart journald:

```bash
sudo systemctl restart systemd-journald
```

### Query logs efficiently

```bash
# Filter by priority (error level and above)
sudo journalctl -u terranote-adapter-telegram -p err

# Filter by time range
sudo journalctl -u terranote-adapter-telegram --since "2025-11-21 10:00:00" --until "2025-11-21 11:00:00"

# Filter by process/user
sudo journalctl _UID=$(id -u terranote)

# Combine filters
sudo journalctl -u terranote-adapter-telegram -p err --since "1 hour ago"
```

## Troubleshooting

### Service fails to start

1. Check service status:
   ```bash
   sudo systemctl status terranote-adapter-telegram
   ```

2. Check logs:
   ```bash
   sudo journalctl -u terranote-adapter-telegram -n 50
   ```

3. Verify environment file exists:
   ```bash
   ls -la /home/terranote/terranote-adapter-telegram/.env
   ```

4. Check file permissions:
   ```bash
   ls -la /home/terranote/terranote-adapter-telegram/
   ```

### Permission issues

If you encounter permission errors:

```bash
# Ensure terranote user owns the directories
sudo chown -R terranote:terranote /home/terranote/terranote-adapter-telegram
sudo chown -R terranote:terranote /home/terranote/terranote-core

# Ensure .env files are readable
chmod 600 /home/terranote/terranote-adapter-telegram/.env
chmod 600 /home/terranote/terranote-core/.env
```

### Node.js/Poetry not found

If the service fails because Node.js or Poetry is not found:

1. Check if they're in PATH:
   ```bash
   sudo -u terranote which node
   sudo -u terranote which poetry
   ```

2. If using nvm or custom installation, update the ExecStart path in the service file.

### Git safe.directory error

If you see "dubious ownership" errors when running `git pull`:

```bash
# As the user that owns the repository (e.g., angoca)
git config --global --add safe.directory /home/terranote/terranote-infra

# Or as terranote user
sudo -u terranote git config --global --add safe.directory /home/terranote/terranote-infra
```

## Security Considerations

The service files include security hardening:

- `NoNewPrivileges=true`: Prevents privilege escalation
- `PrivateTmp=true`: Uses private /tmp directory
- `ProtectSystem=strict`: Read-only access to system directories
- `ProtectHome=read-only`: Read-only access to home directories (except ReadWritePaths)
- `ReadWritePaths`: Explicitly allows write access only to service directories

## References

- [systemd.service man page](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [journalctl man page](https://www.freedesktop.org/software/systemd/man/journalctl.html)
- [systemd-journald.service](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html)
