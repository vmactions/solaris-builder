#!/usr/bin/env bash

set -ex


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
export VM_OCR
export VM_DISK
export VM_ARCH


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



$vmsh startWeb $osname


$vmsh setup 

if ! $vmsh clearVM $osname; then
  echo "vm does not exists"
fi


if [ "$VM_ISO_LINK" ]; then
  $vmsh createVM  $VM_ISO_LINK $osname $ostype $sshport

  sleep 2

  if [ -e "hooks/installOpts.sh" ]; then
    echo "hooks/installOpts.sh"
    cat "hooks/installOpts.sh"
    . "hooks/installOpts.sh"
  else
    $vmsh  processOpts  $osname  "$opts"
  
    echo "sleep 60 seconds. just wait"
    sleep 60
  
    if $vmsh isRunning $osname; then
      if ! $vmsh shutdownVM $osname; then
        echo "shutdown error"
      fi
      if ! $vmsh destroyVM $osname; then
        echo "destroyVM error"
      fi
    fi
  fi

  while $vmsh isRunning $osname; do
    sleep 5
  done

elif [ "$VM_VHD_LINK" ]; then
  if [ ! -e "$osname.qcow2" ]; then
    if [ ! -e "$osname.qcow2.xz" ]; then
      $vmsh download "$VM_VHD_LINK" $osname.qcow2.xz
    fi
    xz -d -T 0 --verbose  "$osname.qcow2.xz"
  fi

  $vmsh createVMFromVHD $osname $ostype $sshport

  sleep 5

else
  echo "no VM_ISO_LINK or VM_VHD_LINK, can not build."
  exit 1
fi


echo "VM image size immediately after install:"
ls -lh ${osname}.qcow2



start_and_wait() {
  $vmsh startVM $osname
  sleep 2
  if [ -e "hooks/waitForLoginTag.sh" ]; then
    echo "hooks/waitForLoginTag.sh"
    cat "hooks/waitForLoginTag.sh"
    . "hooks/waitForLoginTag.sh"
  else
    waitForText "$VM_LOGIN_TAG"
  fi

  sleep 3
}

###############################################

start_and_wait


inputKeys "string root; enter; sleep 1;"
if [ "$VM_ROOT_PASSWORD" ]; then
  inputKeys "string $VM_ROOT_PASSWORD ; enter"
fi
inputKeys "enter"
sleep 2


if [ ! -e ~/.ssh/id_rsa ] ; then 
  ssh-keygen -f  ~/.ssh/id_rsa -q -N "" 
fi

cat enablessh.txt >enablessh.local


#add ssh key twice, to avoid bugs.
echo "echo '$(base64 -w 0 ~/.ssh/id_rsa.pub)' | openssl base64 -d >>~/.ssh/authorized_keys" >>enablessh.local
echo "" >>enablessh.local

echo "echo '$(cat ~/.ssh/id_rsa.pub)' >>~/.ssh/authorized_keys" >>enablessh.local
echo "" >>enablessh.local


echo >>enablessh.local
echo "chmod 600 ~/.ssh/authorized_keys">>enablessh.local
echo "exit">>enablessh.local
echo >>enablessh.local


$vmsh inputFile $osname enablessh.local


###############################################################

$vmsh addSSHHost  $osname


ssh $osname sh <<EOF
echo 'StrictHostKeyChecking=no' >.ssh/config

echo "Host host" >>.ssh/config
echo "     HostName  192.168.122.1" >>.ssh/config
echo "     User runner" >>.ssh/config
echo "     ServerAliveInterval 1" >>.ssh/config

EOF


###############################################################


ssh $osname 'cat ~/.ssh/id_rsa.pub' >$osname-$VM_RELEASE-id_rsa.pub

#upload reboot.sh
if [ -e "hooks/reboot.sh" ]; then
  echo "hooks/reboot.sh"
  cat "hooks/reboot.sh"
  scp hooks/reboot.sh $osname:/reboot.sh
else
  ssh "$osname" "cat - >/reboot.sh" <<EOF
sleep 5
ssh host sh <<END
env | grep SSH_CLIENT | cut -d = -f 2 | cut -d ' ' -f 1 >$osname.rebooted

END

EOF
fi


