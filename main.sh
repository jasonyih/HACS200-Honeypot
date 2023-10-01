#!/bin/bash

# This script is the main script that should be continuosly run for each IP address.
# It handles everything, from starting up honeypot configurations on the IP address,
# recycling a container when the time is up, and running the data collection script
# at the appropriate times. 

# As for our recycling policy:
# (1) the maximum amount of time before a honeypot is recycled is 30 minutes from when an
#     attacker first ssh's into the honeypot. 
# (2) the amount of idle time before a honeypot is recycled is 5 minutes.

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

# creates an mitm logs directory specifically for the specific ip address, if it doesn't exist yet
if [ ! -d /home/student/mitm_logs/logs_for_"$ipaddress"]
then
    mkdir /home/student/mitm_logs/logs_for_"$ipaddress"
fi


# considers the case that the tracker document for this ip address already exists, 
# meaning that a container is presently running on the ip address
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

    # exiting from the script in the case that the container is running but it's not yet time to recycle yet
    exit 0
fi

# everything below is intended to run if there is no container running on the ip address (so there is no tracker document for it)

# generates a random number between 1-3 (inclusive) to decide on which honeypot configuration will be next to run on this ip address
randnum=$(openssl rand -hex 1) ; dec=$(printf "%d" "0x$num") ; dec=$(($dec - 2)) ; mod=$(($dec % 3 + 1))

# if the random number is 1, then honeypot type 1 will run. This is the honeypot with 0% of its files being compressed
if [ "$randnum" -eq 1 ]
then

    /home/student/container.sh compcontainer "$1" "$2"
    contname="compcontainer"
    sudo lxc-attach -n "$contname" -- bash -c "gzip /honey/honeyfile1.txt && gzip /honey/honeyfile2.txt && gzip /honey/honeyfile3.txt"

# if the random number is 2, then honeypot type 2 will run. This is the honeypot with 50% of its files being compressed
elif [ "$randnum" -eq 2]
then
    #FIX FOR 50%
    /home/student/container.sh uncompcontainer "$1" "$2"
    contname="uncompcontainer"

# if the random number is 3, then honeypot type 3 will run. This is the honeypot with 100% of its files being compressed
else
    /home/student/container.sh uncompcontainer "$1" "$2"
    contname="uncompcontainer"
fi

# current time (using seconds after epoch)
current_time=$(date +%s)

# maximum amount of time container can run in seconds (30 mins = 1800 secs)
max_cont_time_in_secs=$(("$container_run_time"*60))

# the end time of the container (using seconds after epoch)
container_end_time=$(("$current_time" + "$max_cont_time_in_secs"))

# 
echo "$container_end_time" "$contname" "$1" "$2" >> /home/student/tracker"$ipaddress".txt