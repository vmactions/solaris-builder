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

echo "set zfs:zfs_unmap_ignore_size=0x10000" > /etc/system.d/zfs
echo "set zfs:zfs_log_unmap_ignore_size=0x10000" >> /etc/system.d/zfs

# Try to debug random network issues
echo "==== Network Configuration ===="
echo "** ip address:"
ifconfig -a
echo "** dns configuration:"
cat /etc/resolv.conf
echo "==============================="

# Install legacy OpenCSW package repository
/usr/bin/wget --no-check-certificate https://get.opencsw.org/now
echo y | pkgadd -d ./now all
if ! /opt/csw/bin/pkgutil -U ; then
  echo "pkgutil failed"
fi
rm -f now

gsed -i 's|#SUPATH=/usr/bin:/usr/sbin|SUPATH=/usr/bin:/usr/sbin:/opt/csw/bin|' /etc/default/login

SOLARIS_VER=`uname -v`

#if [ "$SOLARIS_VER" = "11.4.42.111.0" ] ; then
  # If using the CBE release, we need to set the proper publisher and try to
  # do a full system update (but at this time it appears Oracle isn't publishing
  # updates for CBE)
  #  https://blogs.oracle.com/solaris/post/building-open-source-software-on-oracle-solaris-114-cbe-release
  pkg set-publisher -G'*' -g http://pkg.oracle.com/solaris/release/ solaris

  # Refresh Package list
  pkg refresh --full

  # Upgrade release.  Catch return code 4 and treat as success as it just means
  # nothing to upgrade.
  rv=0
  pkg update --accept --no-backup-be -v '*' || rv=$?
  if [ "$rv" != 0 -a "$rv" != 4 ] ; then
    echo "pkg update failed"
    exit 1
  fi
#else
#  # When not using CBE we need to update the CA Certificates
#  ls -lah /opt/csw/bin/
#  /opt/csw/bin/pkgutil -y -i cacertificates
#  rm -rf /etc/openssl/certs/*
#  cp /etc/opt/csw/ssl/certs/* /etc/openssl/certs/
#fi
