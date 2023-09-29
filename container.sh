#!/bin/bash

# checking to see if the number of arguments passed in (3) is correct
if [ $# -ne 3 ]
then
        echo "Usage: container.sh <container name> <external IP address> <external netmask prefix>"
        exit 1
fi


if sudo lxc-ls | grep -q "$1 "
then


  ip=$(sudo lxc-ls -f | grep "$1 " | cut -d'-' -f2 | awk '{$1=$1};1')
  sudo forever stop /home/student/MITM/mitm.js
  sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$2" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:3355
  sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$2" --jump DNAT --to-destination "$ip"
  sudo iptables --table nat --delete POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$2"
  sudo ip addr delete "$2"/"$3" brd + dev eth1
  sudo lxc-stop -n "$1"
  sudo lxc-destroy -n "$1"

else

  sudo lxc-create -n "$1" -t download -- -d ubuntu -r focal -a amd64
  sudo lxc-start -n "$1"
  sleep 5

  sudo ip addr add "$2"/"$3" brd + dev eth1
  sudo ip link set dev eth1 up
  ip=$(sudo lxc-ls -f | grep "$1 " | cut -d'-' -f2 | awk '{$1=$1};1')

  sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$2" --jump DNAT --to-destination "$ip"
  sudo iptables --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$2"
  sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$2" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:3355

  sudo lxc-attach -n "$1" -- bash -c "sudo apt-get update && sudo apt-get install openssh-server"
  sudo lxc-attach -n "$1" -- bash -c "mkdir /honey && touch /honey/honeyfile1.txt && touch /honey/honeyfile2.txt && touch /honey/honeyfile3.txt && chmod 666 /honey/honeyfile1.txt && chmod 666 /honey/honeyfile2.txt && chmod 666 /honey/honeyfile3.txt"

  counter=1

  while [ "$counter" -le 100 ]
  do

    randvalue1=$(echo $RANDOM | md5sum | head -c 20; echo;)
    randvalue2=$(echo $RANDOM | md5sum | head -c 20; echo;)
    randvalue3=$(echo $RANDOM | md5sum | head -c 20; echo;)
    username="user""$counter"
    sudo lxc-attach -n "$1" -- bash -c "echo $username $randvalue1 >> /honey/honeyfile1.txt && echo $username $randvalue2 >> /honey/honeyfile2.txt && echo $username $randvalue3 >> /honey/honeyfile3.txt"
    counter=$(( counter + 1 ))

  done

  sudo sysctl -w net.ipv4.conf.all.route_localnet=1
  sudo npm install -g forever

  fileend=1

  while [ -f /home/student/mitm_logs/"$1".log"$fileend" ]
  do
    fileend=$(( fileend + 1 ))
  done

    sudo forever -l /home/student/mitm_logs/"$1".log"$fileend" start /home/student/MITM/mitm.js -n "$1" -i "$ip" -p 3355 --auto-access --auto-access-fixed 2 --debug
fi
