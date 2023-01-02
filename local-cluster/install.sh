#!/bin/bash

yes | pacman -S avahi
yes | pacman -S	nss-mdns

echo "MulticastDNS=no" >> /etc/systemd/resolved.conf

systemctl restart systemd-resolved.service

systemctl enable avahi-daemon.service
systemctl start avahi-daemon.service
