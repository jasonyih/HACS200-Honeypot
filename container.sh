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

fourthipfield=$(echo "$2" | cut -d'.' -f4)
customport=$(( fourthipfield + 50000 ))

contname=$1
sudo lxc-ls -f > /home/student/temp"$2"
# checks to see if the container already exists. If so, it is stopped and destroyed. If not, it is created and run
if grep -q "$1 " /home/student/temp"$2"
then

    # represent what is currently the most recent log number
    fileend=1

    # used in while loop to find last log number
    increment=2

    # loops through log files for the specific container, to find the last one whose number is assigned to fileend
    while [ -f /home/student/mitm_logs/"$contname".log"$increment" ]
    do
        fileend=$(( fileend + 1 ))
        increment=$(( increment + 1 ))
    done

    # the lines below are used to destroy the container and remove all the firewall rules to do with it
    ip=$(sudo lxc-ls -f | grep "$1 " | cut -d'-' -f2 | awk '{$1=$1};1')
    attacker_ip=$(grep "Attempts: 2" /home/student/mitm_logs/"$contname".log"$fileend" | cut -d' ' -f8 | cut -d',' -f1)
    regid=$(sudo forever list | grep "$1".log | cut -d' ' -f6)

    sudo forever stop "$regid"
    sudo /usr/sbin/iptables --wait --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$2" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:"$customport"
    sudo /usr/sbin/iptables --wait --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$2" --jump DNAT --to-destination "$ip"
    sudo /usr/sbin/iptables --wait --table nat --delete POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$2"
    sudo /usr/sbin/ip addr delete "$2"/"$3" brd + dev eth1

    sudo /usr/bin/flock /home/student/zlock1 /usr/sbin/iptables --wait --delete INPUT --source "$attacker_ip" --destination "$2" --jump ACCEPT
    sudo /usr/bin/flock /home/student/zlock2 /usr/sbin/iptables --wait --delete INPUT ! --source "$attacker_ip" --protocol tcp --dport "$customport" --jump DROP
    sudo lxc-stop -n "$1"
    sleep 5
    sudo lxc-destroy -n "$1"
    sleep 5

else
    # these lines create the new container as specified as the arguments to this script, set up the appropriate firewall rules, and
    # install an OpenSSH server on it.
    sudo lxc-create -n "$1" -t download -- -d ubuntu -r focal -a amd64
    sudo lxc-start -n "$1"

    contip=$(grep "$1 " /home/student/temp"$2" | cut -d'-' -f2 | sed 's/^[ \t]*//')

    while [ -z "$contip" ]
    do
      sleep 1
      sudo lxc-ls -f > /home/student/temp"$2"
      contip=$(grep "$1 " /home/student/temp"$2" | cut -d'-' -f2 | sed 's/^[ \t]*//')
    done

    sudo ip addr add "$2"/"$3" brd + dev eth1
    sudo ip link set dev eth1 up
    ip=$(sudo lxc-ls -f | grep "$1 " | cut -d'-' -f2 | awk '{$1=$1};1')
    sudo /usr/sbin/iptables --wait --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$2" --jump DNAT --to-destination "$ip"
    sudo /usr/sbin/iptables --wait --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$2"
    sudo /usr/sbin/iptables --wait --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$2" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:"$customport"
    sudo lxc-attach -n "$1" -- bash -c "sudo apt-get update && sudo apt-get install -y openssh-server"
    sudo cp /home/student/sshd_config /var/lib/lxc/"$contname"/rootfs/etc/ssh/sshd_config
    sudo lxc-attach -n "$1" -- bash -c "sudo systemctl restart ssh.service"
    # this line create a honey directory named "confidential" on the container
    sudo lxc-attach -n "$1" -- bash -c "mkdir /confidential"

        for i in {1..50};
        do
          sudo cp /home/student/HoneyFiles/file"$i".txt /var/lib/lxc/$contname/rootfs/confidential/passwords"$i".txt
        done

    # sets up forever
    #sudo /usr/sbin/sysctl -w net.ipv4.conf.all.route_localnet=1
    #sudo npm install -g forever

    # variable used to determine the last log for this container
    fileend=1

    # loop to assign the last log number for the container to fileend
    while [ -f /home/student/mitm_logs/"$1".log"$fileend" ]
    do
        fileend=$(( fileend + 1 ))
    done

    # sets up the MITM server for this container
    sudo forever -l /home/student/mitm_logs/"$1".log"$fileend" start /home/student/MITM/mitm.js -n "$1" -i "$ip" -p "$customport" --auto-access --auto-access-fixed 1 --debug
fi
