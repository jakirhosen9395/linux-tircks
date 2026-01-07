# Extend Ubuntu 24.04 Root LVM by Adding a New Disk (/dev/sdb)

**Goal:** Add the new 50G disk `/dev/sdb` to the existing LVM Volume Group `ubuntu-vg`, extend the root Logical Volume `ubuntu-lv`, and grow the ext4 filesystem mounted at `/`.

> Important: This does **not** “merge physical disks” into one disk. It extends the **LVM storage pool** so `/` can use space from both `/dev/sda` and `/dev/sdb`.

---

## Environment (as observed)

### Initial block devices
Command:
```bash
lsblk
```

Example output:
```text
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0  100G  0 disk 
├─sda1                      8:1    0    1M  0 part 
├─sda2                      8:2    0    2G  0 part /boot
└─sda3                      8:3    0   98G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   98G  0 lvm  /
sdb                         8:16   0   50G  0 disk 
sr0                        11:0    1  2.6G  0 rom  
```

### Filesystem + LVM topology
Command:
```bash
lsblk -f
```

Example output:
```text
NAME            FSTYPE      FSVER            LABEL                         UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
sda                                                                                                                              
├─sda1                                                                                                                           
├─sda2          ext4        1.0                                            c0efdee8-8661-4fb9-aa79-c44399560624      1.6G    10% /boot
└─sda3          LVM2_member LVM2 001                                       19uoXn-PTCM-9ied-fWew-OmM1-oaVO-kykUK1                
  └─ubuntu--vg-ubuntu--lv
                ext4        1.0                                            dc561d05-34b5-4dfe-87a1-b3b5d31a6b86    128.3M    95% /
sdb                                                                                                                              
sr0             iso9660     Joliet Extension Ubuntu-Server 24.04 LTS amd64 2024-04-23-12-46-09-00                                
```

### Confirm `/dev/sdb` is empty (no signatures)
Command:
```bash
sudo wipefs -n /dev/sdb
```

Example output (no output means no signatures found):
```text
# (no output)
```

---

## Prerequisites / Safety Checklist

- You have **sudo** privileges.
- `/dev/sdb` is the **correct disk** and can be wiped/repurposed.
- Current root filesystem `/` is on LVM (`ubuntu-vg/ubuntu-lv`).
- Recommended: Take a backup/snapshot before resizing storage.

---

## Step-by-step procedure

### 1) Partition `/dev/sdb` for LVM

Create a GPT partition table, one partition covering the full disk, and mark it as LVM:

Command:
```bash
sudo parted -s /dev/sdb mklabel gpt
sudo parted -s /dev/sdb mkpart primary 1MiB 100%
sudo parted -s /dev/sdb set 1 lvm on
```

Verify the partition exists:

Command:
```bash
lsblk /dev/sdb
```

Example output:
```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sdb      8:16   0   50G  0 disk
└─sdb1   8:17   0   50G  0 part
```

---

### 2) Initialize the new partition as an LVM Physical Volume (PV)

Command:
```bash
sudo pvcreate /dev/sdb1
```

Example output:
```text
  Physical volume "/dev/sdb1" successfully created.
```

---

### 3) Extend the existing Volume Group (VG)

Add `/dev/sdb1` into the existing VG `ubuntu-vg`:

Command:
```bash
sudo vgextend ubuntu-vg /dev/sdb1
```

Example output:
```text
  Volume group "ubuntu-vg" successfully extended
```

Validate PV/VG state:

Command:
```bash
sudo vgs
```

Example output (values may vary):
```text
  VG        #PV #LV #SN Attr   VSize    VFree
  ubuntu-vg   2   1   0 wz--n- 147.99g  50.00g
```

Command:
```bash
sudo pvs
```

Example output (values may vary):
```text
  PV         VG        Fmt  Attr PSize    PFree
  /dev/sda3  ubuntu-vg lvm2 a--  <98.00g      0
  /dev/sdb1  ubuntu-vg lvm2 a--  <50.00g  <50.00g
```

---

### 4) Extend the root Logical Volume (LV) to use all free space

Command:
```bash
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

Example output:
```text
  Size of logical volume ubuntu-vg/ubuntu-lv changed from 98.00 GiB (25088 extents) to 147.99 GiB (37885 extents).
  Logical volume ubuntu-vg/ubuntu-lv successfully resized.
```

---

### 5) Grow the ext4 filesystem online

Because `/` is **ext4**, use `resize2fs`:

Command:
```bash
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

Example output:
```text
resize2fs 1.47.0 (5-Feb-2023)
Filesystem at /dev/mapper/ubuntu--vg-ubuntu--lv is mounted on /; on-line resizing required
old_desc_blocks = 13, new_desc_blocks = 19
The filesystem on /dev/mapper/ubuntu--vg-ubuntu--lv is now 38797312 (4k) blocks long.
```

---

## Post-change validation

### 1) Check root filesystem size/usage

Command:
```bash
df -hT /
```

Example output (values will differ):
```text
Filesystem                          Type  Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv   ext4  145G   92G   47G  67% /
```

### 2) Check LV/VG/PV inventory

Command:
```bash
sudo lvs
```

Example output:
```text
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  ubuntu-lv ubuntu-vg -wi-ao---- 147.99g
```

Command:
```bash
sudo vgs
```

Example output:
```text
  VG        #PV #LV #SN Attr   VSize    VFree
  ubuntu-vg   2   1   0 wz--n- 147.99g     0
```

Command:
```bash
sudo pvs
```

Example output:
```text
  PV         VG        Fmt  Attr PSize    PFree
  /dev/sda3  ubuntu-vg lvm2 a--  <98.00g      0
  /dev/sdb1  ubuntu-vg lvm2 a--  <50.00g      0
```

---

## Operational considerations (production)

- After the change, your root LV spans **two physical disks** (`/dev/sda` + `/dev/sdb`).
- With a standard LVM linear layout, **failure of either disk can cause data loss**.
- For production reliability, consider:
  - Disk-level redundancy (RAID1/RAID10), or
  - LVM mirroring (trade-offs: complexity/performance), or
  - Cloud volumes with managed redundancy and online expansion.

---

## Troubleshooting quick notes

### If `/dev/sdb1` does not appear after partitioning
```bash
sudo partprobe /dev/sdb
lsblk /dev/sdb
```

### If VG name differs
List VGs and use the correct one:
```bash
sudo vgs
```

### If filesystem is not ext4
Check and use the correct grow command:
```bash
findmnt -no FSTYPE /
```
- `ext4` → `resize2fs`
- `xfs` → `xfs_growfs /`

---

## Complete command sequence (copy/paste)

```bash
# Inspect
lsblk
lsblk -f
sudo wipefs -n /dev/sdb

# Partition and mark for LVM
sudo parted -s /dev/sdb mklabel gpt
sudo parted -s /dev/sdb mkpart primary 1MiB 100%
sudo parted -s /dev/sdb set 1 lvm on
lsblk /dev/sdb

# LVM: PV -> VG -> LV
sudo pvcreate /dev/sdb1
sudo vgextend ubuntu-vg /dev/sdb1
sudo vgs
sudo pvs

# Extend root LV and filesystem
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# Validate
df -hT /
sudo lvs
sudo vgs
sudo pvs
```
