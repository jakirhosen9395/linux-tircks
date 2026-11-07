# RHEL 9.8 GUI, TigerVNC, Linux User, and SFTP Configuration Guide

## 1. Environment Summary and User Matrix

| Linux User | VNC Display | VNC Port | SFTP Group | Access Level |
| :--- | :--- | :--- | :--- | :--- |
| user1 | :1 | 5901 | sftp-allowed (1001) | VNC + SFTP Allowed |
| user2 | :2 | 5902 | sftp-allowed (1001) | VNC + SFTP Allowed |
| user3 | :3 | 5903 | sftp-denied (1002) | VNC Only (SFTP Denied) |
| user4 | :4 | 5904 | sftp-denied (1002) | VNC Only (SFTP Denied) |

* **Password Rule:** Every user has an 8-character password used for both Linux login and TigerVNC login.
* **Direct VNC Connection:** TigerVNC listens on 0.0.0.0:5901 through 5904 (no SSH tunnel required).
* **SFTP Chroot Path:** Allowed users upload and download files inside /srv/sftp/user1/files and /srv/sftp/user2/files.

---

## 2. Server Preparation

### Step 1: Verify RHEL 9.8 OS and Repositories
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/os-release

**Commands:**
```bash
cat /etc/os-release
uname -r
dnf repolist
```

**Validation:**
```bash
grep -E '^(NAME|VERSION_ID|PLATFORM_ID)=' /etc/os-release
dnf repolist --enabled
```

**Expected output:**
* NAME="Red Hat Enterprise Linux"
* VERSION_ID="9.8"
* PLATFORM_ID="platform:el9"
* Active repositories listed: rhel-9-appstream-rhui-rpms and rhel-9-baseos-rhui-rpms.

---

### Step 2: Set Hostname and Check IP Address
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/hostname

**Commands:**
```bash
hostnamectl set-hostname vnc-server
hostname -I
ip -br addr show
```

**Validation:**
```bash
hostnamectl status
hostname -I
```

**Expected output:**
* Static hostname: vnc-server
* Operating System: Red Hat Enterprise Linux 9.8 (Plow)
* Prints the server IPv4 address (for example, 172.31.15.62). Use this exact IP for all VNC and SFTP client connections.

---

### Step 3: Update Packages and Install Base Utilities
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** None

**Commands:**
```bash
dnf clean all
dnf makecache
dnf upgrade -y
dnf install -y openssh-server openssh-clients policycoreutils-python-utils setroubleshoot-server firewalld
```

**Validation:**
```bash
rpm -q openssh-server openssh-clients policycoreutils-python-utils firewalld
```

**Expected output:**
* Displays installed package versions for openssh-server, openssh-clients, policycoreutils-python-utils, and firewalld with no missing packages.

---

### Step 4: Enable Firewalld and Verify SELinux Status
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/selinux/config

**Commands:**
```bash
systemctl enable --now firewalld
getenforce
```

**Validation:**
```bash
systemctl is-active firewalld
getenforce
```

**Expected output:**
* active
* Enforcing

---

## 3. GUI Desktop Installation

### Step 5: Install GNOME Desktop and X11 Utilities
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** None

**Commands:**
```bash
dnf group install -y "Server with GUI"
dnf install -y gnome-terminal xorg-x11-xauth dejavu-sans-fonts
```

**Validation:**
```bash
rpm -q gnome-shell gnome-session gdm gnome-terminal xorg-x11-xauth
```

**Expected output:**
* gnome-shell-40.10-35.el9_8.1.x86_64
* gnome-session-40.1.1-11.el9.x86_64
* gdm-40.1-44.el9_8.x86_64
* gnome-terminal-3.40.3-1.el9.x86_64
* xorg-x11-xauth-1.1-10.el9.x86_64

---

### Step 6: Enable GDM and Switch to Graphical Target
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/systemd/system/default.target

**Commands:**
```bash
systemctl enable gdm.service
systemctl set-default graphical.target
systemctl isolate graphical.target
```

**Validation:**
```bash
systemctl get-default
systemctl is-active gdm.service
```

**Expected output:**
* graphical.target
* active

---

## 4. Linux User and Group Management

### Step 7: Allow 8-Character Passwords in PAM
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/security/pwquality.conf

