# Linux Short Notes 📘
### For DevOps Engineers

A quick-reference guide covering Linux fundamentals — history, file system hierarchy, commands, permissions, automation, and networking.

---

## Table of Contents
1. [History of Linux](#history-of-linux)
2. [Linux File System Hierarchy](#linux-file-system-hierarchy)
3. [Basic Commands](#basic-commands)
4. [File & Directory Operations](#file--directory-operations)
5. [User Management](#user-management)
6. [Group Management](#group-management)
7. [File System Permissions](#linux-file-system-permissions)
8. [Access Control List (ACL)](#access-control-list-acl)
9. [Regular Expressions & grep](#regular-expressions--grep)
10. [Find Command](#find-command)
11. [wc, head & tail](#wc-word-count-head--tail)
12. [Archiving with tar](#archiving-with-tar)
13. [Job Automation (at & cron)](#job-automation)
14. [Sudo Command](#sudo-command)
15. [Networking (RHEL)](#networking-on-red-hat-enterprise-linux)

---

## History of Linux

Linux comes from the Unix family. It is a free and open-source operating system, developed by **Linus Torvalds** in **September 1991**.

- In 1991, Linus Torvalds was a student at the University of Helsinki, Finland.
- He developed the first version of Linux (0.01) and posted it on the Minix newsgroup on **17 September 1991**.
- The code became popular, and he was encouraged to keep developing it.
- The first "official" version, **Linux 0.02**, was released on **5 October 1991**.

Today, Linux is one of the most widely used operating systems in the world — **90% of the fastest 500 supercomputers**, including the top 10, run on Linux variants.

---

## Linux File System Hierarchy

Everything in Linux is represented as a file (including hardware and programs). Files live inside directories, which are organized in a tree structure — this is called the **File System Hierarchy (FSH)**.

Linux uses a **single-rooted, inverted tree-like structure**, starting from `/` (the root directory).

| Directory | Purpose |
|---|---|
| `/` | Root — top-level directory; starting point of the FSH |
| `/root` | Home directory of the root (superuser) |
| `/bin` | User binaries — common commands usable in single-user mode, available to all users |
| `/sbin` | System binaries — admin commands for system maintenance (e.g. `iptables`, `reboot`, `fdisk`, `ifconfig`, `swapon`) |
| `/dev` | Device files — terminals, USB devices, etc. (e.g. `/dev/tty1`, `/dev/usbmon0`) |
| `/var` | Variable data — files that tend to grow over time |
| `/var/log` | System and application log files |
| `/var/lib` | Database and package files |
| `/var/mail` | Emails |
| `/var/tmp` | Temporary files needed across reboots |
| `/mnt` | Used to temporarily mount a file system |
| `/media` | Mount points for removable media (USB, CD/DVD, etc.) |
| `/usr` | Applications and files used by users (not the system) |
| `/etc` | Core configuration files; also contains startup/shutdown scripts |
| `/boot` | Boot loader files — GRUB configuration and Linux kernels |
| `/opt` | Optional/third-party application software not shipped with the distro |
| `/home` | Home directories of regular (secondary) users |
| `/tmp` | Temporary files created by the system/users — cleared on reboot |

### Basic Info Commands

```bash
pwd            # Show present working directory
ls             # List files and directories
uname          # Show kernel (OS) name
uname -r       # Show kernel version
cd             # Change directory
clear          # Clear the screen
whoami         # Show current logged-in user
history        # Show previously used commands
date           # Show current date and time
```

---

## Basic Commands

### Create Files & Directories

```bash
mkdir dir1                     # Create a single directory
mkdir dir1 dir2 dir3           # Create multiple directories
mkdir -p parent/child/grandchild   # Create nested directory path
mkdir -p dir{1..5}             # Create a numbered range of directories
```

`touch` creates an **empty file** — it cannot write, edit, or save data into the file.

```bash
touch file1                    # Create a single file
touch file1 file2 file3        # Create multiple files
touch file{1..5}.txt           # Create a numbered range of files
```

## File & Directory Operations

### `cp` — Copy files/directories

```bash
cp <options> <source> <destination>
```

**Options**
- `-r` → recursive
- `-v` → verbose
- `-f` → force

```bash
cp file1 /destination/                # Copy a file
cp D* /destination/                    # Copy all files starting with "D"
```

### `rm` — Remove files/directories

```bash
rm file1                # Remove a file
rm -r directory1        # Remove a directory
```

### `mv` — Move / Rename

```bash
mv file1 /destination/       # Move a file/directory
mv oldname newname           # Rename a file/directory
```

---

## User Management

```bash
useradd <username>              # Create a user account
id <username>                   # Check user account properties
passwd <username>               # Set/create user password
chage -l <username>             # Check password aging properties
su - <username>                 # Switch user account
exit / logout                   # Log out from a user account
userdel -r <username>           # Delete a user account (with home dir)
usermod -l <newname> <oldname>  # Change a user's login name
```

### Group Management (Users)

```bash
groupadd <groupname>            # Add a group account
getent group <groupname>        # Check group account properties
gpasswd -A <user> <groupname>   # Check/set group admin
groupdel <groupname>            # Delete a group account
```

> A **group** is a collection of user accounts, useful for admins to manage and apply permissions to multiple users at once.

```bash
gpasswd -a <user> <group>              # Add a single member to a group
usermod -aG group1,group2 <user>       # Add a user to multiple groups
gpasswd -d <user> <group>              # Remove a member from a group
gpasswd -A <user> <group>              # Make a user the group admin
```

---

## Linux File System Permissions

**Types of file permission systems:**
- Basic Permission
- Special Permission
- Access Control List (ACL) Permission

```bash
ls -l file1        # Check file permission
ls -ld dir1        # Check directory permission
```

Output columns: **Permission | Link | Owner | Group owner | Size | Date & time | Name**

### Permission Groups

| Symbol | Meaning |
|---|---|
| `u` (User/Owner) | Permissions for the file's owner |
| `g` (Group) | Permissions for members of the group |
| `o` (Others) | Permissions for all other users |

### Permission Values (Numeric)

| Permission | Symbol | Value |
|---|---|---|
| Read | `r` | 4 |
| Write | `w` | 2 |
| Execute | `x` | 1 |

### Changing Permissions

```bash
chmod u+r file1              # Add read permission to owner
chmod g+rw file1              # Add read+write permission to group
chmod o-r file1                # Remove read permission from others
chmod 754 file1                 # Set permission using numeric value

chown <user> file1              # Change ownership
chgrp <group> file1             # Change group ownership
```

---

## Access Control List (ACL)

ACL provides an **additional, more flexible** permission mechanism beyond basic Linux permissions — allowing special access to be granted to specific users/groups on a file or directory.

**Use case:** If a user is *not* a member of a group but you still want to give them read/write access — without adding them to the group — ACL solves this.

```bash
getfacl file1                       # Check ACL permission

setfacl -m u:username:rwx file1     # Set ACL permission for a user
setfacl -x u:username file1         # Remove ACL permission for a user

setfacl -m g:groupname:rwx file1    # Set ACL permission for a group
setfacl -x g:groupname file1        # Remove ACL permission for a group

setfacl -b file1                    # Remove all ACL permissions
```

---

## Regular Expressions & grep

**Regular Expressions (regex)** are special character patterns used to search and match complex data patterns.

**GREP** = Global Regular Expression Print — searches a file for a pattern and displays all matching lines.

```bash
grep "word" file1                    # Search a word/string in a file
grep "word" file1 file2              # Search a string across multiple files
grep -i "word" file1                 # Case-insensitive search
grep -r "word" .                     # Search recursively in all files
grep -v "word" file1                 # Invert match (show non-matching lines)
grep -c "word" file1                 # Show count of matching lines
grep -l "word" *                     # Show file names that match
grep -L "word" *                     # Show file names that do NOT match
grep -n "word" file1                 # Show matching lines with line numbers
grep "^word" file1                   # Lines that start with "word"
grep "word$" file1                   # Lines that end with "word"
grep "word" file1 > output.txt       # Search and redirect output to a new file
```

---

## Find Command

`find` is used to **search and locate** files/directories based on given conditions — permissions, users, groups, type, date, size, etc.

```bash
find /home -type f                          # Find files under the home directory
find / -perm -4000                          # Find files with SUID permission
find / -perm -2000                          # Find files with GUID permission
find / -perm -1000                          # Find files with sticky bit permission
find / -user <username>                     # Find files based on user
find / -group <groupname>                   # Find files based on group
find / -size -10M                           # Find files smaller than 10MB
find / -size +10M                           # Find files larger than 10MB
```

---

## WC (Word Count), Head & Tail

```bash
wc -l file1     # Count number of lines
wc -w file1     # Count number of words
```

**`head`** — display top lines of a file:
```bash
head file1              # Display top 10 lines
head -n 20 file1         # Display top N lines
```

**`tail`** — display bottom lines of a file:
```bash
tail file1               # Display bottom 10 lines
tail -n 20 file1          # Display bottom N lines
```

---

## Archiving with tar

`tar` (**tape archive**) is used to combine multiple files/directories into a single file — useful for backup and compression. Supports compression algorithms like `gzip`, `bz2`, and `xz`.

```bash
tar <options> <files>
```

**Common Options**
| Option | Meaning |
|---|---|
| `c` | Create |
| `x` | Extract |
| `v` | Verbose |
| `f` | Force (use archive file) |
| `t` | Test |
| `z` | gzip compression |
| `j` | bz2 compression |
| `J` | xz compression |
| `C` | Extract to a specific destination |

```bash
tar -cvf archive.tar files/                 # Create a tar archive
tar -tvf archive.tar --human-readable       # Show file size in human-readable format
tar -xvf archive.tar                        # Extract archive to default location
tar -xvf archive.tar -C /destination/       # Extract to a specific location

tar -czvf archive.tar.gz files/             # Create archive with gzip compression
tar -xzvf archive.tar.gz                    # Extract gzip-compressed archive

tar -cjvf archive.tar.bz2 files/            # Create archive with bz2 compression
tar -xjvf archive.tar.bz2                   # Extract bz2-compressed archive

tar -cJvf archive.tar.xz files/             # Create archive with xz compression
tar -xJvf archive.tar.xz                    # Extract xz-compressed archive
```

---

## Job Automation

Job automation lets tasks run automatically, useful for admins to schedule work even when not present.

**Two types:**
1. **`at`** — execute a job only once
2. **`crontab`** — execute a job repeatedly (on a schedule)

### `at` command

```bash
at 5:00pm                       # Set a job with at command
atq                              # Show pending jobs
atrm <job_number>                # Remove a job
```
To restrict a user from using `at`, add their username to `/etc/at.deny`.

### `crontab` (cron)

```bash
systemctl start crond            # Start crond service
systemctl enable crond           # Enable crond permanently

crontab -e                       # Set a cron job
crontab -l                       # Show cron jobs of current user
crontab -r                       # Remove cron jobs
# (or manually edit the crontab file and remove the job line)

crontab -u <username> -e         # Set a cron job for another user
crontab -u <username> -l         # Show cron jobs for another user
```
To restrict a user from cron, add their username to `/etc/cron.deny`.

---

## Sudo Command

`sudo` ("superuser do") allows a permitted user to execute commands as another user (typically root), based on rules in `/etc/sudoers`.

### Grant sudo to a user

```bash
visudo   # or: vim /etc/sudoers
```
```
root  ALL=(ALL) ALL
amir  ALL=(ALL) ALL
```

### Grant sudo to a group

```
%punegrp  ALL=(ALL) ALL
```
By default, all members of `punegrp` get sudo privileges.

### Wheel group

`wheel` is a system group that has sudo privileges by default. Adding a user to it grants sudo access.

```bash
grep wheel /etc/group
useradd shub
passwd shub
gpasswd -a shub wheel
```

### Sudo without password

```
amir      ALL=(ALL) NOPASSWD: ALL
%punegrp  ALL=(ALL) NOPASSWD: ALL
```

---

## Networking on Red Hat Enterprise Linux

```bash
ip addr show          # Show IP address
```

### Configure Networking with `nmcli`

`NetworkManager` is a daemon that monitors and manages network settings. `nmcli` is the command-line tool for managing it.

```bash
nmcli con show                  # Show all connections
nmcli con show --active         # Show active connection(s)
nmcli con show "citynet"        # Show a specific connection
nmcli device status             # Show device status

nmcli con add con-name "citynet" ifname eth0 type ethernet   # Create a new connection

nmcli con mod "citynet" ipv4.addresses 192.168.0.100/24
nmcli con mod "citynet" ipv4.gateway 192.168.0.254
nmcli con mod "citynet" ipv4.dns 192.168.0.254

nmcli con up citynet             # Activate a connection
nmcli con down citynet           # Deactivate a connection

nmcli con up newconn; nmcli con down oldconn   # Start new & stop old connection

nmcli con delete citynet         # Remove an existing connection

hostnamectl set-hostname <name>  # Set hostname
hostnamectl                      # Show hostname
```

### Configuring Networking with `nmtui`

`nmtui` provides a text-based UI for the same network configuration tasks.

### IP Configuration Files

All connections created with `nmcli` or `nmtui` are stored by default in:
```
/etc/sysconfig/network-scripts/
```

> ⚠️ You *can* edit these files directly, but it's **not recommended**. If you do, restart the `NetworkManager` service afterward for changes to take effect:
> ```bash
> systemctl restart NetworkManager
> ```

---

📌 *Notes compiled from "Linux Short Notes for DevOps Engineers" — Train Shubham With.*
