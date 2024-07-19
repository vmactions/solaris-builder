#some tasks run in the VM as soon as the vm is up

cp .bashrc .bash_profile

bootadm set-menu timeout=1

svcadm disable sendmail

cat /etc/auto_master | grep -v /home >auto.txt
cat auto.txt >/etc/auto_master
rm -f auto.txt

automount -v
svcadm restart autofs

pkg update --accept