#set cronjob
ssh "$osname" sh <<EOF
chmod +x /reboot.sh
cat /reboot.sh
if uname -a | grep SunOS >/dev/null; then
crontab -l | {  cat;  echo "* * * * * /reboot.sh";   } | crontab --
else
crontab -l | {  cat;  echo "@reboot /reboot.sh";   } | crontab -
fi
crontab -l

EOF

# set zfs TRIM/discard support to try to reclaim space when large changes are
# made
ssh "$osname" sh <<EOF
echo "set zfs:zfs_unmap_ignore_size=0x10000" > /etc/system.d/zfs
echo "set zfs:zfs_log_unmap_ignore_size=0x10000" >> /etc/system.d/zfs
EOF

shutdown_and_wait() {
  ssh $osname  "$VM_SHUTDOWN_CMD"

  sleep 30

  if $vmsh isRunning $osname; then
    if ! $vmsh shutdownVM $osname; then
      echo "shutdown error"
    fi
  fi

  while $vmsh isRunning $osname; do
    sleep 5
  done
}

restart_and_wait() {
  shutdown_and_wait
  start_and_wait
}

# Need to restart VM before installing packages as the postBuild hook
# probably upgraded the OS snapshot so it needs to reboot.
restart_and_wait

if [ -e "hooks/postBuild.sh" ]; then
  echo "hooks/postBuild.sh"
  cat "hooks/postBuild.sh"
  ssh $osname sh<"hooks/postBuild.sh"
fi


# If a system upgrade was performed by the postBuild.sh, we need to restart and
# purge the old OS snapshot to free up space.
restart_and_wait

echo "Purging any stale OS snapshots..."
ssh "$osname" sh <<'EOF'
beadm list | tail +3 | while read -r line; do
  name=`echo $line | awk '{ print $1 };'`
  mountpoint=`echo $line | awk '{ print $3 };'`
  if [ "$mountpoint" = "-" ] ; then
    echo "Removing $name: beadm destroy -F $name"
    beadm destroy -F $name
  fi
done
EOF


# Install any requested packages
if [ "$VM_PRE_INSTALL_PKGS" ]; then
  echo "$VM_INSTALL_CMD $VM_PRE_INSTALL_PKGS"
  ssh $osname sh <<<"$VM_INSTALL_CMD $VM_PRE_INSTALL_PKGS"
fi


shutdown_and_wait


##############################################################

echo "Clean up ISO for more space"
sudo rm -f solaris.iso

echo "contents of home directory:"
ls -lah

echo "free space:"
df -h


ova="$osname-$VM_RELEASE.qcow2.xz"
# The exportOVA command doesn't try to compact the qcow2 file and also uses
# a lesser compression.
#$vmsh exportOVA $osname "$ova"

# compact the qcow2 file by exporting it
echo "Compacting ${osname}.qcow2, this will take a long time..."
sudo qemu-img convert -O qcow2 ${osname}.qcow2 ${osname}.qcow2.compact
sudo rm -f ${osname}.qcow2
sudo mv ${osname}.qcow2.compact ${osname}.qcow2
ls -lh ${osname}.qcow2

# Compress
echo "Compressing $ova, this will take a long time..."
sudo xz -z9 --stdout ${osname}.qcow2 > $ova

ova_size=`du -k ${ova} | cut -f 1`
if [ ${ova_size} -gt 2097152 ] ; then
  echo "OVA exceeds 2G, splitting in 2G chunks..."
  split -b 2G -d -a 1 "${ova}" "${ova}."
  rm -f "${ova}"
fi

cp ~/.ssh/id_rsa  $osname-$VM_RELEASE-host.id_rsa

echo "contents after export:"
ls -lah


##############################################################

echo "Checking the packages: $VM_RSYNC_PKG $VM_SSHFS_PKG"

if [ -z "$VM_RSYNC_PKG$VM_SSHFS_PKG" ]; then
  echo "skip"
else
  $vmsh addSSHAuthorizedKeys $osname-$VM_RELEASE-id_rsa.pub
  $vmsh startVM $osname
  $vmsh waitForVMReady $osname
  if [ "$VM_RSYNC_PKG" ]; then
    ssh $osname sh <<<"$VM_INSTALL_CMD $VM_RSYNC_PKG"
  fi
  if [ "$VM_SSHFS_PKG" ]; then
    ssh $osname sh <<<"$VM_INSTALL_CMD $VM_SSHFS_PKG"
  fi
fi


