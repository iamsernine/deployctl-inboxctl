# Presentation demo runbook

This file is for preparing and recording the project demo.

Target setup:

- Windows workstation: runs `inboxctl`.
- Ubuntu VM: already connected; will show 5 deployctl projects.
- Debian VM: must be connected by SSH; will show 5 deployctl projects.
- SSH user: `sernine`.
- Ubuntu already has 2 projects on ports `8080` and `8081`.
- Debian example IP below: `192.168.1.79`. Replace with the real Debian IP.

Important truth for the teacher:

- `-f` is implemented as a background child process followed by `wait`.
- `-s` is implemented as a real Bash subshell.
- `-t` is currently parsed but not a real thread/parallel implementation. In the demo, say: "the flag is accepted, but the code still needs the parallel branch."

## 0. Demo story

The clean video should show:

1. `deployctl` help.
2. Ubuntu has 5 deployed projects.
3. Debian has 5 deployed projects.
4. One deploy in normal mode.
5. One deploy in subshell mode `-s`.
6. One deploy in fork mode `-f`.
7. One deploy with `-t`, while explaining it is incomplete.
8. Logs in `history.log`.
9. `inboxctl` adding both servers.
10. `inboxctl` testing SSH.
11. `inboxctl` fetching both servers.
12. `inboxctl` showing projects, live projects, logs, errors, watch.

If the teacher asks for a live demo, do only one fast dry-run or one prepared real deploy.

## 1. Connect to Debian by SSH

### On Debian VM

Install and start SSH:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

Find Debian IP:

```bash
hostname -I
ip addr show
```

Assume Debian IP is:

```text
192.168.1.79
```

### On Windows PowerShell

Test network:

```powershell
ping 192.168.1.79
```

Generate an SSH key if you do not already have one:

```powershell
ssh-keygen -t ed25519 -C "sernine-demo"
```

Copy the public key to Debian:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh sernine@192.168.1.79 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Test SSH:

```powershell
ssh sernine@192.168.1.79
```

### On Git Bash or WSL

Alternative key copy:

```bash
ssh-copy-id sernine@192.168.1.79
ssh sernine@192.168.1.79
```

## 2. Server preparation for Ubuntu and Debian

Run this on both Ubuntu and Debian.

Install dependencies:

```bash
sudo apt update
sudo apt install -y git docker.io nginx curl iproute2
sudo systemctl enable --now docker
sudo systemctl enable --now nginx
sudo usermod -aG docker sernine
```

Install `deployctl` from the project repository:

```bash
cd ~/deployctl-inboxctl
sudo bash deployctl/install.sh
deployctl --help
```

Check the server:

```bash
sudo deployctl check
sudo tail -n 20 /var/log/deployctl/history.log
```

## 3. Prepare one reusable demo app repository

Run this on both Ubuntu and Debian. This creates a local Git repository that deployctl can clone without internet.

```bash
mkdir -p /opt/deployctl-demo-source
sudo chown -R "$USER:$USER" /opt/deployctl-demo-source
cd /opt/deployctl-demo-source
```

Create `app.py`:

```bash
cat > app.py <<'EOF'
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("PORT", "8080"))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
            return
        self.send_response(200)
        self.end_headers()
        msg = f"deployctl demo app running on port {PORT}\n"
        self.wfile.write(msg.encode())

HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
EOF
```

Create `Dockerfile`:

```bash
cat > Dockerfile <<'EOF'
FROM python:3.12-alpine
WORKDIR /app
COPY app.py /app/app.py
CMD ["python", "/app/app.py"]
EOF
```

Create `.env.example` with one prompt only:

```bash
cat > .env.example <<'EOF'
PORT=8080
EOF
```

Commit it:

```bash
git init
git add app.py Dockerfile .env.example
git commit -m "demo app for deployctl presentation"
```

The repo URL used by deployctl will be:

```text
file:///opt/deployctl-demo-source
```

## 4. Prepare Ubuntu projects

Ubuntu target table:

| App | Port | Demo mode |
|---|---:|---|
| `ubuntu-app-8080` | 8080 | already deployed or normal |
| `ubuntu-app-8081` | 8081 | already deployed or normal |
| `ubuntu-app-8082` | 8082 | subshell `-s` |
| `ubuntu-app-8083` | 8083 | fork `-f` |
| `ubuntu-app-8084` | 8084 | thread flag `-t` |

If the first two already exist, just verify them:

```bash
deployctl status ubuntu-app-8080 || true
deployctl status ubuntu-app-8081 || true
curl -s http://127.0.0.1:8080
curl -s http://127.0.0.1:8081
```

If you need to create or recreate all five before the video:

