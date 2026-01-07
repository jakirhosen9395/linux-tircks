
# 🗂️ Mount Secondary Disk as `/data`

This guide explains how to partition, format, and permanently mount a secondary disk (e.g., `/dev/sdb`) to `/data`.

---

## 📌 Assumptions

- You have a second disk (e.g., `/dev/sdb`) of 100GB.
- Primary OS is installed on `/dev/sda`.
- Target mount point is `/data`.
- Filesystem: `ext4`

---

## 🛠️ Step-by-Step Instructions

### 1. 🔍 Identify the New Disk

Run the following command to list disks:

```bash
lsblk
```

You should see output like:

```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   50G  0 disk 
├─sda1   8:1    0    1G  0 part /boot/efi
├─sda2   8:2    0    2G  0 part /boot
└─sda3   8:3    0 46.9G  0 part /
sdb      8:16   0  100G  0 disk                  # ← Unused disk
```

---

### 2. 📏 Partition `/dev/sdb`

Launch `fdisk`:

```bash
sudo fdisk /dev/sdb
```

Inside `fdisk`, enter the following:

```
n     → New partition  
p     → Primary  
1     → Partition number  
Enter → Accept default first sector  
Enter → Accept default last sector (use full disk)  
w     → Write and exit
```

---

### 3. 🧱 Format the Partition

```bash
sudo mkfs.ext4 /dev/sdb1
```

---

### 4. 📂 Create the Mount Directory

```bash
sudo mkdir -p /data
```

---

### 5. 🖇️ Mount the Disk Temporarily

```bash
sudo mount /dev/sdb1 /data
```

To verify:

```bash
df -h | grep /data
```

---

### 6. 🛡️ Mount Disk Permanently (Edit `/etc/fstab`)

Instead of using UUID, you can directly use `/dev/sdb1` if you're sure the device name won't change.

Edit `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Add this line at the bottom:

```fstab
/dev/sdb1  /data  ext4  defaults  0  2
```

Save and exit.

---

### 7. ✅ Final Test

Run:

```bash
sudo umount /data
sudo mount -a
df -h | grep /data
```

You should now see `/dev/sdb1` mounted at `/data` permanently.

---

## 🧾 Example `fstab` Entry

```fstab
# <file system>  <mount point>  <type>  <options>  <dump>  <pass>
/dev/sdb1  /data  ext4  defaults  0  2
```

---

## 📎 Notes

- If you're using a cloud platform, disk names (e.g., `/dev/sdb1`) may change across reboots.
- For safer mounting, prefer UUID when possible: `sudo blkid /dev/sdb1`
- You can use this mount point for MongoDB, Docker volumes, or general data storage.

---

## ✅ Done!

You now have a 100GB disk mounted to `/data` and it will persist across reboots.
