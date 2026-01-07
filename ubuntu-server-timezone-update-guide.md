# 🛠️ Ubuntu Server: Timezone + Update/Upgrade Setup Guide (DevOps-Friendly)

This doc walks you through a clean, safe workflow after provisioning an **Ubuntu Server**:  
✅ set the correct **timezone**, then ✅ run a proper **system update & upgrade**.

If your timezone is wrong, logs, cron schedules, monitoring alerts, and security audits can get messy real fast.

---

## ✅ 1) Prerequisites

Before you start, make sure:

- 🔐 You have **sudo** access
- 🌐 The server has **internet connectivity**
- 🐧 You’re running **Ubuntu 22.04 LTS** or a newer stable Ubuntu Server release

---

## 🕒 2) Set Server Timezone

### Set timezone (example: Bangladesh)
```bash
sudo timedatectl set-timezone Asia/Dhaka
```

### Verify timezone + time sync status
```bash
timedatectl status
```

Example output:
```text
               Local time: Wed 2026-01-07 14:30:12 +06
           Universal time: Wed 2026-01-07 08:30:12 UTC
                 RTC time: Wed 2026-01-07 08:30:11
                Time zone: Asia/Dhaka (+06, +0600)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```

---

## 🔄 3) System Update & Upgrade (Safe DevOps Practice)

Right after server creation, your first move should be:  
📦 refresh package index → ⬆️ upgrade packages → 🧹 clean leftovers.

### One-liner maintenance flow
```bash
sudo apt update -y && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt autoremove -y && sudo apt clean
```

### What each command does (quick map)

| Command | What it does |
|---|---|
| `apt update` | 🔎 Refreshes package lists |
| `apt upgrade` | ⬆️ Upgrades installed packages |
| `apt dist-upgrade` | 🧠 Handles dependency changes safely |
| `apt autoremove` | 🧹 Removes unused packages |
| `apt clean` | 🗑️ Clears cached `.deb` files |

---

## 🔁 4) Reboot (If Needed)

Some upgrades (kernel/systemd) may require a reboot.

```bash
sudo reboot
```

Tip: Check if a reboot is required (common on Ubuntu):
```bash
test -f /var/run/reboot-required && echo "🚨 Reboot required" || echo "✅ No reboot required"
```

---

## 🛡️ 5) Basic Security Hardening (Recommended)

### 🔥 Enable UFW firewall
```bash
sudo ufw enable
sudo ufw status
```

Example output:
```text
Status: active
```

> If you’re on SSH, make sure SSH is allowed before enabling UFW, otherwise you might lock yourself out.

### 🧱 Install Fail2ban (SSH brute-force protection)
```bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban --no-pager
```

Example output (status):
```text
● fail2ban.service - Fail2Ban Service
     Loaded: loaded (/lib/systemd/system/fail2ban.service; enabled; preset: enabled)
     Active: active (running)
```

---

## 🔗 6) Useful links

- Ubuntu Server Docs: https://ubuntu.com/server/docs  
- `timedatectl` manual: https://manpages.ubuntu.com/manpages/jammy/en/man1/timedatectl.1.html  

---

## ✅ Wrap-up

You now have:
- 🕒 Correct timezone configured
- 🔄 Fully updated system packages
- 🧹 Cleaned unused packages + cache
- 🛡️ Optional firewall + brute-force protection enabled

This is a solid, DevOps-friendly baseline for new Ubuntu servers.
