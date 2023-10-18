#!/bin/bash

# This script is the main script that should be continuosly run for each IP address.
# It handles everything, from starting up honeypot configurations on the IP address,
# recycling a container when the time is up, and running the data collection script
# at the appropriate times.
#
# main.sh will be run by cron every minute for each ip address
#
# As for our recycling policy:
# (1) the maximum amount of time before a honeypot is recycled is 30 minutes from when an
#     attacker first ssh's into the honeypot.
# (2) the amount of idle time before a honeypot is recycled is 5 minutes.
# (3) if an attacker logs in and then logs out of a honeypot, it will be recycled.

# checking to see if the number of arguments passed in (3) is correct
if [ $# -ne 2 ]
then
  echo "Usage: main.sh <external IP address> <external netmask prefix>"
  exit 1
fi

# initializing these three variables from the arguments passed into the script
ipaddress=$1
netmask=$2
container_run_time=30

# creates an mitm_logs directory if it doesn't exist yet
if [ ! -d /home/student/mitm_logs ]
then
    mkdir /home/student/mitm_logs
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

    # checks to see if attacker has not ssh'd into the honeypot yet
    if grep -q 'Opened shell' /home/student/mitm_logs/"$contname".log"$fileend"
    then
        # this block does nothing if the attacker has already ssh'd into the container
        if grep -q 'Attacker closed connection' /home/student/mitm_logs/"$contname".log"$fileend"
        then

            # removes the tracker document for the ip address
            rm /home/student/tracker"$ipaddress".txt

            # runs container.sh script to stop the running container on this ip address
            /bin/bash /home/student/container.sh "$contname" "$extip" "$netmask"

            # runs the data collection script as the container is being recycled
            /bin/bash /home/student/datacol.sh "$contname"

            exit 0

        fi
    else

        # maximum amount of time container can run in seconds (30 mins = 1800 secs)
        max_cont_time_in_secs=$(("$container_run_time"*60))

        # current time (using seconds after epoch)
        current_time=$(date +%s)

        # the end time of the container (using seconds after epoch)
        container_end_time=$(("$current_time" + "$max_cont_time_in_secs"))

        # these two lines reset the timer for the container, if there is no attacker activity
        rm /home/student/tracker"$ipaddress".txt

        echo "$container_end_time" "$contname" "$ipaddress" "$netmask" >> /home/student/tracker"$ipaddress".txt

        # exiting from the script in the case that the container is running but it's not yet time to recycle yet because an attacker
        # hasn't ssh'd into it
        exit 0

    fi

    # timestamp of attacker entry
    timestamp_of_attacker_entry=$(grep -m 1 'Opened shell' /home/student/mitm_logs/"$contname".log"$fileend" | cut -d' ' -f1-2)

    # time of attacker entry, in the form of seconds after epoch
    attacker_entry_in_seconds_after_epoch=$(date -d "$timestamp_of_attacker_entry" +%s)

    # maximum amount of time container can run in seconds (30 mins = 1800 secs)
    max_cont_time_in_secs=1800;

    # updating the end time of the container (using seconds after epoch)
    endsecs=$(("$attacker_entry_in_seconds_after_epoch" + "$max_cont_time_in_secs"))

    # represents the current time
    secsafterepoch=$(date +%s)

    # this extracts the timestamp of the last attacker command on the current MITM log
    last_line_timestamp=$(tail -n 1 /home/student/mitm_logs/"$contname".log"$fileend" | cut -d' ' -f1-2)

    # this is the timestamp of the last attacker command in the form of seconds after epoch
    last_attacker_activity=$(date -d "$last_line_timestamp" +%s)

    idle_time=$(("$secsafterepoch" - "$last_attacker_activity"))

    # case that it is time to recycle the container on the ip address, from either looking at 30 mins from when the attacker first
    # ssh's in or from when the attacker has been idle for more than five minutes
    if [ "$endsecs" -le "$secsafterepoch" ]
    then

    # removes the tracker document for the ip address
    rm /home/student/tracker"$ipaddress".txt

    # runs container.sh script to stop the running container on this ip address
    /bin/bash /home/student/container.sh "$contname" "$extip" "$netmask"

    # runs the data collection script as the container is being recycled
    /bin/bash /home/student/datacol.sh "$contname"

    exit 0

    elif [ "$idle_time" -ge 300 ]
    then

    # removes the tracker document for the ip address
    rm /home/student/tracker"$ipaddress".txt

    # runs container.sh script to stop the running container on this ip address
    /bin/bash /home/student/container.sh "$contname" "$extip" "$netmask"

    # runs the data collection script as the container is being recycled
    /bin/bash /home/student/datacol.sh "$contname"

    exit 0

    fi

    # exiting from the script in the case that the container is running but it's not yet time to recycle yet
    exit 0
fi

# everything below is intended to run if there is no container running on the ip address (so there is no tracker document for it)

# generates a random number between 1-3 (inclusive) to decide on which honeypot configuration will be next to run on this ip address
num=$(openssl rand -hex 1)
dec=$(printf "%d" "0x$num")
randnum=$((dec % 3 + 1))
cont="NONE_SELECTED_YET"

# if the random number is 1, then honeypot type 1 will run. This is the honeypot with 0% of its files being compressed
if [ "$randnum" -eq 1 ]
then
    # runs the container.sh script passing in container name, ip address, and netmask
    cont="cont0percent"
    cont+="$ipaddress"
    /bin/bash /home/student/container.sh "$cont" "$ipaddress" "$netmask"

# if the random number is 2, then honeypot type 2 will run. This is the honeypot with 50% of its files being compressed
elif [ "$randnum" -eq 2 ]
then
    # runs the container.sh script passing in container name, ip address, and netmask
    cont="cont50percent"
    cont+="$ipaddress"
    /bin/bash /home/student/container.sh "$cont" "$ipaddress" "$netmask"

    # goes through half of the "honey" files in the container, compressing them
    for i in {1..25};
    do
        sudo lxc-attach -n "$cont" -- gzip /confidential/passwords"$i".txt
    done

# if the random number is 3, then honeypot type 3 will run. This is the honeypot with 100% of its files being compressed
else
    # runs the container.sh script passing in container name, ip address, and netmask
    cont="cont100percent"
    cont+="$ipaddress"
    /bin/bash /home/student/container.sh "$cont" "$ipaddress" "$netmask"

    # goes through all of the "honey" files in the container, compressing them
    for i in {1..50};
    do
        sudo lxc-attach -n "$cont" -- gzip /confidential/passwords"$i".txt
    done
fi

# current time (using seconds after epoch)
current_time=$(date +%s)

# maximum amount of time container can run in seconds (30 mins = 1800 secs)
max_cont_time_in_secs=$(("$container_run_time"*60))

# the end time of the container (using seconds after epoch)
container_end_time=$(("$current_time" + "$max_cont_time_in_secs"))

# adding information about the container's end time, name, and respective ip address and netmask to the ip address's tracker file
echo "$container_end_time" "$cont" "$ipaddress" "$netmask" >> /home/student/tracker"$ipaddress".txt