```bash
printf '8080\n' | sudo deployctl deploy ubuntu-app-8080 \
  --repo file:///opt/deployctl-demo-source \
  --domain ubuntu-app-8080.local \
  --port 8080 \
  --ssl no

printf '8081\n' | sudo deployctl deploy ubuntu-app-8081 \
  --repo file:///opt/deployctl-demo-source \
  --domain ubuntu-app-8081.local \
  --port 8081 \
  --ssl no

printf '8082\n' | sudo deployctl -s deploy ubuntu-app-8082 \
  --repo file:///opt/deployctl-demo-source \
  --domain ubuntu-app-8082.local \
  --port 8082 \
  --ssl no

printf '8083\n' | sudo deployctl -f deploy ubuntu-app-8083 \
  --repo file:///opt/deployctl-demo-source \
  --domain ubuntu-app-8083.local \
  --port 8083 \
  --ssl no

printf '8084\n' | sudo deployctl -t deploy ubuntu-app-8084 \
  --repo file:///opt/deployctl-demo-source \
  --domain ubuntu-app-8084.local \
  --port 8084 \
  --ssl no
```

Verify Ubuntu:

```bash
deployctl list live
deployctl status ubuntu-app-8080
deployctl status ubuntu-app-8081
deployctl status ubuntu-app-8082
deployctl status ubuntu-app-8083
deployctl status ubuntu-app-8084

curl -s http://127.0.0.1:8080
curl -s http://127.0.0.1:8081
curl -s http://127.0.0.1:8082
curl -s http://127.0.0.1:8083
curl -s http://127.0.0.1:8084

sudo tail -n 30 /var/log/deployctl/history.log
```

## 5. Prepare Debian projects

Debian target table:

| App | Port | Demo mode |
|---|---:|---|
| `debian-app-8090` | 8090 | normal |
| `debian-app-8091` | 8091 | subshell `-s` |
| `debian-app-8092` | 8092 | fork `-f` |
| `debian-app-8093` | 8093 | custom logs `-l` |
| `debian-app-8094` | 8094 | thread flag `-t` |

Deploy all five before the video:

```bash
printf '8090\n' | sudo deployctl deploy debian-app-8090 \
  --repo file:///opt/deployctl-demo-source \
  --domain debian-app-8090.local \
  --port 8090 \
  --ssl no

printf '8091\n' | sudo deployctl -s deploy debian-app-8091 \
  --repo file:///opt/deployctl-demo-source \
  --domain debian-app-8091.local \
  --port 8091 \
  --ssl no

printf '8092\n' | sudo deployctl -f deploy debian-app-8092 \
  --repo file:///opt/deployctl-demo-source \
  --domain debian-app-8092.local \
  --port 8092 \
  --ssl no

printf '8093\n' | sudo deployctl -l /tmp/debian-deployctl-logs deploy debian-app-8093 \
  --repo file:///opt/deployctl-demo-source \
  --domain debian-app-8093.local \
  --port 8093 \
  --ssl no

printf '8094\n' | sudo deployctl -t deploy debian-app-8094 \
  --repo file:///opt/deployctl-demo-source \
  --domain debian-app-8094.local \
  --port 8094 \
  --ssl no
```

Verify Debian:

```bash
deployctl list live
deployctl status debian-app-8090
deployctl status debian-app-8091
deployctl status debian-app-8092
deployctl status debian-app-8093
deployctl status debian-app-8094

curl -s http://127.0.0.1:8090
curl -s http://127.0.0.1:8091
curl -s http://127.0.0.1:8092
curl -s http://127.0.0.1:8093
curl -s http://127.0.0.1:8094

sudo tail -n 30 /var/log/deployctl/history.log
cat /tmp/debian-deployctl-logs/history.log
```

## 6. Clean deployctl video sequence

Use this when recording. Avoid package installs and file creation in the video.

### Ubuntu video commands

```bash
deployctl --help
deployctl version
deployctl list live

deployctl status ubuntu-app-8080
deployctl status ubuntu-app-8081
deployctl status ubuntu-app-8082
deployctl status ubuntu-app-8083
deployctl status ubuntu-app-8084

curl -s http://127.0.0.1:8080
curl -s http://127.0.0.1:8081
curl -s http://127.0.0.1:8082
curl -s http://127.0.0.1:8083
curl -s http://127.0.0.1:8084

sudo tail -n 20 /var/log/deployctl/history.log
```

### Debian video commands

Connect from Windows:

```powershell
ssh sernine@192.168.1.79
```

Then on Debian:

```bash
deployctl --help
deployctl list live

deployctl status debian-app-8090
deployctl status debian-app-8091
deployctl status debian-app-8092
deployctl status debian-app-8093
deployctl status debian-app-8094

curl -s http://127.0.0.1:8090
curl -s http://127.0.0.1:8091
curl -s http://127.0.0.1:8092
curl -s http://127.0.0.1:8093
curl -s http://127.0.0.1:8094

sudo tail -n 20 /var/log/deployctl/history.log
```

### Show flags cleanly with dry-run

These are safe and fast:

