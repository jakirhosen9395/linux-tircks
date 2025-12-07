# Ubuntu Server Update & Time Configuration Guide

এই ডকুমেন্টটি **Ubuntu Server** তৈরির পর সঠিকভাবে **time zone সেট করা**, তারপর **system update ও upgrade** করার সম্পূর্ণ নির্দেশনা প্রদান করে। DevOps environment-এ server প্রস্তুত করার এটি একটি স্ট্যান্ডার্ড ও নিরাপদ workflow।

---

## 1. Prerequisite

সার্ভারে login করার পর নিশ্চিত করুন:

- আপনার কাছে **sudo privileges** আছে  
- সার্ভারটি **Internet connected**  
- আপনি **Ubuntu 22.04 LTS** অথবা তার নতুন stable version ব্যবহার করছেন

---

## 2. Server Time Zone Set করা

সঠিক Time Zone সেট না থাকলে log, cron job, monitoring, security audit—এসব ক্ষেত্রে সমস্যা হতে পারে।

### Time Zone সেট করার Command

```bash
sudo timedatectl set-timezone Asia/Dhaka
```

### Time Status যাচাই

```bash
timedatectl status
```

---

## 3. System Update & Upgrade (Safe DevOps Practice)

সার্ভার নতুন তৈরি হলে সর্বপ্রথম **package list update** এবং **system upgrade** করা জরুরি। নিচের command টি সম্পূর্ণ Server maintenance flow follow করে:

### Update & Upgrade Command

```bash
sudo apt update -y && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo apt autoremove -y && sudo apt clean
```

### Command Breakdown

| Command | Explanation |
|--------|-------------|
| `apt update` | package list refresh করে |
| `apt upgrade` | নতুন version available package update করে |
| `apt dist-upgrade` | dependency change হলে সেগুলো manage করে |
| `apt autoremove` | অপ্রয়োজনীয় প্যাকেজ remove করে |
| `apt clean` | local archive clean করে disk space খালি রাখে |

---

## 4. Best Practice (DevOps Standard)

- সবসময় update-এর আগে **backup বা snapshot** রাখা উচিত  
- Production server-এ update করার আগে **staging server**-এ test করা উচিত  
- Critical workload-এর ক্ষেত্রে `reboot` প্রয়োজন হতে পারে:

```bash
sudo reboot
```

---

## 5. Additional Security Hardening (Highly Recommended)

- **UFW Firewall Enable**

```bash
sudo ufw enable
sudo ufw status
```

- **Fail2ban Install**

```bash
sudo apt install fail2ban -y
```

---

## 6. Useful Links

- Ubuntu Official Docs: https://ubuntu.com/server/docs  
- timedatectl Reference: https://man.archlinux.org/man/timedatectl.1  

---

## Conclusion

এই guide ব্যবহার করে আপনি server setup-এর পরে একটি পরিষ্কার, নিরাপদ এবং standard DevOps update workflow maintain করতে পারবেন।  
Server-এর health, security এবং performance বজায় রাখতে নিয়মিত update করা অত্যন্ত গুরুত্বপূর্ণ।
