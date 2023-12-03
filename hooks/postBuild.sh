#some tasks run in the VM as soon as the vm is up


wget -L http://get.opencsw.org/now

echo y |  pkgadd -v  -d now  all

rm -f now 

if ! /opt/csw/bin/pkgutil -U ; then
  echo "pkgutil failed"
  sleep 10
fi



cp .bashrc .bash_profile

gsed -i 's|#SUPATH=/usr/bin:/usr/sbin|SUPATH=/usr/bin:/usr/sbin:/opt/csw/bin|' /etc/default/login



ls -lah /opt/csw/bin/


/opt/csw/bin/pkgutil -y -i cacertificates

rm -rf /etc/openssl/certs/*

cp /etc/opt/csw/ssl/certs/* /etc/openssl/certs/



bootadm set-menu timeout=1


svcadm disable sendmail

cat /etc/auto_master | grep -v /home >auto.txt
cat auto.txt >/etc/auto_master
rm -f auto.txt

automount -v
svcadm restart autofs



