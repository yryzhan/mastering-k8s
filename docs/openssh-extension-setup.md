# OpenSSH Extension Setup Guide

This guide explains how to install and configure Remote-SSH extensions for Cursor/VS Code to enable remote development over SSH.

## Available Extensions

There are two main Remote-SSH extensions available:

1. **Remote - SSH** (Microsoft) - `ms-vscode-remote.remote-ssh`
   - Official Microsoft extension
   - Works with VS Code
   - May have limitations in open-source builds

2. **Open Remote - SSH** (Open Source) - `jeanp413.open-remote-ssh`
   - Open-source alternative by [jeanp413](https://github.com/jeanp413/open-remote-ssh)
   - Works with VSCodium, VS Code, and Cursor
   - Requires additional activation step (see below)
   - Supports x86_64, ARM platforms, macOS, Windows, FreeBSD

## Installing the Remote-SSH Extension

### Method 1: Install via Cursor/VS Code UI

#### For Microsoft's Remote - SSH

1. Open Cursor/VS Code
2. Click on the Extensions icon in the sidebar (or press `Cmd+Shift+X` on macOS / `Ctrl+Shift+X` on Windows/Linux)
3. Search for "Remote - SSH"
4. Find the extension published by Microsoft (`ms-vscode-remote.remote-ssh`)
5. Click the "Install" button

#### For Open Remote - SSH

1. Open Cursor/VS Code/VSCodium
2. Click on the Extensions icon in the sidebar (or press `Cmd+Shift+X` on macOS / `Ctrl+Shift+X` on Windows/Linux)
3. Search for "Open Remote - SSH"
4. Find the extension published by jeanp413 (`jeanp413.open-remote-ssh`)
5. Click the "Install" button

### Method 2: Install via Command Line

```bash
# Microsoft's Remote - SSH
code --install-extension ms-vscode-remote.remote-ssh
cursor --install-extension ms-vscode-remote.remote-ssh

# Open Remote - SSH
code --install-extension jeanp413.open-remote-ssh
cursor --install-extension jeanp413.open-remote-ssh
```

### Method 3: Install from Extensions Marketplace

1. Visit the [Remote-SSH extension page](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
2. Click "Install"
3. Your editor will open and prompt you to install the extension

## Verifying Installation

After installation, you should see:

- A new "Remote Explorer" icon in the sidebar
- An indicator in the bottom-left corner of the window showing connection status
- "Remote-SSH" commands available in the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`)

## Activating Open Remote - SSH Extension

**Important**: If you installed the Open Remote - SSH extension (`jeanp413.open-remote-ssh`), you need to enable it in your `argv.json` file.

> **Note**: This activation step is NOT needed in VSCodium since version 1.75, and is NOT needed for Microsoft's Remote - SSH extension.

### Step 1: Open Runtime Arguments

1. Press `Cmd+Shift+P` / `Ctrl+Shift+P` to open Command Palette
2. Type and select: `Preferences: Configure Runtime Arguments`
3. This will open the `argv.json` file (located at `~/.vscode-oss/argv.json` or `~/.cursor/argv.json`)

### Step 2: Enable the Extension

Add `jeanp413.open-remote-ssh` to the `enable-proposed-api` array:

```json
{
    // ... other settings ...
    "enable-proposed-api": [
        "jeanp413.open-remote-ssh"
    ]
    // ... other settings ...
}
```

If you already have other extensions in the `enable-proposed-api` array, add it to the existing list:

```json
{
    "enable-proposed-api": [
        "some-other-extension",
        "jeanp413.open-remote-ssh"
    ]
}
```

### Step 3: Restart Editor

After saving `argv.json`, restart Cursor/VS Code for the changes to take effect.

### Remote Host Requirements for Open Remote - SSH

The Open Remote - SSH extension supports the following platforms:

**Supported platforms:**

- x86_64 Debian 8+, Ubuntu 16.04+, CentOS / RHEL 7+ Linux
- ARMv7l (AArch32) Raspbian Stretch/9+ (32-bit)
- ARMv8l (AArch64) Ubuntu 18.04+ (64-bit)
- macOS 10.14+ (Mojave)
- Windows 10+
- FreeBSD 13 (requires manual remote-extension-host installation)
- DragonFlyBSD (requires manual remote-extension-host installation)

**Alpine Linux Requirements:**

If connecting to Alpine Linux, install required packages:

```bash
sudo apk add bash libstdc++
```

## Configuring SSH for Remote Development

### SSH Config File Setup

The Remote-SSH extension uses your SSH config file located at `~/.ssh/config`. Add remote hosts like this:

```ssh-config
# GitHub Codespace
Host cs.codespace-name.main
    User codespace
    ProxyCommand /opt/homebrew/bin/gh codespace ssh -c <CODESPACE-NAME> --stdio
    UserKnownHostsFile=/dev/null
    StrictHostKeyChecking no
    LogLevel quiet
    ControlMaster auto
    IdentityFile ~/.ssh/codespaces.auto

# Example: Remote Server
Host myserver
    HostName 192.168.1.100
    User username
    Port 22
    IdentityFile ~/.ssh/id_rsa

# Example: Jump Host Configuration
Host production-server
    HostName 10.0.0.50
    User deploy
    ProxyJump bastion.example.com
    IdentityFile ~/.ssh/production_key
```

### Cursor Settings for Remote-SSH

Add these settings to your Cursor `settings.json`:

```json
{
  "remote.SSH.configFile": "~/.ssh/config",
  "remote.SSH.useLocalServer": false,
  "remote.SSH.localServerDownload": "off",
  "remote.SSH.useExecServer": true,
  "remote.SSH.lockfilesInTmp": true
}
```

## Connecting to Remote Hosts

### Method 1: Using Remote Explorer

1. Click the Remote Explorer icon in the sidebar
2. Select "SSH Targets" from the dropdown
3. Click on the host you want to connect to
4. Select "Connect to Host in Current Window" or "Connect to Host in New Window"

### Method 2: Using Command Palette

1. Press `Cmd+Shift+P` / `Ctrl+Shift+P`
2. Type "Remote-SSH: Connect to Host"
3. Select your host from the list or type the hostname

### Method 3: Using Status Bar

1. Click the green indicator in the bottom-left corner
2. Select "Connect to Host"
3. Choose your remote host

## Common Remote Development Tasks

### Opening a Folder on Remote Host

```text
1. Connect to remote host
2. File > Open Folder (or Cmd+O / Ctrl+O)
3. Navigate to the desired folder on the remote system
4. Click "OK"
```

### Opening a Terminal on Remote Host

```text
1. Connect to remote host
2. Terminal > New Terminal (or Ctrl+` / Cmd+`)
3. The terminal will open in the remote host context
```

### Port Forwarding

The Remote-SSH extension automatically handles port forwarding:

1. When a service starts on the remote host (e.g., on port 8080)
2. Cursor will detect it and offer to forward the port
3. Access it locally at `http://localhost:8080`

You can also manually forward ports:

1. Press `Cmd+Shift+P` / `Ctrl+Shift+P`
2. Type "Forward a Port"
3. Enter the port number (e.g., 8080)
4. Access it at `http://localhost:8080`

## Troubleshooting

### Connection Timeout

If connection times out:

```bash
# Verify SSH connection manually
ssh -v hostname

# Check SSH config
cat ~/.ssh/config

# Test with verbose output
ssh -vvv hostname
```

### Permission Denied

```bash
# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 700 ~/.ssh

# Add key to SSH agent
ssh-add ~/.ssh/id_rsa
```

### Server Installation Issues

If the remote server fails to install VS Code Server:

1. Check available disk space on remote host:

   ```bash
   df -h
   ```

2. Manually clean VS Code Server cache:

   ```bash
   rm -rf ~/.vscode-server
   ```

3. Reconnect using Remote-SSH

### "Could not establish connection" Error

This usually means:

- SSH host is down or unreachable
- Incorrect hostname/IP address
- Firewall blocking SSH port
- SSH service not running on remote host

Solutions:

```bash
# Check if host is reachable
ping hostname

# Check if SSH port is open
nc -zv hostname 22

# Verify SSH service is running (on remote host)
sudo systemctl status sshd
```

### Extension Not Showing Up

If the Remote-SSH extension is not visible:

1. Check if it's installed:
   - Go to Extensions
   - Search for "Remote - SSH"
   - Verify "Installed" status

2. Restart Cursor/VS Code
3. Check extension logs:
   - View > Output
   - Select "Remote - SSH" from dropdown

## Advanced Configuration

### Using Jump Hosts (Bastion)

```ssh-config
# Bastion host
Host bastion
    HostName bastion.example.com
    User admin
    IdentityFile ~/.ssh/bastion_key

# Production server via bastion
Host prod-server
    HostName 10.0.0.100
    User deploy
    ProxyJump bastion
    IdentityFile ~/.ssh/prod_key
```

### Setting Remote Environment Variables

Create or edit `~/.ssh/environment` on the remote host:

```bash
KUBECONFIG=/etc/kubernetes/admin.conf
PATH=/usr/local/bin:/usr/bin:/bin
```

Enable in SSH config:

```ssh-config
Host myserver
    HostName 192.168.1.100
    User username
    PermitUserEnvironment yes
```

### Keeping Connection Alive

Add to SSH config to prevent timeout:

```ssh-config
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

## Quick Reference

### Extension Comparison

| Feature | Microsoft Remote-SSH | Open Remote-SSH |
|---------|---------------------|-----------------|
| Extension ID | `ms-vscode-remote.remote-ssh` | `jeanp413.open-remote-ssh` |
| Activation Required | No | Yes (in argv.json) |
| VSCodium Support | Limited | Yes (v1.75+) |
| Cursor Support | Yes | Yes |
| Open Source | No | Yes |
| Platform Support | Standard | Extended (FreeBSD, DragonFlyBSD) |
| GitHub Repo | Closed | [github.com/jeanp413/open-remote-ssh](https://github.com/jeanp413/open-remote-ssh) |

### Common Tasks

| Task | Command |
|------|---------|
| Install extension | Search "Remote - SSH" or "Open Remote-SSH" in Extensions |
| Activate Open Remote-SSH | `Preferences: Configure Runtime Arguments` → Add to `enable-proposed-api` |
| Connect to host | `Cmd+Shift+P` → "Remote-SSH: Connect to Host" |
| Open folder | File → Open Folder (while connected) |
| Forward port | `Cmd+Shift+P` → "Forward a Port" |
| Disconnect | Click green indicator → "Close Remote Connection" |
| View SSH config | `~/.ssh/config` |
| View extension logs | View → Output → "Remote - SSH" |

## Integration with GitHub Codespaces

The Remote-SSH extension works seamlessly with GitHub Codespaces:

1. Install the extension
2. Configure SSH config as shown in [Codespace Port Forwarding Guide](./codespace-port-forward.md)
3. Connect using the configured host

Example SSH config for Codespaces:

```ssh-config
Host cs.*
    User codespace
    ProxyCommand /opt/homebrew/bin/gh codespace ssh -c $(echo %h | cut -d. -f2) --stdio
    UserKnownHostsFile=/dev/null
    StrictHostKeyChecking no
    LogLevel quiet
```

## Notes

- The Remote-SSH extension requires SSH client to be installed on your local machine
- Remote host must have SSH server (sshd) running
- First connection may take longer as VS Code Server is installed on remote host
- Extensions need to be installed separately for remote hosts
- Settings can be configured separately for local and remote environments

## Related Documentation

- [Codespace Port Forwarding Guide](./codespace-port-forward.md) - Port forwarding with GitHub Codespaces
- [Official Microsoft Remote-SSH Documentation](https://code.visualstudio.com/docs/remote/ssh)
- [Open Remote - SSH GitHub Repository](https://github.com/jeanp413/open-remote-ssh) - Open-source Remote-SSH alternative
