
# 📁 Linux Filesystem Overview

This repository provides a visual and textual overview of the **Linux filesystem hierarchy**, explaining the purpose of each major directory under the root (`/`) directory.

![Linux Filesystem Overview](./A_diagram_titled_"Linux_Filesystem_Overview"_prese.png)

---

## 📂 Top-Level Directories Explained

| Directory | Description |
|-----------|-------------|
| `/`       | Root of the filesystem. Everything starts here. |
| `/bin`    | Essential command binaries (e.g., `ls`, `cp`). |
| `/boot`   | Boot loader files including the Linux kernel. |
| `/dev`    | Device files representing hardware and virtual devices. |
| `/etc`    | System-wide configuration files. |
| `/home`   | User home directories. |
| `/lib`    | Essential shared libraries for binaries in `/bin` and `/sbin`. |
| `/media`  | Mount point for removable media (USB, CD-ROM, etc.). |
| `/mnt`    | Temporary mount point for mounting filesystems. |
| `/opt`    | Optional application software packages. |
| `/proc`   | Virtual filesystem for kernel and process information. |
| `/root`   | Home directory for the root user. |
| `/run`    | Volatile runtime data since the last boot. |
| `/sbin`   | System binaries used for system administration. |
| `/srv`    | Data for services provided by the system (web, FTP, etc.). |
| `/tmp`    | Temporary files (automatically cleared). |
| `/usr`    | Secondary hierarchy for user utilities and applications. |
| `/var`    | Variable data like logs, mail, spool files, and temporary files. |

---

## 📌 Usage

- View the image file `linux-structure-diagram.png` to get a visual representation.
- Read the descriptions above to understand what each directory is responsible for.

---

## 📷 Diagram Attribution

The diagram included in this repository was generated for educational and illustrative purposes.

---

## 🧠 Additional Resources

- [Filesystem Hierarchy Standard (FHS)](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- `man hier` — Run this command in terminal for manual on filesystem hierarchy.

---

## ✅ License

This project is provided for public learning and can be reused with credit.

---

**Happy Learning!** ✨