**Commands:**
```bash
sed -i 's/^#\?\s*minlen\s*=.*/minlen = 8/' /etc/security/pwquality.conf
grep -q '^minlen' /etc/security/pwquality.conf || echo "minlen = 8" >> /etc/security/pwquality.conf
```

**Validation:**
```bash
grep '^minlen' /etc/security/pwquality.conf
```

**Expected output:**
* minlen = 8

---

### Step 8: Create SFTP Access Groups
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/group

**Commands:**
```bash
getent group sftp-allowed || groupadd -g 1001 sftp-allowed
getent group sftp-denied || groupadd -g 1002 sftp-denied
```

**Validation:**
```bash
getent group sftp-allowed sftp-denied
```

**Expected output:**
* sftp-allowed:x:1001:
* sftp-denied:x:1002:

---

### Step 9: Create Users, Permissions, and 8-Character Linux Passwords
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/passwd, /etc/group, /etc/shadow

**Commands:**
```bash
useradd -m -s /bin/bash -G sftp-allowed user1
useradd -m -s /bin/bash -G sftp-allowed user2
useradd -m -s /bin/bash -G sftp-denied user3
useradd -m -s /bin/bash -G sftp-denied user4

chmod 700 /home/user1 /home/user2 /home/user3 /home/user4

passwd user1
passwd user2
passwd user3
passwd user4
```

**Validation:**
```bash
id user1
id user2
id user3
id user4
getent group sftp-allowed sftp-denied
ls -ld /home/user1 /home/user2 /home/user3 /home/user4
for u in user1 user2 user3 user4; do passwd -S "$u"; done
```

**Expected output:**
* uid=1001(user1) gid=1003(user1) groups=1003(user1),1001(sftp-allowed)
* uid=1002(user2) gid=1004(user2) groups=1004(user2),1001(sftp-allowed)
* uid=1003(user3) gid=1005(user3) groups=1005(user3),1002(sftp-denied)
* uid=1004(user4) gid=1006(user4) groups=1006(user4),1002(sftp-denied)
* sftp-allowed:x:1001:user1,user2
* sftp-denied:x:1002:user3,user4
* drwx------. on /home/user1, /home/user2, /home/user3, and /home/user4
* Password status shows PS (Password set) for all four users.

---

## 5. TigerVNC Installation and Configuration

### Step 10: Install TigerVNC and Configure Global Settings
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/tigervnc/vncserver-config-defaults, /etc/tigervnc/vncserver-config-mandatory

**Commands:**
```bash
dnf install -y tigervnc-server

cat << 'EOF' > /etc/tigervnc/vncserver-config-defaults
session=gnome
geometry=1920x1080
securitytypes=vncauth,tlsvnc
EOF

cat << 'EOF' > /etc/tigervnc/vncserver-config-mandatory
SendCutText=0
AcceptCutText=0
EOF

chmod 644 /etc/tigervnc/vncserver-config-defaults /etc/tigervnc/vncserver-config-mandatory
```

**Validation:**
```bash
rpm -q tigervnc-server
cat /etc/tigervnc/vncserver-config-defaults
cat /etc/tigervnc/vncserver-config-mandatory
```

**Expected output:**
* tigervnc-server-1.15.0-7.el9_8.2.x86_64
* Defaults file contains: session=gnome, geometry=1920x1080, securitytypes=vncauth,tlsvnc
* Mandatory file contains: SendCutText=0, AcceptCutText=0 (no localhost restriction).

---

### Step 11: Map Users to VNC Displays
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/tigervnc/vncserver.users

**Commands:**
```bash
cat << 'EOF' > /etc/tigervnc/vncserver.users
:1=user1
:2=user2
:3=user3
:4=user4
EOF

sed -i 's/[[:space:]]*$//' /etc/tigervnc/vncserver.users
chmod 644 /etc/tigervnc/vncserver.users
```

**Validation:**
```bash
cat -A /etc/tigervnc/vncserver.users
```

**Expected output:**
* :1=user1$
* :2=user2$
* :3=user3$
* :4=user4$

---

### Step 12: Set VNC Passwords for Each User
**Server:** RHEL 9.8
**Execution user:** root (switching to each user)
**Configuration file:** /home/userN/.config/tigervnc/passwd

**Commands:**
```bash
su - user1 -c "vncpasswd"
su - user2 -c "vncpasswd"
su - user3 -c "vncpasswd"
su - user4 -c "vncpasswd"
```
*Note: Enter the same 8-character password set in Step 9, and enter n when asked for a view-only password.*

