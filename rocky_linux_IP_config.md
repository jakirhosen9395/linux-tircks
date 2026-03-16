# Rocky Linux Static IP Change Runbook

## Purpose
This document explains how to change the static IP address on a Rocky Linux server managed by **NetworkManager** by editing the connection profile file directly.

In this case, the target change is :

- **Old IP:** `10.70.57.182`
- **New IP:** `10.70.57.183`
- **Gateway:** `10.70.57.1`
- **Interface / Connection:** `ens18`

---

## Environment Notes
- OS: Rocky Linux
- Network management: `NetworkManager`
- Connection profile directory: `/etc/NetworkManager/system-connections/`
- Connection profile file identified: `/etc/NetworkManager/system-connections/ens18.nmconnection`

---

## Important Observation
From the terminal output provided, the connection profile file was identified correctly, but the pasted `cat` output still showed the **old IP**:

```ini
[ipv4]
address1=10.70.57.182/24,10.70.57.1
dns=8.8.8.8;
method=manual
```

That means the final saved configuration shown in the transcript does **not yet confirm** the IP was changed to `10.70.57.183`.

The correct final line should be:

```ini
address1=10.70.57.183/24,10.70.57.1
```

---

## Step-by-Step Procedure

### 1. Become root
```bash
sudo su
```

---

### 2. Find the connection profile containing the current IP
```bash
sudo grep -R "10.70.57.182" /etc/NetworkManager/system-connections/
```

### Expected result
```bash
/etc/NetworkManager/system-connections/ens18.nmconnection:address1=10.70.57.182/24,10.70.57.1
```

This confirms that the file to edit is:

```bash
/etc/NetworkManager/system-connections/ens18.nmconnection
```

---

### 3. Back up the existing connection file
```bash
sudo cp /etc/NetworkManager/system-connections/ens18.nmconnection \
        /etc/NetworkManager/system-connections/ens18.nmconnection.bak
```

This allows quick rollback if anything goes wrong.

---

### 4. Edit the connection file
Open the file in `vi` or `vim`:

```bash
sudo vi /etc/NetworkManager/system-connections/ens18.nmconnection
```

Locate the `[ipv4]` section.

### Current value
```ini
[ipv4]
address1=10.70.57.182/24,10.70.57.1
dns=8.8.8.8;
method=manual
```

### Change it to
```ini
[ipv4]
address1=10.70.57.183/24,10.70.57.1
dns=8.8.8.8;
method=manual
```

Save and exit the editor.

---

### 5. Review the file contents
```bash
cat /etc/NetworkManager/system-connections/ens18.nmconnection
```

### Expected result
```ini
[connection]
id=ens18
uuid=8e3b67d6-0224-3c49-bbbf-597d76d52173
type=ethernet
autoconnect-priority=-999
interface-name=ens18

[ethernet]

[ipv4]
address1=10.70.57.183/24,10.70.57.1
dns=8.8.8.8;
method=manual

[ipv6]
addr-gen-mode=eui64
method=auto

[proxy]
```

---

### 6. Confirm the connection name
```bash
sudo nmcli connection show
```

### Example output
```bash
NAME   UUID                                  TYPE      DEVICE
ens18  8e3b67d6-0224-3c49-bbbf-597d76d52173  ethernet  ens18
lo     35ebf915-308a-4dfa-9594-3f900fca9dd7  loopback  lo
```

The active connection name is `ens18`.

---

### 7. Apply the updated configuration
Bring the connection down and back up:

```bash
sudo nmcli connection down ens18
sudo nmcli connection up ens18
```

If you are connected remotely over this interface, be careful because bringing the connection down may temporarily interrupt access.

A lighter approach that may also work is:

```bash
sudo nmcli connection up ens18
```

---

### 8. Verify the applied IP address
Check the interface address:

```bash
ip addr show ens18
```

Or verify through NetworkManager:

```bash
nmcli connection show ens18
```

You should confirm that the system is now using:

```text
10.70.57.183/24
```

---

## Commands Used in the Session
```bash
sudo su
sudo grep -R "10.70.57.182" /etc/NetworkManager/system-connections/
vim /etc/NetworkManager/system-connections/ens18.nmconnection
sudo cp /etc/NetworkManager/system-connections/ens18.nmconnection /etc/NetworkManager/system-connections/ens18.nmconnection.bak
sudo vi /etc/NetworkManager/system-connections/ens18.nmconnection
cat /etc/NetworkManager/system-connections/ens18.nmconnection
sudo nmcli connection show
sudo nmcli connection show ens18
```

---

## Recommended Final Command Sequence
Use the following concise command sequence for the actual change:

```bash
sudo cp /etc/NetworkManager/system-connections/ens18.nmconnection \
        /etc/NetworkManager/system-connections/ens18.nmconnection.bak

sudo vi /etc/NetworkManager/system-connections/ens18.nmconnection
# Change:
# address1=10.70.57.182/24,10.70.57.1
# to:
# address1=10.70.57.183/24,10.70.57.1

sudo nmcli connection down ens18
sudo nmcli connection up ens18
ip addr show ens18
```

---

## Rollback Procedure
If something goes wrong, restore the backup:

```bash
sudo cp /etc/NetworkManager/system-connections/ens18.nmconnection.bak \
        /etc/NetworkManager/system-connections/ens18.nmconnection

sudo nmcli connection down ens18
sudo nmcli connection up ens18
```

---

## Summary
The server is using a NetworkManager connection profile named `ens18`. The IP address is configured in:

```bash
/etc/NetworkManager/system-connections/ens18.nmconnection
```

To complete the change properly, update:

```ini
address1=10.70.57.182/24,10.70.57.1
```

to:

```ini
address1=10.70.57.183/24,10.70.57.1
```

Then reactivate the connection and verify the new IP.
