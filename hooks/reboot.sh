

if [ -e "/rebooted.txt" ]; then
  exit
fi

sleep 5
ssh host sh <<END
env | grep SSH_CLIENT | cut -d = -f 2 | cut -d ' ' -f 1 >solaris.rebooted

END

touch "/rebooted.txt" 



