#! /bin/bash

#Collecting all physical interfaces's name and mac addresse for centos7
declare -A NAME_TO_MAC
set -e
for f in /sys/class/net/*; do
  if [ -L $f ]; then
    name=`readlink $f`
    if echo $name | grep -v 'devices/virtual' > /dev/null; then
      eval $(ifconfig `basename $f` | head -n 1 | awk '{print "NAME_TO_MAC[\"",$1,"\"]=",$5}' | tr -d ' ')
    fi
  fi
done

function getRealMac()
{
  local ifname=$1
  local bond=$2
  local pattern="Slave Interface: $ifname"
  awk -v pattern="$pattern" '$0 ~ pattern, $0 ~ /^$/' $bond | awk '/Permanent HW addr/{print $4}' | tr -d ' '
}

#Trying to get the real mac when there's a bonding interface
for name in "${!NAME_TO_MAC[@]}";  do
  for bond in /proc/net/bonding/*; do
    if grep $name /sys/devices/virtual/net/`basename $bond`/bonding/slaves > /dev/null; then
      MAC=`getRealMac $name $bond`
      if ! [ -z $MAC ]; then
        NAME_TO_MAC["$name"]="$MAC"
      fi
    fi
  done
done

set +e

echo "System Physical Interfaces"
echo "=========================="
for k in ${!NAME_TO_MAC[@]}; do
   echo $k ${NAME_TO_MAC[$k]}
done

echo "=========================="