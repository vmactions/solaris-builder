
set -e
wget -L http://get.opencsw.org/now
echo y |  pkgadd -v  -d now  all
rm -f now

cp .bashrc .bash_profile
gsed -i 's|#SUPATH=/usr/bin:/usr/sbin|SUPATH=/usr/bin:/usr/sbin:/opt/csw/bin|' /etc/default/login







