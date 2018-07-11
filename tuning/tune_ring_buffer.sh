#! /bin/bash
#==============================================================================
#
#          FILE: tune_ring_buffer.sh
#   DESCRIPTION: Tune up receive (TX) and transmit (RX) buffers on network interface.
#       CREATED: 2018/07/11
#        AUTHOR: honglei
#==============================================================================

set -e

for f in /sys/class/net/*; do
  if [ -L $f ]; then
	name=`readlink $f`
	if echo $name | grep -v 'devices/virtual' | grep -v unused> /dev/null; then
	  nic=$(basename $f)
	  ethtool -G ${nic} rx 4096 tx 4096
	fi
  fi
done