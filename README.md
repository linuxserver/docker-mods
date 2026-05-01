# Trusted CA - Docker mod for openssh-server

This mod allow the configuration of the `TrustedUserCAKeys` directive, which allows ssh authentication using certificates.

In openssh-server docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:openssh-server-trusted-ca`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:openssh-server-trusted-ca|linuxserver/mods:openssh-server-mod2`

## Mod environment variables
In order to add a certificate authority, you can add your CA's public keys in one or multiple environment variables:
* `TRUSTED_CA="your_ca_pubkey"` to add one CA to the TrustedCA file from text.
* `TRUSTED_CA_URL="https://example.com/trusted_ca.key"` to retrieve one or more trusted CA from a URL.
* `TRUSTED_CA_FILE="/mounted_file"` to add one or more CA from a file (inside the container's tree).
* `TRUSTED_CA_DIR="/mounted_dir"` to add CAs from the content of a directory (inside the container's tree).

You can use multiple environment variables at the same time to add different CAs.

Certificates are added/removed from the server when the container is starting, so you will need to restart your container for your change to take effect.

# Example
If you want to build your own CA:
```
# Create temp directory and cd there
cd $(mktemp -d)

# Generate key pairs (x and x.pub)
ssh-keygen -b 4096 -t ed25519 -f myca
ssh-keygen -b 4096 -t ed25519 -f userkey

# Sign users pubkeys (x-cert.pub)
ssh-keygen -s myca -I my_user_certificate_id -n myuser userkey.pub
```

Notes: `-n` parameter gives the username principals, it must match the target user (see `man 1 ssh-keygen`).

```
services:
  openssh-server:
    image: linuxserver/openssh-server
    environment:
      - DOCKER_MODS=linuxserver/mods:openssh-server-trusted-ca
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - USER_NAME=myuser
      - TRUSTED_CA_FILE=/pubkey
    volumes:
      - ./myca.pub:/pubkey:ro,z
    ports:
      - 2222:2222
```

You can then connect using:
```
ssh -p 2222 -i ./userkey myuser@127.0.0.1

# Or specify the certificate explicitly:
ssh -o CertificateFile=./userkey-cert.pub -p 2222 -i ./userkey myuser@127.0.0.1
```
