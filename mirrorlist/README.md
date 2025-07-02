## Arch Linux aur-repo mirrorlist

Add and trust my GPG key in pacman keyring:

```bash
sudo pacman-key --recv-keys FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
sudo pacman-key --lsign-key FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
```

Add the following lines to `/etc/pacman.conf`:

```ini
[aur-repo]
## China Telecom Network (200Mbps) (ipv4, http, https)
Server = https://rom.ie8.pub:2443/aur-repo/$arch
```

```ini
[aur-repo]
## China Telecom Network (100Mbps) (ipv4, ipv6, http, https)
Server = https://fun.ie8.pub:2443/aur-repo/$arch
```

```ini
[aur-repo]
## CloudFlare Preferred CDN (ipv4, ipv6, http, https)
Server = https://mirrors.kicad.online/aur-repo/$arch
```

```ini
[aur-repo]
## CloudFlare Free CDN (ipv4, ipv6, http, https)
Server = https://aur-repo.taotieren.com/aur-repo/$arch
```

```ini
[aur-repo]
## China Mobile Network (50Mbps) (ipv6, http, https)
Server = https://aur-repo6.taotieren.com/aur-repo/$arch
```

```bash
pacman -Syu aur-repo-mirrorlist-git
```

```ini
[aur-repo]
Include = /etc/pacman.d/aur-repo-mirrorlist
```

## Arch Linux aur-repo debuginfod configuration

```bash
cp -v aur-repo.urls /etc/debuginfod/
```

## Rsync

```bash
## Only IPv6
## Status: OK
rsync rsync://aur-repo6.taotieren.com
rsync -avzP --bwlimit=30720 --timeout=120 --contimeout=120  --exclude-from=/opt/rsync/exclude.list rsync://aur-repo6.taotieren.com/aur-repo /opt/sync/aur-repo

## Only IPv4
## Status: FAILED
# rsync rsync://aur-repo6.taotieren.com
# rsync -avzP --bwlimit=30720 --timeout=120 --contimeout=120  --exclude-from=/opt/rsync/exclude.list rsync://aur-repo6.taotieren.com/aur-repo /opt/sync/aur-repo
```
