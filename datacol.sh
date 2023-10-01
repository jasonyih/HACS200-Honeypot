#!/bin/bash

if [ $# -ne 1 ]
then
    echo "Usage: datacol.sh <container name>"
    exit 1
fi

fileend=1
increment=2

while [ -f /home/student/mitm_logs/"$1".log"$increment" ]
do
    fileend=$(( fileend + 1 ))
    increment=$(( increment + 1 ))
done

if [ ! -f /home/student/mitm_logs/"$1"counter ]
then
    touch /home/student/mitm_logs/"$1"counter
fi

numcommands=$(grep -c 'line from reader' /home/student/mitm_logs/"$1".log"$fileend")

echo "$numcommands" >> /home/student/mitm_logs/"$1"counter
