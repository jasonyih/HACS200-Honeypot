#!/bin/bash

contname1=$(head -1 /home/student/tracker128.8.238.193.txt | cut -d' ' -f2)
contname2=$(head -1 /home/student/tracker128.8.238.4.txt | cut -d' ' -f2)
contname3=$(head -1 /home/student/tracker128.8.238.43.txt | cut -d' ' -f2)
contname4=$(head -1 /home/student/tracker128.8.238.64.txt | cut -d' ' -f2)
contname5=$(head -1 /home/student/tracker128.8.238.100.txt | cut -d' ' -f2)

sudo lxc-destroy -n "$contname1"
sudo lxc-destroy -n "$contname2"
sudo lxc-destroy -n "$contname3"
sudo lxc-destroy -n "$contname4"
sudo lxc-destroy -n "$contname5"

sudo rm /home/student/tracker*

sudo /usr/sbin/sysctl -w net.ipv4.conf.all.route_localnet=1
sudo /usr/bin/npm install -g forever
