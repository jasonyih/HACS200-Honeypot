#!/bin/bash

# This script is used to set up or recycle the basic container with the honey files to be then compressed
# to varying degrees later by the main script. This script is called by the main script when it is time
# to either set up a container on the specified ip address or destroy it.

# checking to see if the number of arguments passed in (3) is correct
if [ $# -ne 3 ]
then
        echo "Usage: container.sh <container name> <external IP address> <external netmask prefix>"
        exit 1
fi

contname=$1

# checks to see if the container already exists. If so, it is stopped and destroyed. If not, it is created and run
if sudo lxc-ls | grep -q "$1 "
then
    # the lines below are used to destroy the container and remove all the firewall rules to do with it
    ip=$(sudo lxc-ls -f | grep "$1 " | cut -d'-' -f2 | awk '{$1=$1};1')

    # MAKE SPECIFIC FOR CONTAINER/IP
    sudo forever stop /home/student/MITM/mitm.js
    sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$2" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:3355
    sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$2" --jump DNAT --to-destination "$ip"
    sudo iptables --table nat --delete POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$2"
    sudo ip addr delete "$2"/"$3" brd + dev eth1
    sudo lxc-stop -n "$1"
    sleep 5
    sudo lxc-destroy -n "$1"
    sleep 5

else
    # these lines create the new container as specified as the arguments to this script, set up the appropriate firewall rules, and
    # install an OpenSSH server on it.
    sudo lxc-create -n "$1" -t download -- -d ubuntu -r focal -a amd64
    sudo lxc-start -n "$1"
    sleep 5
    sudo ip addr add "$2"/"$3" brd + dev eth1
    sudo ip link set dev eth1 up
    ip=$(sudo lxc-ls -f | grep "$1 " | cut -d'-' -f2 | awk '{$1=$1};1')
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$2" --jump DNAT --to-destination "$ip"
    sudo iptables --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$2"
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$2" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:3355
    sudo lxc-attach -n "$1" -- bash -c "sudo apt-get update && sudo apt-get install -y openssh-server"

    # this line create a honey directory named "confidential" on the container
    sudo lxc-attach -n "$1" -- bash -c "mkdir /confidential"

        for i in {1..50};
        do
          sudo mv /home/student/HoneyFiles/file"$i".txt /var/lib/lxc/$contname/rootfs/confidential/passwords"$i".txt
        done

    # sets up forever
    sudo sysctl -w net.ipv4.conf.all.route_localnet=1
    sudo npm install -g forever

    # variable used to determine the last log for this container
    fileend=1

    # loop to assign the last log number for the container to fileend
    while [ -f /home/student/mitm_logs/"$1".log"$fileend" ]
    do
        fileend=$(( fileend + 1 ))
    done

    # sets up the MITM server for this container
    sudo forever -l /home/student/mitm_logs/"$1".log"$fileend" start /home/student/MITM/mitm.js -n "$1" -i "$ip" -p 3355 --auto-access --auto-access-fixed 2 --debug
fi
