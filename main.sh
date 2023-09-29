#!/bin/bash

# This script should be run in cron.

# checking to see if the number of arguments passed in (3) is correct
if [ $# -ne 3 ]
then
  echo "Usage: main.sh <external IP address> <external netmask prefix> <number of minutes to run container>"
  exit 1
fi

# initializing these three variables from the arguments passed into the script
ipaddress=$1
netmask=$2
container_run_time=$3

# creates an mitm_logs directory if it doesn't exist yet
if [ ! -d /home/student/mitm_logs ]
then
  mkdir /home/student/mitm_logs
fi

# case that the tracker document for this ip address already exists, meaning that a container is presently running on the ip address
if [ -f /home/student/tracker"$ipaddress".txt ]
then

    # these four lines extract information from the tracker document about the running container on this ip address
    netmask=$(head -1 /home/student/tracker"$ipaddress".txt | cut -d' ' -f4)
    extip=$(head -1 /home/student/tracker"$ipaddress".txt | cut -d' ' -f3)
    contname=$(head -1 /home/student/tracker"$ipaddress".txt | cut -d' ' -f2)
    endsecs=$(head -1 /home/student/tracker"$ipaddress".txt | cut -d' ' -f1)

    # AAA
    secsafterepoch=$(date +%s)

    # case that it is time to recycle the container on the ip address
    if [ "$endsecs" -le "$secsafterepoch" ]
    then

    # removes the tracker document for the ip address
    rm /home/student/tracker"$ipaddress".txt

    # runs container.sh script to stop the running container on this ip address
    /home/student/container.sh "$contname" "$extip" "$netmask"

    # AAA
    /home/student/datacol.sh "$contname"

    # case that it is not yet time to recyle the container on the ip address
    else

    # informs user that container is not yet ready to be recycled
    echo "container is not ready to be recycled!"

  fi

    # exiting from the script
    exit 0
fi

# everything below is intended to run if there is no container running on the ip address (so there is no tracker document for it)

randnum=$(openssl rand -hex 1) ; dec=$(printf "%d" "0x$num") ; dec=$(($dec - 2)) ; mod=$(($dec % 3 + 1))

# 
if [ "$randnum" -eq 1 ]
then
    /home/student/container.sh compcontainer "$1" "$2"
    contname="compcontainer"

    sudo lxc-attach -n "$contname" -- bash -c "gzip /honey/honeyfile1.txt && gzip /honey/honeyfile2.txt && gzip /honey/honeyfile3.txt"
elif [ "$randnum" -eq 2]
then
    #FIX FOR 50%
    /home/student/container.sh uncompcontainer "$1" "$2"
    contname="uncompcontainer"
else
    
    /home/student/container.sh uncompcontainer "$1" "$2"
    contname="uncompcontainer"
fi

secondsafterepoch=$(date +%s)
endsecondsafterepoch=$(("$secondsafterepoch" + 60*"$3"))
echo "$endsecondsafterepoch" "$contname" "$1" "$2" >> /home/student/tracker.txt