**Validation:**
```bash
ls -l /home/user1/.config/tigervnc/passwd \
      /home/user2/.config/tigervnc/passwd \
      /home/user3/.config/tigervnc/passwd \
      /home/user4/.config/tigervnc/passwd
```

**Expected output:**
* Four passwd files listed with -rw------- permissions, each 8 bytes in size and owned by its respective user.

---

### Step 13: Enable and Start TigerVNC Services
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /usr/lib/systemd/system/vncserver@.service

**Commands:**
```bash
systemctl daemon-reload
systemctl enable --now vncserver@:1.service vncserver@:2.service vncserver@:3.service vncserver@:4.service
```

**Validation:**
```bash
systemctl is-active vncserver@:1.service vncserver@:2.service vncserver@:3.service vncserver@:4.service
ss -lntp | grep 590
ps -u user1 -u user2 -u user3 -u user4 | grep -E 'Xvnc|gnome-session|gnome-shell'
```

**Expected output:**
* Four lines printing active.
* LISTEN sockets on 0.0.0.0:5901, 0.0.0.0:5902, 0.0.0.0:5903, and 0.0.0.0:5904 owned by Xvnc.
* Running Xvnc, gnome-session, and gnome-shell processes for all four users.

---

## 6. SFTP and SSH Access Configuration

### Step 14: Create SFTP Chroot Directories and Permissions
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /srv/sftp

**Commands:**
```bash
mkdir -p /srv/sftp/user1/files /srv/sftp/user2/files

chown root:root /srv /srv/sftp /srv/sftp/user1 /srv/sftp/user2
chmod 755 /srv /srv/sftp /srv/sftp/user1 /srv/sftp/user2

chown user1:sftp-allowed /srv/sftp/user1/files
chown user2:sftp-allowed /srv/sftp/user2/files
chmod 700 /srv/sftp/user1/files /srv/sftp/user2/files
```

**Validation:**
```bash
ls -ld /srv /srv/sftp /srv/sftp/user1 /srv/sftp/user1/files /srv/sftp/user2 /srv/sftp/user2/files
```

**Expected output:**
* drwxr-xr-x. root root on /srv, /srv/sftp, /srv/sftp/user1, and /srv/sftp/user2.
* drwx------. user1 sftp-allowed on /srv/sftp/user1/files.
* drwx------. user2 sftp-allowed on /srv/sftp/user2/files.

---

### Step 15: Enable SSH Password Authentication
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/ssh/sshd_config, /etc/ssh/sshd_config.d/50-cloud-init.conf

**Commands:**
```bash
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
for f in /etc/ssh/sshd_config.d/*.conf; do
    [ -e "$f" ] && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' "$f"
done
```

**Validation:**
```bash
grep -rn "PasswordAuthentication" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/
```

**Expected output:**
* Active lines show PasswordAuthentication yes in /etc/ssh/sshd_config and /etc/ssh/sshd_config.d/50-cloud-init.conf.

---

### Step 16: Configure SFTP Group Access Rules in SSHD
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/ssh/sshd_config.d/40-sftp-access.conf

**Commands:**
```bash
cat << 'EOF' > /etc/ssh/sshd_config.d/40-sftp-access.conf
PasswordAuthentication yes
KbdInteractiveAuthentication yes

DenyGroups sftp-denied

Match Group sftp-allowed
    PasswordAuthentication yes
    ChrootDirectory /srv/sftp/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTTY no

Match Group sftp-denied
    PasswordAuthentication no
    ForceCommand /usr/sbin/nologin
EOF

chmod 600 /etc/ssh/sshd_config.d/40-sftp-access.conf
sshd -t && systemctl reload sshd
```

**Validation:**
```bash
sshd -t
sshd -T -C user=user1,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|chrootdirectory|forcecommand|denygroups)'
sshd -T -C user=user3,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|chrootdirectory|forcecommand|denygroups)'
```

**Expected output:**
* First check (user1): passwordauthentication yes, forcecommand internal-sftp, chrootdirectory /srv/sftp/%u, denygroups sftp-denied.
* Second check (user3): passwordauthentication no, forcecommand /usr/sbin/nologin, chrootdirectory none, denygroups sftp-denied.

---

## 7. Firewall, SELinux, and Client Verification

