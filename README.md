# GSP Agent for Windows (Cygwin)

Turnkey installation of the **GameServer Panel (GSP) Agent** on Windows using **Cygwin**, with optional services:
- **Pure-FTPd (TLS)**
- **OpenSSH (sshd)**
- **Apache (httpd)**

The installer script, **`install_gsp_agent.bat`**, sets up Cygwin, fetches the latest GSP agent bundle, configures services, opens firewall ports, and schedules the agent to start at boot.

<p align="center">
  <a href="https://github.com/GameServerPanel/GSP-Agent-Windows/releases/download/stable_release/GSP_Stable.zip"><b>Download GSP_Stable.zip</b></a>
</p>

---

## Table of Contents

- [Why](#why)
- [Quick Start](#quick-start)
- [What the Installer Does](#what-the-installer-does)
- [Defaults (Paths & Ports)](#defaults-paths--ports)
- [Customization](#customization)
- [Operations](#operations)
- [Troubleshooting & Auditing](#troubleshooting--auditing)
- [Architecture](#architecture)
- [Security Notes](#security-notes)
- [Contributing](#contributing)
- [License](#license)

---

## Why

- **Parity across platforms:** Our Linux nodes use **Pure-FTPd**; using it under Cygwin gives consistent behavior on Windows.
- **Automated services:** Registers **sshd**, **pure-ftpd**, and **httpd** as Windows services via `cygrunsrv`.
- **Fast onboarding:** Drop one BAT file on a fresh box, run as admin, and you’re online in minutes.

---

## Quick Start

**Requirements**
- Windows Server 2019/2022 or Windows 10/11
- Administrator privileges
- Inbound firewall: **22/tcp (SSH)**, **21/tcp (FTP control)**, **80/tcp (HTTP)**, and **FTP passive range** (**50000–50100/tcp** by default)
- If behind NAT: port forwarding for the above; consider a fixed external IP for FTP passive mode

**Install**
1. Place **`install_gsp_agent.bat`** on the target machine.
2. Right-click → **Run as administrator**.
3. When prompted, set a password for the **`cyg_server`** service account.
4. The script will:
   - Install **Cygwin** into the folder containing the BAT
   - Install & configure **OpenSSH**, **Pure-FTPd (TLS)**, **Apache**
   - Download and unpack **[`GSP_Stable.zip`](https://github.com/GameServerPanel/GSP-Agent-Windows/releases/download/stable_release/GSP_Stable.zip)**
   - Run the agent configurator
   - Create a boot-time scheduled task: **“OGP agent start on boot”**

**Verify**
```bash
# In a Cygwin terminal (bash)
cygrunsrv -Q sshd
cygrunsrv -Q pure-ftpd
cygrunsrv -Q httpd

# See agent running
ps -ef | grep ogp_agent
