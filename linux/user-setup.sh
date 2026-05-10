#!/bin/bash

# Change root password
passwd

# Update software
apt update && apt upgrade -y && reboot

# Add new user with administrative rights
adduser user_name

# Confugiuer SSH
nano /etc/ssh/sshd_config