# vault-cli
## Installing tpm2-tools
### Ubuntu/Debian
```bash
sudo apt install tpm2-tools
```
#### Dependencies
```bash
sudo apt-get install autoconf automake libtool pkg-config gcc \
    libssl-dev libcurl4-gnutls-dev python3-yaml
```

### Fedora/RHEL/CentOS
```bash
sudo dnf install tpm2-tools
```
#### Dependencies
```bash
sudo dnf -y update && sudo dnf -y install automake libtool \
autoconf autoconf-archive libstdc++-devel gcc pkg-config \
uriparser-devel libgcrypt-devel dbus-devel glib2-devel \
compat-openssl10-devel libcurl-devel PyYAML
```

### Arch Linux
```bash
sudo pacman -S tpm2-tools
```
