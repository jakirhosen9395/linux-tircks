# Mount Secondary Disk as `/data` (Ubuntu)

This guide shows the minimal, clear process to partition, format, and permanently mount a secondary disk (example: `/dev/sdb`) to `/data` on Ubuntu.

---

## Assumptions

- New disk: `/dev/sdb` (example size: **100G**)
- Primary OS disk: `/dev/sda`
- Mount point: `/data`
- Filesystem: `ext4`
- You have `sudo` access

> Warning: These steps will erase any existing data on `/dev/sdb`.

---

## 1) Identify the new disk

Command:
```bash
lsblk
```

Example output:
```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   50G  0 disk 
├─sda1   8:1    0    1G  0 part /boot/efi
├─sda2   8:2    0    2G  0 part /boot
└─sda3   8:3    0 46.9G  0 part /
sdb      8:16   0  100G  0 disk                  # <- Unused disk
```

---

## 2) Create a partition on `/dev/sdb`

Command:
```bash
sudo fdisk /dev/sdb
```

Inside `fdisk`, type:
```text
n     -> New partition
p     -> Primary
1     -> Partition number
<Enter> -> Default first sector
<Enter> -> Default last sector (use full disk)
w     -> Write and exit
```

Verify:
```bash
lsblk /dev/sdb
```

Example output:
```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sdb      8:16   0  100G  0 disk
└─sdb1   8:17   0  100G  0 part
```

---

## 3) Format the partition

Command:
```bash
sudo mkfs.ext4 /dev/sdb1
```

Example output:
```text
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 26213632 4k blocks and 6553600 inodes
Filesystem UUID: 1c2f0a9e-6f15-4a0d-8d3f-1f0a2a3b4c5d
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, ...
Allocating group tables: done
Writing inode tables: done
Creating journal (131072 blocks): done
Writing superblocks and filesystem accounting information: done
```

---

## 4) Create the mount directory

Command:
```bash
sudo mkdir -p /data
```

---

## 5) Mount temporarily and verify

Command:
```bash
sudo mount /dev/sdb1 /data
```

Verify:
```bash
df -hT | grep /data
```

Example output:
```text
/dev/sdb1  ext4   98G   24K   93G   1% /data
```

---

## 6) Make it permanent with `/etc/fstab` (UUID recommended)

Get UUID:
```bash
sudo blkid /dev/sdb1
```

Example output:
```text
/dev/sdb1: UUID="1c2f0a9e-6f15-4a0d-8d3f-1f0a2a3b4c5d" TYPE="ext4" PARTUUID="8f0c1d2e-01"
```

Edit `/etc/fstab`:
```bash
sudo nano /etc/fstab
```

Add this line (replace UUID with your actual value):
```fstab
UUID=1c2f0a9e-6f15-4a0d-8d3f-1f0a2a3b4c5d  /data  ext4  defaults  0  2
```

---

## 7) Final test

Command:
```bash
sudo umount /data
sudo mount -a
```

Verify:
```bash
df -hT | grep /data
```

Example output:
```text
/dev/sdb1  ext4   98G   24K   93G   1% /data
```

---

## Done

Your secondary disk is mounted at `/data` and will persist across reboots.
