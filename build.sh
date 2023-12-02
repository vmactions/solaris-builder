#!/usr/bin/env bash

set -e


_conf="$1"

if [ -z "$_conf" ] ; then
  echo "Please give the conf file"
  exit 1
fi


. "$_conf"


##############################################################
osname="$VM_OS_NAME"
ostype="$VM_OS_TYPE"
sshport=$VM_SSH_PORT


opts="$VM_OPTS"

vboxlink="${SEC_VBOX:-$VM_VBOX_LINK}"


vmsh="$VM_VBOX"


export VM_OS_NAME
export VM_RELEASE
export VM_DISK


##############################################################


waitForText() {
  _text="$1"
  $vmsh waitForText $osname "$_text"
}

#keys splitted by ;
#eg:  enter
#eg:  down; enter
#eg:  down; up; tab; enter


inputKeys() {
  $vmsh input $osname "$1"
}



if [ ! -e "$vmsh" ] ; then
  echo "Downloading $vboxlink"
  wget -O "$vmsh" "$vboxlink"
fi

chmod +x "$vmsh"






$vmsh setup 

if ! $vmsh clearVM $osname; then
  echo "vm does not exists"
fi


$vmsh startWeb $osname



$vmsh createVM  $VM_ISO_LINK $osname $ostype $sshport


sleep 2


$vmsh  processOpts  $osname  "$opts"

echo "sleep 180 seconds. just wait"
sleep 180

$vmsh shutdownVM $osname

$vmsh destroyVM $osname

$vmsh startVM $osname




###############################################


waitForText "$VM_LOGIN_TAG"
sleep 2

inputKeys "string root; enter; sleep 1; string $VM_ROOT_PASSWORD ; enter"

sleep 2


if [ ! -e ~/.ssh/id_rsa ] ; then 
  ssh-keygen -f  ~/.ssh/id_rsa -q -N "" 
fi

echo "set -e" >enablessh.local
echo "mkdir -p ~/.ssh" >>enablessh.local
echo "touch ~/.ssh/authorized_keys" >>enablessh.local


#add ssh key twice, to avoid bugs.
echo "echo '$(base64 -w 0 ~/.ssh/id_rsa.pub)' | openssl base64 -d >>~/.ssh/authorized_keys" >>enablessh.local
echo "" >>enablessh.local

echo "echo '$(cat ~/.ssh/id_rsa.pub)' >>~/.ssh/authorized_keys" >>enablessh.local
echo "" >>enablessh.local


echo "chmod 600 ~/.ssh/authorized_keys"  >>enablessh.local

cat enablessh.txt >>enablessh.local


$vmsh inputFile $osname enablessh.local


###############################################################

$vmsh addSSHHost  $osname


ssh $osname sh <<EOF
echo 'StrictHostKeyChecking=accept-new' >.ssh/config

echo "Host host" >>.ssh/config
echo "     HostName  192.168.122.1" >>.ssh/config
echo "     User runner" >>.ssh/config
echo "     ServerAliveInterval 1" >>.ssh/config

EOF


if [ -e "hooks/postBuild.sh" ]; then
  ssh $osname sh<"hooks/postBuild.sh"
fi


ssh $osname 'cat ~/.ssh/id_rsa.pub' >$osname-$VM_RELEASE-id_rsa.pub


if [ "$VM_PRE_INSTALL_PKGS" ]; then
  echo "$VM_INSTALL_CMD $VM_PRE_INSTALL_PKGS"
  ssh $osname sh <<<"$VM_INSTALL_CMD $VM_PRE_INSTALL_PKGS"
fi

ssh $osname  "$VM_SHUTDOWN_CMD"

sleep 5

###############################################################

$vmsh shutdownVM $osname

while $vmsh isRunning $osname; do
  sleep 5
done

##############################################################




ova="$osname-$VM_RELEASE.qcow2"


echo "Exporting $ova"
$vmsh exportOVA $osname "$ova"

cp ~/.ssh/id_rsa  $osname-$VM_RELEASE-host.id_rsa


ls -lah





