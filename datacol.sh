#!/bin/bash

# This is the preliminary data collection script which extracts the dependent variables
# we are measuring from the respective MITM logs. As of now, it is just measuring
# the number of lines executed by attackers

# checks to see if the number of arguments is 1
if [ $# -ne 1 ]
then
    echo "Usage: datacol.sh <container name>"
    exit 1
fi

# these two variables are used to track the last MITM log file for the given IP address
fileend=1
increment=2

# loops through log files for the specific container, to find the last one whose number is assigned to fileend
while [ -f /home/student/mitm_logs/"$1".log"$increment" ]
do
    fileend=$(( fileend + 1 ))
    increment=$(( increment + 1 ))
done

# if the counter file for this ip address doesn't exist yet, it is created
if [ ! -f /home/student/mitm_logs/"$1"counter ]
then
    touch /home/student/mitm_logs/"$1"counter
fi

# numcommands holds the number of commands that were executed in a particular session
numcommands=$(grep -c 'line from reader' /home/student/mitm_logs/"$1".log"$fileend")

# numcommands is added to the end of the respective counter file
echo "$numcommands" >> /home/student/mitm_logs/"$1"counter