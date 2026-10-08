# ish-lab

Turn iSH on your iPhone into an SSH server you can reach from your laptop.

## Install (run in iSH)

```sh
apk add git
git clone https://github.com/Madcroo94/ish-lab
cd ish-lab
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

## If the laptop can't connect

- Phone and laptop on the same Wi-Fi (not a guest network).
- Settings > Privacy & Security > Local Network > iSH is on.
- Settings > iSH > Location > Always (keeps iSH alive in the background).
- Still failing? Use the reverse tunnel. On iSH: `sh tunnel.sh you@laptop-ip`. On the laptop: `ssh -p 2222 root@localhost`.
- To see the real error: `pkill sshd; /usr/sbin/sshd -D -e`.