```bash
deployctl -n -l /tmp/flag-demo-logs deploy normal-demo \
  --repo file:///opt/deployctl-demo-source \
  --domain normal-demo.local \
  --port 8100 \
  --ssl no

deployctl -n -s -l /tmp/flag-demo-logs deploy subshell-demo \
  --repo file:///opt/deployctl-demo-source \
  --domain subshell-demo.local \
  --port 8101 \
  --ssl no

deployctl -n -f -l /tmp/flag-demo-logs deploy fork-demo \
  --repo file:///opt/deployctl-demo-source \
  --domain fork-demo.local \
  --port 8102 \
  --ssl no

deployctl -n -t -l /tmp/flag-demo-logs deploy thread-flag-demo \
  --repo file:///opt/deployctl-demo-source \
  --domain thread-flag-demo.local \
  --port 8103 \
  --ssl no

cat /tmp/flag-demo-logs/history.log
```

Say this sentence for `-t`:

```text
The thread flag is present in the parser, but the current code does not yet implement real parallel execution. This is documented as an incomplete requirement.
```

## 7. inboxctl preparation on Windows

Use Git Bash or WSL from the repository root.

Install inboxctl:

```bash
bash inboxctl/install.sh
inboxctl --help
```

Add Ubuntu and Debian:

```bash
inboxctl add-server ubuntu-vm sernine@192.168.1.78
inboxctl add-server debian-vm sernine@192.168.1.79
```

If the server names already exist and you want a clean reset:

```bash
inboxctl remove-server ubuntu-vm
inboxctl remove-server debian-vm
inboxctl add-server ubuntu-vm sernine@192.168.1.78
inboxctl add-server debian-vm sernine@192.168.1.79
```

Test SSH:

```bash
inboxctl test ubuntu-vm
inboxctl test debian-vm
```

Important: if `inboxctl fetch` cannot read `/etc/deployctl` or `/var/log/deployctl`, give the SSH user read access or use a privileged user. For demo simplicity on each VM, you can allow `sernine` to read deployctl metadata/logs:

```bash
sudo chmod -R a+rX /etc/deployctl /var/log/deployctl /var/lib/deployctl/state
```

This is acceptable for a classroom VM, but do not use broad permissions like this on a real production server.

Fetch once before video:

```bash
inboxctl fetch ubuntu-vm
inboxctl fetch debian-vm
```

## 8. Clean inboxctl video sequence

Run from Windows Git Bash or WSL:

```bash
inboxctl --help
inboxctl version

inboxctl list servers
inboxctl show servers

inboxctl test ubuntu-vm
inboxctl test debian-vm

inboxctl fetch ubuntu-vm
inboxctl fetch debian-vm

inboxctl show projects ubuntu-vm
inboxctl show live ubuntu-vm
inboxctl logs ubuntu-vm ubuntu-app-8080
inboxctl errors ubuntu-vm

inboxctl show projects debian-vm
inboxctl show live debian-vm
inboxctl logs debian-vm debian-app-8090
inboxctl errors debian-vm
```

For `watch`, record only a few seconds:

```bash
inboxctl watch ubuntu-vm
```

Stop with `Ctrl+C`.

Also show local cache:

```bash
ls -R ~/.cache/inboxctl/servers
```

## 9. One live test if teacher asks

Fastest safe live demo: dry-run deploy with logs.

```bash
deployctl -n -v -l /tmp/live-teacher-demo deploy teacher-live-demo \
  --repo file:///opt/deployctl-demo-source \
  --domain teacher-live-demo.local \
  --port 8110 \
  --ssl no

cat /tmp/live-teacher-demo/history.log
```

If the teacher asks for a real deploy:

```bash
printf '8110\n' | sudo deployctl deploy teacher-live-demo \
  --repo file:///opt/deployctl-demo-source \
  --domain teacher-live-demo.local \
  --port 8110 \
  --ssl no

deployctl status teacher-live-demo
curl -s http://127.0.0.1:8110
sudo tail -n 20 /var/log/deployctl/history.log
```

Then from Windows:

```bash
inboxctl fetch ubuntu-vm
inboxctl show projects ubuntu-vm
inboxctl logs ubuntu-vm teacher-live-demo
```

## 10. Final checklist before recording

- Ubuntu SSH works from Windows.
- Debian SSH works from Windows.
- `deployctl --help` works on both VMs.
- Docker and nginx are running on both VMs.
- Ubuntu has 5 apps visible with `deployctl list live`.
- Debian has 5 apps visible with `deployctl list live`.
- `curl` works for all 10 ports.
- `history.log` has recent `INFOS` lines.
- At least one `ERROR` line exists if you want to show `inboxctl errors`; otherwise it will correctly print `(no ERROR lines)`.
- `inboxctl list servers` shows both `ubuntu-vm` and `debian-vm`.
- `inboxctl fetch` works for both servers.
- `inboxctl show projects` shows both servers' apps.
- Be ready to say clearly: `-t` is incomplete in the current codebase.
