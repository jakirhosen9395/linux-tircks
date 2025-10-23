# Change Ubuntu Server Hostname

This guide provides step-by-step instructions to change the hostname of an Ubuntu server.

---

## 🔧 Steps to Change the Hostname

### 1. Check Current Hostname
```bash
hostnamectl
```

---

### 2. Set the New Hostname
Replace `new-hostname` with the desired hostname:

```bash
sudo hostnamectl set-hostname new-hostname
```

✅ This updates the static hostname immediately and will persist after a reboot.

---

### 3. Update `/etc/hosts`
Open the file:
```bash
sudo nano /etc/hosts
```

Find a line like:
```bash
127.0.1.1    old-hostname
```

Change it to:
```bash
127.0.1.1    new-hostname
```

Save and exit (press `Ctrl+O`, `Enter`, then `Ctrl+X`).

---

### 4. (Optional) Reboot the Server
To ensure all services recognize the new hostname:
```bash
sudo reboot
```

---

### 5. Verify the New Hostname
After reboot:
```bash
hostnamectl
```

---

## ✅ Done!
Your server's hostname is now updated successfully.
