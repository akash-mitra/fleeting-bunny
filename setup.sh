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

LOG_FILE="~/setup.log"


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



# securing the SSH server
log "Strengthening the security of the server..."
# SSH
# backup the current ssh config file
cp /etc/ssh/sshd_config /home/setup/
