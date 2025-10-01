# Codespace Port Forwarding Guide

This guide explains how to forward ports from your GitHub Codespace to your local machine.

## Getting Your Codespace Name

To find your codespace name, run:

```bash
# List all your codespaces
gh codespace list

# The output will show your codespace name in the first column
```

## Current Codespaces

- **`<CODESPACE-NAME>`** (Active) - *Replace with your actual codespace name*

## SSH Connection to Codespace

Before setting up port forwarding, you can connect directly to your codespace via SSH:

```bash
# Connect to codespace via SSH
gh codespace ssh -c <CODESPACE-NAME>

# Or use the SSH config (if configured)
ssh cs.<CODESPACE-NAME>.main
```

### SSH Tunnel Port Forwarding

You can also use SSH tunnels for port forwarding:

```bash
# Create SSH tunnel for port forwarding
ssh -L <local-port>:localhost:<remote-port> -c <CODESPACE-NAME>

# Examples:
ssh -L 8080:localhost:8080 -c <CODESPACE-NAME>
ssh -L 3000:localhost:3000 -c <CODESPACE-NAME>

# Multiple port forwarding via SSH tunnel
ssh -L 8080:localhost:8080 -L 3000:localhost:3000 -c <CODESPACE-NAME>
```

### SSH Config Setup

To use the SSH config method, add this to your `~/.ssh/config`:

```ssh-config
Host cs.<CODESPACE-NAME>.main
    User codespace
    ProxyCommand /opt/homebrew/bin/gh codespace ssh -c <CODESPACE-NAME> --stdio
    UserKnownHostsFile=/dev/null
    StrictHostKeyChecking no
    LogLevel quiet
    ControlMaster auto
    IdentityFile ~/.ssh/codespaces.auto
```

## Basic Port Forwarding Commands

### Forward Single Port

```bash
# Forward port 8080 from codespace to laptop
gh codespace ports forward 8080:8080 -c <CODESPACE-NAME>

# Forward port 3000 from codespace to laptop  
gh codespace ports forward 3000:3000 -c <CODESPACE-NAME>

# Forward port 8000 from codespace to laptop
gh codespace ports forward 8000:8000 -c <CODESPACE-NAME>
```

### Forward Multiple Ports

```bash
# Forward multiple ports in one command
gh codespace ports forward 8080:8080 3000:3000 8000:8000 -c <CODESPACE-NAME>
```

### Interactive Port Forwarding

```bash
# Start with one port, then add more interactively
gh codespace ports forward 8080:8080 -c <CODESPACE-NAME>

# Note: The command requires at least one port pair argument
# You can add more ports while the command is running
```

### Background Port Forwarding

```bash
# Run in background
gh codespace ports forward 8080:8080 -c <CODESPACE-NAME> &
```

## Common Development Ports

### Web Applications

```bash
# React/Next.js development server
gh codespace ports forward -c <CODESPACE-NAME> 3000:3000

# Node.js/Express applications
gh codespace ports forward -c <CODESPACE-NAME> 8080:8080

# Python Flask/Django applications
gh codespace ports forward -c <CODESPACE-NAME> 5000:5000
```

### Kubernetes Services

```bash
# Kubernetes dashboard
gh codespace ports forward -c <CODESPACE-NAME> 8001:8001

# Prometheus monitoring
gh codespace ports forward -c <CODESPACE-NAME> 9090:9090

# Grafana dashboard
gh codespace ports forward -c <CODESPACE-NAME> 3000:3000
```

### Database Connections

```bash
# PostgreSQL
gh codespace ports forward -c <CODESPACE-NAME> 5432:5432

# MySQL
gh codespace ports forward -c <CODESPACE-NAME> 3306:3306

# MongoDB
gh codespace ports forward -c <CODESPACE-NAME> 27017:27017

# Redis
gh codespace ports forward -c <CODESPACE-NAME> 6379:6379
```

## Accessing Forwarded Ports

Once ports are forwarded, access them on your local machine:

- **Web applications**: `http://localhost:8080`
- **Development servers**: `http://localhost:3000`
- **Databases**: Connect to `localhost:5432` (or respective port)

## Managing Port Forwards

### List Active Port Forwards

```bash
gh codespace ports list -c <CODESPACE-NAME>
```

### Stop Port Forwarding

```bash
# Stop specific port forward
gh codespace ports stop -c <CODESPACE-NAME> 8080

# Stop all port forwards
gh codespace ports stop -c <CODESPACE-NAME> --all
```

## Troubleshooting

### Port Already in Use

```bash
# Check what's using the port
lsof -i :8080

# Kill the process using the port
kill -9 <PID>
```

### Connection Refused

- Ensure the service is running in the codespace
- Check if the port is correct
- Verify the codespace is running

### Multiple Codespaces

If you have multiple codespaces, specify the correct one:

```bash
gh codespace ports forward <remote-port>:<local-port> -c <codespace-name>
```

### Common Error: "requires at least 1 arg(s)"

If you get the error "requires at least 1 arg(s), only received 0", you need to specify at least one port pair:

```bash
# ❌ Wrong - no port pairs specified
gh codespace ports forward -c <CODESPACE-NAME>

# ✅ Correct - specify at least one port pair
gh codespace ports forward 8080:8080 -c <CODESPACE-NAME>
```

## Quick Reference

| Service | Common Port | GitHub CLI | SSH Tunnel |
|---------|-------------|------------|------------|
| Web App | 8080 | `gh codespace ports forward 8080:8080 -c <CODESPACE-NAME>` | `ssh -L 8080:localhost:8080 -c <CODESPACE-NAME>` |
| React Dev | 3000 | `gh codespace ports forward 3000:3000 -c <CODESPACE-NAME>` | `ssh -L 3000:localhost:3000 -c <CODESPACE-NAME>` |
| K8s Dashboard | 8001 | `gh codespace ports forward 8001:8001 -c <CODESPACE-NAME>` | `ssh -L 8001:localhost:8001 -c <CODESPACE-NAME>` |
| PostgreSQL | 5432 | `gh codespace ports forward 5432:5432 -c <CODESPACE-NAME>` | `ssh -L 5432:localhost:5432 -c <CODESPACE-NAME>` |
| MySQL | 3306 | `gh codespace ports forward 3306:3306 -c <CODESPACE-NAME>` | `ssh -L 3306:localhost:3306 -c <CODESPACE-NAME>` |

## Notes

- Port forwarding persists until the codespace is stopped or the forward is explicitly stopped
- You can forward the same port to multiple local ports if needed
- Use `Ctrl+C` to stop interactive port forwarding
- Background processes can be managed with `jobs` and `kill` commands
