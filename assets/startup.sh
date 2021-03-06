#! /bin/bash

# If the repository GPG keypair doesn't exist, create it.
if [[ ! -f /opt/aptly/aptly.pub ]]; then
  /opt/gpg_batch.sh
  # If your system doesn't have a lot of entropy this may, take a long time
  # Google how-to create "artificial" entropy if this gets stuck
  gpg2 --batch --gen-key /opt/gpg_batch
  chmod 700 ~/.gnupg
fi

# Export the GPG Public key
if [[ ! -f /opt/aptly/public/aptly_repo_signing.key ]]; then
  mkdir -p /opt/aptly/public
  gpg2 --import /opt/aptly/aptly.pub
  gpg2 --export --armor > /opt/aptly/public/aptly_repo_signing.key
fi

# Import Ubuntu keyrings if they exist
if [[ -f /usr/share/keyrings/ubuntu-archive-keyring.gpg ]]; then
  gpg2 --list-keys
  gpg2 --no-default-keyring                                     \
       --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg \
       --export |                                               \
  gpg2 --no-default-keyring                                     \
       --keyring trustedkeys.gpg                                \
       --import
fi

# Import Debian keyrings if they exist
if [[ -f /usr/share/keyrings/debian-archive-keyring.gpg ]]; then
  gpg2 --list-keys
  gpg2 --no-default-keyring                                     \
       --keyring /usr/share/keyrings/debian-archive-keyring.gpg \
       --export > /root/.gnupg/trustedkeys.gpg
fi

# Aptly looks in /root/.gnupg for default keyrings
#ln -sf /opt/aptly/aptly.sec /root/.gnupg/secring.gpg
ln -sf /opt/aptly/aptly.pub /root/.gnupg/pubring.gpg

# Generate Nginx Config
/opt/nginx.conf.sh

# ssh related things
# add a user for uploading packages with e.g. dput
SSH_USERPASS=`pwgen -c -n -1 8`
mkdir /home/uploader
useradd -d /home/uploader -s /bin/bash uploader
chown -R uploader /home/uploader

mkdir /opt/incoming
chown -R uploader /opt/incoming

# add a place for the logs
mkdir /opt/logs

echo "uploader:$SSH_USERPASS" | chpasswd
echo "ssh uploader password: $SSH_USERPASS"

# import new packages which are placed in /opt/incoming
crontab <<EOF
@reboot inoticoming --logfile /opt/logs/inoticoming.log /opt/incoming/ --chdir /opt/incoming/ --stdout-to-log --suffix .changes /opt/aptly-import.sh {} \;
EOF

# Start Supervisor
/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
