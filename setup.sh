#!/bin/sh
#-------------------------------------------------------
# This script will setup a virgin server
# as a webserver with following softwares
# - Apache WebServer
# - Mail Server (Optional)
# - Mail Transfer Agent (Optional)
# - MySQL database server (optional)
# - Joomla CMS or Joomla CMS with Gantry Framework
# - CSF Firewall + Additional Security Rules
# - Also sets-up LFD and a few monitoring systems
#
# Version : 0.01 | Date: 09 Dec 2013 | Owner: Akash
# -  Intital Version
#
#---------------------------------------------------------

# user defined function for logging
log () { echo "$1"; }

# Set Default Parameter Values
VERSION="0.01"
HAS_MAIL_SERVER=1
HAS_MTA=1
HAS_MYSQL=1
HAS_CMS=1
CMS_TYPE=1

LOG_FILE="./setup.log"
SSH_CONFIG_FILE="./ssh_test.sh"

# run the wizard first to get all the configuration information from user
# show a prompt
clear
echo "----------------------------------------------------------------------"
echo "                              /\\ /\\"
echo "                              \\/_\\/"
echo "                             ( o o )"
echo "                              \\ | /"
echo "                               ===" 
echo "                               / \\"
echo "----------------------------------------------------------------------"
echo " FLEETING BUNNY - Webhost configuration tool version $VERSION"
echo "----------------------------------------------------------------------"
echo "Press any key to continue..."
read input
clear
echo "Starting SSH configuration..."

# Values for following variables need to be setup
# Port __PORT__
# LoginGraceTime __GRACE_TIME__
# PermitRootLogin __PERMIT_ROOT__
# MaxAuthTries __MAX_AUTH_TRY__
# MaxSessions __MAX_SESSION_COUNT__
# PasswordAuthentication __PASS_AUTH__
# X11Forwarding __X11_FORWARD__
# ClientAliveInterval __CLIENT_ALIVE__
# Banner __BANNER__

echo "Default SSH Port is 22. We suggest you change it."
echo "Question 1: Which port would you like to run your SSH client [1024-65000]?"
read SSH_PORT
sed -i "s/__PORT__/$SSH_PORT/g" $SSH_CONFIG_FILE

echo "We disable remote root login with password by default"
sed -i "s/__PERMIT_ROOT__/without-password/g" $SSH_CONFIG_FILE

echo "We suggest you disable password authentication for other users as well."
echo "When you disable password, you will need key file to login"
echo "Question 2: Should we disable password authentication (yes / no)?"
read PASS_DISABLE
sed -i "s/__PASS_AUTH__/$PASS_DISABLE/g" $SSH_CONFIG_FILE

echo "We update following parameters of your SSH session with the below corresponding values"
echo "LoginGraceTime = 60 seconds (server disconnects if user has not logged-in successfully by this time)"
echo "MaxAuthTries   = 4 (maximum number of authentication attempts permitted per connection)"
echo "X11Forwarding  = yes (Specifies whether X11 forwarding is permitted)"

exit

# check if root, if not get out
if [ `whoami` != "root" ]; then
 echo "Run this program as root"
 exit -1
else 
 log "Initiating Setup script version: $VERSION as root"
fi

# Log current system state
log "uptime: `uptime`"
log "System Details: `uname -o -s -v`"

# update and upgrade the server
log "Performing yum update"
## yum -y update >/dev/null
if [ $? -eq 0 ]; then
 log "Update successful"
fi
log "Attempting to upgrade server"
## yum -y upgrade > /dev/null
if [ $? -eq 0 ]; then
 log "Upgrade Successful"
fi

# create a new staging folder to store prestine copy of products
## mkdir /home/setup

if [ $? -ne 0 ]; then
  echo "Failed to create setup directory under /"
  exit -1
else
  log "Created setup directory"
fi

# copy a list of softwares to setup directory
# TODO

# add a new user for ssh 


# securing the SSH server
log "Strengthening the security of the server..."
# SSH
# backup the current ssh config file
cp /etc/ssh/sshd_config /home/setup/
# change default port
## echo "Port 45690" >> /etc/ssh/sshd_config
log "... SSH default port changed to 45690"
# restart SSH
## service sshd restart
log "... SSH server restarted"
