#some tasks run in the VM as soon as the vm is up

cp .bashrc .bash_profile

bootadm set-menu timeout=1

svcadm disable sendmail

cat /etc/auto_master | grep -v /home >auto.txt
cat auto.txt >/etc/auto_master
rm -f auto.txt

automount -v
svcadm restart autofs


# Fix issues with locale settings that can cause spurious failures.
nlsadm set-system-locale C
unset LC_ALL LANG LC_CTYPE LC_COLLATE LC_NUMERIC LC_TIME LC_MONETARY LC_MESSAGES
export LC_ALL=C
export LANG=C
export LC_COLLATE=C

# Perform full OS update
pkg update --accept --no-backup-be -v
