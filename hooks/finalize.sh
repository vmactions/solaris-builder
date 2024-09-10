echo "Purging any stale OS snapshots..."
beadm list | tail +3 | while read -r line; do
  name=`echo $line | awk '{ print $1 };'`
  mountpoint=`echo $line | awk '{ print $3 };'`
  if [ "$mountpoint" = "-" ] ; then
    echo "Removing $name: beadm destroy -F $name"
    beadm destroy -F $name
  fi
done
