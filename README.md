# ish-lab

Turn iSH on your iPhone into an SSH server you can reach from your laptop.

## Install (run in iSH)

```sh
apk add git
git clone https://github.com/Madcroo94/iSH
cd iSH
sh setup-ssh.sh
```

When it finishes it prints the command to run on your laptop, like:

```sh
ssh -p 2222 root@192.168.1.42
```

What the script does: installs OpenSSH, makes host keys, writes a working `/etc/ssh/sshd_config` (port 2222), asks you for a root password, starts sshd, starts the background keep-alive, and makes sshd start again every time you open iSH. Re-running it is safe.

Options:

```sh
PORT=2200 sh setup-ssh.sh                              # different port
PUBKEY="$(cat id_ed25519.pub)" sh setup-ssh.sh          # allow your laptop's key
```

## Phone lab: status page and health checks

Once SSH works, turn the phone into a lab node (run in iSH, from the same folder):

```sh
sh install-lab.sh
```

This installs `busybox-extras` (for its web server), copies the lab into `/root/lab`, starts it, and makes it start every time you open iSH. Then open `http://<phone-ip>:8080/` on the laptop for a status page that refreshes every minute (`/status.json` has the same data for scripts).

```
/root/lab/
  etc/node.conf   # node name, role, ports (kept when you re-run the installer)
  bin/lab.sh      # start | stop | status | restart
  bin/health.sh   # checks sshd, httpd, keep-alive; writes www/status.json + www/index.html
  bin/loop.sh     # reruns health.sh every 60 s
  www/  logs/  nodes/
```

Name a node on first install: `NODE_NAME=phone2 NODE_ROLE=worker NODE_IP=10.0.0.251 sh install-lab.sh`. Ports are the same on every phone: SSH 2222, status page 8080, new services 8081 and up.

`lab.sh stop` never stops sshd or the keep-alive, so you can't lock yourself out. To remove the lab completely: `sh install-lab.sh uninstall` (SSH setup is left as is).

Run the offline tests on any machine with `sh tests/run.sh`.

## If the laptop can't connect

- Phone and laptop on the same Wi-Fi (not a guest network).
- Settings > Privacy & Security > Local Network > iSH is on.
- Settings > iSH > Location > Always (keeps iSH alive in the background).
- Still failing? Use the reverse tunnel. On iSH: `sh tunnel.sh you@laptop-ip`. On the laptop: `ssh -p 2222 root@localhost`.
- To see the real error: `pkill sshd; /usr/sbin/sshd -D -e`.
