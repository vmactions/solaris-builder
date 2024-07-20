#some tasks run in the VM as soon as the vm is up

cp .bashrc .bash_profile

## Fix issues with locale settings that can cause spurious failures.
unset LC_ALL LANG LC_CTYPE LC_COLLATE LC_NUMERIC LC_TIME LC_MONETARY LC_MESSAGES
export LC_ALL=C
export LANG=C
export LC_COLLATE=C

bootadm set-menu timeout=1

svcadm disable sendmail

cat /etc/auto_master | grep -v /home >auto.txt
cat auto.txt >/etc/auto_master
rm -f auto.txt

automount -v
svcadm restart autofs

# We are using the CBE solaris release now, it doesn't have any updates but it
# does have the wrong package publisher set by default:
#  https://blogs.oracle.com/solaris/post/building-open-source-software-on-oracle-solaris-114-cbe-release
pkg set-publisher -G'*' -g http://pkg.oracle.com/solaris/release/ solaris


# Install legacy OpenCSW package repository
wget -L http://get.opencsw.org/now
echo y | pkgadd -v -d now all
rm -f now
if ! /opt/csw/bin/pkgutil -U ; then
  echo "pkgutil failed"
fi
gsed -i 's|#SUPATH=/usr/bin:/usr/sbin|SUPATH=/usr/bin:/usr/sbin:/opt/csw/bin|' /etc/default/login


# If CBE ever starts releasing upgrades, we'll need to re-enable the upgrade:
#pkg update --accept --no-backup-be -v
