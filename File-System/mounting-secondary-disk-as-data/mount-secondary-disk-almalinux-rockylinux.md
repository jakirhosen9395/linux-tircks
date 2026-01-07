# Mount Secondary Disk as `/data` (AlmaLinux / Rocky Linux)

This guide shows how to partition, format, and permanently mount a secondary disk (for example, `/dev/sdb`) to `/data` on **AlmaLinux** or **Rocky Linux**.

---

## Assumptions

- OS: AlmaLinux or Rocky Linux (RHEL-family)
- A secondary disk is attached (example: `/dev/sdb`) and is **unused**
- Primary OS disk is `/dev/sda`
- Target mount point: `/data`
- Filesystem: `ext4` (supported on RHEL-family; `xfs` is common by default, but `ext4` works fine)

---

## Prerequisites / Safety

- You have `sudo` privileges.
- You have verified the correct device name for the new disk.
- This procedure will **erase** anything on the target disk/partition.

---

## Step-by-step

### 1) Identify the new disk

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
sdb      8:16   0  100G  0 disk                   # <- Unused disk
```

Optional (recommended) to confirm the disk has no filesystem signatures:
```bash
sudo wipefs -n /dev/sdb
```

Example output (no output means no signatures found):
```text
# (no output)
```

---

### 2) Create a partition on `/dev/sdb`

Run `fdisk`:
```bash
sudo fdisk /dev/sdb
```

Inside `fdisk`, type:
```text
n     -> new partition
p     -> primary
1     -> partition number
<Enter> -> default first sector
<Enter> -> default last sector (use full disk)
w     -> write changes and exit
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

### 3) Format the partition as `ext4`

Command:
```bash
sudo mkfs.ext4 -F /dev/sdb1
```

Example output:
```text
mke2fs 1.46.5 (30-Dec-2021)
Creating filesystem with 26214400 4k blocks and 6553600 inodes
Filesystem UUID: 1c2f0a9e-6f15-4a0d-8d3f-1f0a2a3b4c5d
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, ...
Allocating group tables: done
Writing inode tables: done
Creating journal (131072 blocks): done
Writing superblocks and filesystem accounting information: done
```

---

### 4) Create the mount directory

Command:
```bash
sudo mkdir -p /data
```

---

### 5) Mount the disk temporarily

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
/dev/sdb1  ext4  98G  24K   93G   1% /data
```

---

### 6) Persist the mount using UUID in `/etc/fstab` (recommended)

Get the UUID:
```bash
sudo blkid /dev/sdb1
```

Example output:
```text
/dev/sdb1: UUID="1c2f0a9e-6f15-4a0d-8d3f-1f0a2a3b4c5d" TYPE="ext4" PARTUUID="8f0c1d2e-01"
```

Edit `/etc/fstab`:
```bash
sudo vi /etc/fstab
```

Add a line (replace UUID with your real UUID):
```fstab
UUID=1c2f0a9e-6f15-4a0d-8d3f-1f0a2a3b4c5d  /data  ext4  defaults,nofail  0  2
```

Notes:
- `nofail` helps avoid boot failure if the disk is temporarily missing (common in cloud/VM scenarios).

---

### 7) Final test

Command:
```bash
sudo umount /data
sudo mount -a
```

Validate:
```bash
df -hT | grep /data
```

Example output:
```text
/dev/sdb1  ext4  98G  24K   93G   1% /data
```

---

## Example `/etc/fstab` entry

```fstab
# <file system>                              <mount point>  <type>  <options>           <dump> <pass>
UUID=1c2f0a9e-6f15-4a0d-8d3f-1f0a2a3b4c5d     /data          ext4    defaults,nofail     0      2
```

---

## SELinux note (RHEL-family)

On AlmaLinux/Rocky, **SELinux** is often enabled. For general storage, mounting to `/data` is typically fine.  
If you later run services that need a specific SELinux label (for example, web/app data), you may need to apply an appropriate context using `semanage fcontext` and `restorecon`.

---

## Done

You now have a secondary disk mounted to `/data`, and it will persist across reboots via `/etc/fstab`.
