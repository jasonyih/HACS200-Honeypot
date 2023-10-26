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

contname=$1
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
if [ ! -f /home/student/data/"$1"counter.txt ]
then
    touch /home/student/data/"$1"counter.txt
    echo "num_commands-time_attacking-average_length-ip" >> /home/student/data/"$1"counter.txt
fi
if ! grep -q 'Attacker closed connection' /home/student/mitm_logs/"$1".log"$fileend"
then
  exit 1
fi
# numcommands holds the number of commands that were executed in a particular session
num_interative=$(grep -c 'Noninteractive mode attacker command' /home/student/mitm_logs/"$1".log"$fileend")
numcommands=$(grep -c 'line from reader' /home/student/mitm_logs/"$1".log"$fileend")
total_commands=$(( $numcommands + $num_interative))
attacker_ip=$(grep "Attempts: 2" /home/student/mitm_logs/"$contname".log"$fileend" | cut -d' ' -f8 | cut -d',' -f1)
timestamp_of_attacker_entry=$(grep -m 1 'Compromising the honeypot' /home/student/mitm_logs/"$contname".log"$fileend" | cut -d' ' -f1-2)
attacker_entry_in_seconds_after_epoch=$(date -d "$timestamp_of_attacker_entry" +%s)
timestamp_of_attacker_exit=$(grep -m 1 'Attacker closed connection' /home/student/mitm_logs/"$contname".log"$fileend" | cut -d' ' -f1-2)
attacker_exit_in_seconds_after_epoch=$(date -d "$timestamp_of_attacker_exit" +%s)
time_spent_attacking=$(($attacker_exit_in_seconds_after_epoch - $attacker_entry_in_seconds_after_epoch))
file="/home/student/mitm_logs/$contname.log$fileend"
total=0
num_lines=0
while IFS= read -r line; do
    # Check if the line is a line where the attacker wrote commands
    if echo "$line" | grep -q "line from reader"; then
        num_chars=$(echo $line | cut -d':' -f4-)
        # one is subtracted because the lines start with a whitespace character
        total=$(($total + ${#num_chars} - 1))
        num_lines=$(($num_lines + 1))
    fi

    if echo "$line" | grep -q "Noninteractive mode attacker command:"; then
      num_chars=$(echo $line | cut -d':' -f4-)
      total=$(($total + ${#num_chars} - 1))
      num_lines=$(($num_lines + 1))
    fi
done < "$file"
average_length_of_commands=$(/usr/bin/bc -l <<< "$total/$num_lines")
# Information is added to the end of the respective counter file
filep=/home/student/mitm_logs/"$1".log"$fileend"

if [ $total_commands -eq 0 ]
then
  average_length_of_commands=0
fi

echo "$total_commands-$time_spent_attacking-$average_length_of_commands-$attacker_ip-$filep" >> /home/student/data/"$1"counter.txt
