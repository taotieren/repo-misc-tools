## Arch Linux aur-repo mirrorlist

Add and trust my GPG key in pacman keyring:

```bash
sudo pacman-key --recv-keys FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
sudo pacman-key --lsign-key FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
```

Add the following lines to `/etc/pacman.conf`:

```ini
[aur-repo]
## China Telecom Network (100Mbps) (ipv4, ipv6, http, https)
Server = https://fun.ie8.pub:2443/aur-repo/$arch
```

```ini
[aur-repo]
## China Mobile Network (50Mbps) (ipv6, http, https)
Server = https://aur-repo.taotieren.com/aur-repo/$arch
```

```bash
yay -Ss aur-repo-mirrorlist-git
```

```ini
[aur-repo]
Include = /etc/pacman.d/aur-repo-mirrorlist
```

## Arch Linux aur-repo debuginfod configuration

```bash
cp -v aur-repo.urls /etc/debuginfod/
```

## Rysnc

```bash
## Only IPv6
## Status: OK
rsync rsync://aur-repo.taotieren.com
rsync -avzP --bwlimit=30720 --timeout=120 --contimeout=120  --exclude-from=/opt/rsync/exclude.list rsync://aur-repo.taotieren.com/aur-repo /opt/sync/aur-repo

## Only IPv4
## Status: NO
# rsync rsync://aur-repo.taotieren.com
# rsync -avzP --bwlimit=30720 --timeout=120 --contimeout=120  --exclude-from=/opt/rsync/exclude.list rsync://aur-repo.taotieren.com/aur-repo /opt/sync/aur-repo
```