### Step 17: Open SSH and VNC Ports in Firewalld
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/firewalld/zones/public.xml

**Commands:**
```bash
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-port=5901-5904/tcp
firewall-cmd --reload
```
*Note: Also open inbound TCP ports 22 and 5901-5904 in your AWS EC2 Security Group.*

**Validation:**
```bash
firewall-cmd --list-services
firewall-cmd --list-ports
```

**Expected output:**
* Services include ssh.
* Ports include 5901-5904/tcp.

---

### Step 18: Configure SELinux for Chrooted SFTP Uploads
**Server:** RHEL 9.8
**Execution user:** root
**Configuration file:** /etc/selinux/targeted/contexts/files/file_contexts.local

**Commands:**
```bash
semanage fcontext -a -t user_home_t "/srv/sftp/[^/]+/files(/.*)?"
restorecon -Rv /srv/sftp
setsebool -P ssh_chroot_rw_homedirs on
```

**Validation:**
```bash
getenforce
getsebool ssh_chroot_rw_homedirs
ls -Zd /srv/sftp/user1/files /srv/sftp/user2/files
```

**Expected output:**
* Enforcing
* ssh_chroot_rw_homedirs --> on
* unconfined_u:object_r:user_home_t:s0 on both /srv/sftp/user1/files and /srv/sftp/user2/files.

---

### Step 19: Client Verification from Windows PC
**Server:** Windows PC (PowerShell and TigerVNC Viewer)
**Execution user:** Local Windows User

**Commands:**
```powershell
# 1. Test network ports from Windows PowerShell (replace with your server IP)
Test-NetConnection -ComputerName 172.31.15.62 -Port 22
Test-NetConnection -ComputerName 172.31.15.62 -Port 5901

# 2. Test allowed SFTP login (user1)
sftp user1@172.31.15.62

# 3. Test denied SFTP login (user3)
sftp user3@172.31.15.62
```

**Validation:**
```bash
# Run on RHEL 9.8 server as root while clients are connected
ss -ntp | grep -E ':22|:590[1-4]'
ls -la /srv/sftp/user1/files
```

**Expected output:**
* PowerShell Test-NetConnection shows TcpTestSucceeded : True for port 22 and port 5901.
* TigerVNC Viewer connects directly to 172.31.15.62:5901 through 5904 for user1 through user4.
* sftp user1@172.31.15.62 logs in and allows file uploads inside the files directory.
* sftp user3@172.31.15.62 is rejected with Permission denied.

---

## 8. Service Management and Employee Lifecycle

### Step 20: Service Management Commands
**Server:** RHEL 9.8
**Execution user:** root

**Commands:**
```bash
# Restart all VNC services
systemctl restart vncserver@:{1..4}.service

# Reload SSHD safely after config edits
sshd -t && systemctl reload sshd

# Reload firewalld
firewall-cmd --reload
```

**Validation:**
```bash
systemctl is-active vncserver@:{1..4}.service sshd gdm firewalld
ss -lntp | grep -E ':22|:590[1-4]'
```

**Expected output:**
* All listed services report active.
* Ports 22 and 5901 through 5904 are in LISTEN state.

---

### Step 21: Onboard a New Employee (Example: user5 on Display :5 / Port 5905)
**Server:** RHEL 9.8
**Execution user:** root

**Commands:**
```bash
# Create user5 (use sftp-allowed or sftp-denied as required)
useradd -m -s /bin/bash -G sftp-allowed user5
chmod 700 /home/user5
passwd user5
su - user5 -c "vncpasswd"

# Create SFTP chroot if added to sftp-allowed
mkdir -p /srv/sftp/user5/files
chown root:root /srv /srv/sftp /srv/sftp/user5
chmod 755 /srv /srv/sftp /srv/sftp/user5
chown user5:sftp-allowed /srv/sftp/user5/files
chmod 700 /srv/sftp/user5/files
restorecon -Rv /srv/sftp/user5

# Map display :5 and open port 5905
echo ":5=user5" >> /etc/tigervnc/vncserver.users
sed -i 's/[[:space:]]*$//' /etc/tigervnc/vncserver.users
firewall-cmd --permanent --add-port=5905/tcp
firewall-cmd --reload
systemctl daemon-reload
systemctl enable --now vncserver@:5.service
```

**Validation:**
```bash
id user5
systemctl is-active vncserver@:5.service
ss -lntp | grep ':5905'
```

**Expected output:**
* Shows uid and sftp-allowed group for user5.
* vncserver@:5.service is active and listening on 0.0.0.0:5905.

---

### Step 22: Modify Existing Employee Access (Switch SFTP Group or Reset Password)
**Server:** RHEL 9.8
**Execution user:** root

**Commands:**
```bash
# Option A: Move user3 from sftp-denied to sftp-allowed
gpasswd -d user3 sftp-denied
usermod -aG sftp-allowed user3
mkdir -p /srv/sftp/user3/files
chown root:root /srv /srv/sftp /srv/sftp/user3
chmod 755 /srv /srv/sftp /srv/sftp/user3
chown user3:sftp-allowed /srv/sftp/user3/files
chmod 700 /srv/sftp/user3/files
restorecon -Rv /srv/sftp/user3

# Option B: Move user2 from sftp-allowed to sftp-denied
gpasswd -d user2 sftp-allowed
usermod -aG sftp-denied user2
pkill -u user2 sshd 2>/dev/null || true

# Option C: Reset Linux and VNC password for user1
passwd user1
su - user1 -c "vncpasswd"
systemctl restart vncserver@:1.service
```

**Validation:**
```bash
getent group sftp-allowed sftp-denied
sshd -T -C user=user3,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|forcecommand)'
sshd -T -C user=user2,host=localhost,addr=127.0.0.1 | grep -E '^(passwordauthentication|forcecommand)'
```

**Expected output:**
* Group list reflects updated memberships.
* Effective SSHD policy shows internal-sftp for user3 and nologin for user2.

---

### Step 23: Offboard a Leaving Employee (Revoke Access and Preserve Data)
**Server:** RHEL 9.8
**Execution user:** root

**Commands:**
```bash
# Stop VNC and remove display mapping for user2 (:2)
systemctl disable --now vncserver@:2.service
sed -i '/^:2=user2$/d' /etc/tigervnc/vncserver.users

# Lock account, expire login, and block SFTP
usermod -L user2
chage -E 0 user2
usermod -s /sbin/nologin user2
gpasswd -d user2 sftp-allowed 2>/dev/null || true
usermod -aG sftp-denied user2

# Terminate active sessions
loginctl terminate-user user2 2>/dev/null || true
pkill -9 -u user2 2>/dev/null || true

# Backup user files without deleting original data
mkdir -p /srv/archive/user2_$(date +%F)
chmod 700 /srv/archive/user2_$(date +%F)
cp -a /home/user2 /srv/archive/user2_$(date +%F)/home_backup 2>/dev/null || true
cp -a /srv/sftp/user2 /srv/archive/user2_$(date +%F)/sftp_backup 2>/dev/null || true
chown -R root:root /srv/archive/user2_$(date +%F)
```

**Validation:**
```bash
passwd -S user2
chage -l user2 | grep "Account expires"
ps -u user2 || echo "No active processes"
ls -ld /srv/archive/user2_*
```

**Expected output:**
* Password status shows LK (locked) and Account expires shows Jan 01, 1970.
* No active processes for user2, and backup directory exists under /srv/archive.

---

## 9. Troubleshooting Reference

| Problem | Cause | Fix Command / Action |
| :--- | :--- | :--- |
| TigerVNC error 10060 timeout | AWS Security Group closed or wrong server IP | Check IP with `hostname -I` and open TCP 5901-5904 in AWS Security Group |
| VNC service fails to start | Trailing spaces in vncserver.users or missing vncpasswd | Run `sed -i 's/[[:space:]]*$//' /etc/tigervnc/vncserver.users` and `su - user1 -c "vncpasswd"` |
| SFTP closes right after password | Chroot parent folder not owned by root:root 0755 | Run `chown root:root /srv /srv/sftp /srv/sftp/user1 && chmod 755 /srv /srv/sftp /srv/sftp/user1` |
| SFTP upload says Permission denied | Missing SELinux context or uploading outside files folder | Run `restorecon -Rv /srv/sftp && setsebool -P ssh_chroot_rw_homedirs on`, then `cd files` before `put` |
| Denied user can still log into SFTP | User was added to sftp-allowed group by mistake | Run `usermod -G sftp-denied user3` and verify with `getent group sftp-allowed sftp-denied` |
