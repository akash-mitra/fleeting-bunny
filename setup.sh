#!/usr/bin/env bash
#-------------------------------------------------------
# This script will setup a virgin server
# as a webserver with following softwares
# - Apache WebServer
# - Mail Server (Optional)
# - Mail Transfer Agent (Optional)
# - MySQL database server (optional)
# - Joomla CMS or Joomla CMS with Gantry Framework
# - Firewall + Additional Security Rules
# - Also sets-up LFD and a few monitoring systems
#
# Licensed under MIT
# Copyright (c) 2014 Akash R Mitra
# http://be-a-hacker.com
# 
#  Usage:
#  LOG_LEVEL=7 ./setup.sh [ini_file_name]
#
# Change History: 
# VER  | DATE        | COMMENT       
# -------------------------------------------------------------------------
# 0.01 | 09 Dec 2013 | Initial Draft Version
# 0.1  | 29 Dec 2013 | Beta - full AMP capability 
# 0.2  | 04 Jan 2014 | Using some parts from kvz.io Bash3 Boilerplate
# 0.4  | 06 Jan 2014 | Added basic firewall rules
#--------------------------------------------------------------------------

set -o pipefail

# Environment variables - setting default log level to info
[ -z "${LOG_LEVEL}" ] && LOG_LEVEL="6" # 7 = debug -> 0 = emergency

__DIR__="$(cd "$(dirname "${0}")"; echo $(pwd))"
__BASE__="$(basename "${0}")"
__FILE__="${__DIR__}/${__BASE__}"

# Logging functions based on type of messages
function critical ()  { [ "${LOG_LEVEL}" -ge 2 ] && log "FATAL ERROR: $1" || true; }
function error ()     { [ "${LOG_LEVEL}" -ge 3 ] && log "ERROR: $1" || true; }
function warning ()   { [ "${LOG_LEVEL}" -ge 4 ] && log "WARNING: $1" || true; }
function info ()      { [ "${LOG_LEVEL}" -ge 6 ] && log "$1" || true; }
function debug ()     { [ "${LOG_LEVEL}" -ge 7 ] && log "DEBUG: $1" || true; }

# To show a friendly help message
function help () {
  echo ""
  echo " ${@}"
  echo ""
  echo "Usage: $0 [ini_file_location]"
  echo "     ini_file_location (Optional) - Full file path of fleeting bunny config file"
  echo "     This can be either a local file or a remote file over HTTP"
  echo "     For a list of supported configuration directives, please check README.txt"
  exit 1
}

function cleanup_before_exit () {
	rm -f ./input.ini*
	rm -f ./profile.sh*
	rm -f ./sshd-config*
	rm -f ./virtual_template.sh*
	rm -f ./php-ini.php*
	info "Cleaning up. Done"
}
trap cleanup_before_exit EXIT

# user defined function for logging
function log () { echo "`hostname` | `date '+%F | %H:%M:%S |'` $1"; }

# this function returns configuration value for a given parameter
function getConfigValue () {
        local __ret__=$(grep "$1" $FLEET_BUNN_CONFIG | cut -d'=' -f2)
        echo ${__ret__}
}

# Set Default Parameter Values
VERSION="0.4"
MYSQL_CONFIG_LOC="/etc/my.cnf"
INSTALL_FOLDER="/home/setup/"
LOG_FILE="./setup.log"
FLEET_BUNN_CONFIG="./input.ini"
SSH_CONFIG_FILE="./sshd-config"

# check if root, if not get out
if [ `id -u` != "0" ]; then
	help "Run this ${__FILE__} as root"
 	exit -1
else
	info "Initiating Setup script version: $VERSION as root"
fi

# check and download wget
# I prefer to use wget over curl as wget can be typed in using only left hand in QWERTY keyboard ;-)
rpm -q wget > /dev/null
if [ $? -ne 0 ]; then
        debug "Installing wget"
        yum -y install wget > /dev/null
        info "wget installation done"
fi

# show a front screen 
clear
echo "----------------------------------------------------------------------"
echo "                      (\\_          _/)"
echo "                      )  (        )  ("
echo "                     (    (      )    )"
echo "                      )_(\\ \\.--./ /)_("
echo "                        \`)\` 6  6 '('"
echo "                         /        \\"
echo "                         (   []   )"
echo "                         \`(_c__c_)\`"
echo "                            \`--\`"
echo "----------------------------------------------------------------------"
echo " FLEETING BUNNY - Webhost configuration tool version $VERSION"
echo "----------------------------------------------------------------------"
echo ""

# check if fleeting bunny configuration file is provided as command line argument
# This can be any local or remote file (over HTTP). If the file is provided and
# the same is valid, we enter automatic mode, else we enter interactive mode

if [ $# -ne 1 ]; then 
	warning "Fleeting Bunny configuration file not available as command line argument"
	echo "# Blank Fleeting Bunny Configuration File - AUTO CREATED" > $FLEET_BUNN_CONFIG
else
	# check if the file is a remote file that needs to be downloaded
	if [ "${1:0:7}" == "http://" ] || [ "${1:0:8}" == "https://" ]; then
		debug "Detected remote file specified for config. Trying to download..."
		wget --quiet --tries=3 --output-document=input.ini "$1" 2>&1 1> /dev/null
		if [ $? -eq 0 ]; then
			info "Successfully downloaded the config file"
		else
			error "Failed to download [${1}]"
			exit -1
		fi
	else
		if [ ! -f "$1" ]; then
			error "Config file [${1}] does not exist"
			exit -1
		else
			debug "Renaming the specified config file as [input.ini]"
			chmod +w "$1" && mv "$1" "input.ini"	
		fi 
	fi # end of remote file download
fi
 
# Log current system state
info "System Details: `uname -a`"
info "IP address is : `ifconfig eth0 | grep "inet " | cut -d':' -f2 | cut -d' ' -f1`"


# perform a quick server benchmarking to take note of various 
# server parameters such as CPU, RAM, I/O speed etc

info "Attempt to perform server benchmarking..."
wget --quiet --tries=3 --output-document=profile.sh https://raw.github.com/akash-mitra/fleeting-bunny/master/utility/profile.sh
if [ $? -eq 0 ]; then
	bash profile.sh
else
	warning "Failed to download Profile.sh. Possible connection issue"
fi

# update and upgrade the server
info "Performing yum update"
yum -y update >/dev/null
if [ $? -eq 0 ]; then
info "Update successful"
fi
info "Attempting to upgrade server"
yum -y upgrade > /dev/null
if [ $? -eq 0 ]; then
info "Upgrade Successful"
fi

# create a new staging folder to store prestine copy of products
log "Creating setup directory"
if [ -d $INSTALL_FOLDER ]; then
	warning "Fleeting Bunny Install directory already exists"
else
	 mkdir $INSTALL_FOLDER
fi

if [ $? -ne 0 ]; then
  critical "Failed to create setup directory under /"
  exit -1
fi

# copy a list of softwares to setup directory
# TODO


# download templates for different server config files
rm -f sshd_template.sh
debug "Downloading SSH template..."
wget --quiet --tries=3 --output-document=sshd-config https://raw.github.com/akash-mitra/fleeting-bunny/master/templates/sshd-config 2>&1 1> /dev/null


#--------------------------------------------------------
# securing the SSH server
#--------------------------------------------------------
info "Strengthening the security of the SSH server..."
# SSH
# backup the current ssh config file
cp /etc/ssh/sshd_config $INSTALL_FOLDER
debug "Backed up sshd_config under $INSTALL_FOLDER"

# We begin by changing the default configuration of the SSH server
# By default SSH listens to Port 22 and allows password based
# authentication. This allows attacker to brute-force the credentials
# by trying random passwords to obtain SSH access. On the contrary,
# by using Public/Private keys for authentication, we can ensure that
# only holder of the encrypted key can get access to the system.
# 
# Values of some other SSH config parameters are also changed.
# - Port 
# - LoginGraceTime 
# - PermitRootLogin 
# - MaxAuthTries 
# - MaxSessions 
# - PasswordAuthentication 
# - X11Forwarding 
# - ClientAliveInterval 
# - Banner 

SSH_PORT=$(grep SSH_PORT $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$SSH_PORT" == "" ]; then
	warning "SSH port info not available in config file. Will prompt user"
	echo "Default SSH Port is 22. We suggest you change it."
	echo "Question 1: Which port would you like to run your SSH client [1024-65000]?"
	read SSH_PORT
fi
sed -i "s/__PORT__/$SSH_PORT/g" $SSH_CONFIG_FILE
info "SSH Port to be set to [$SSH_PORT]"

PASS_DISABLE=$(grep PASS_DISABLE $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$PASS_DISABLE" == "" ]; then
	warning "SSH Password Auth info not available in config file. Will prompt user"
	echo "We suggest you disable password authentication for other users as well."
	echo "When you disable password, you will need key file to login"
	echo "Question 2: Should we keep password authentication (yes / no)?"
	read PASS_DISABLE
fi
sed -i "s/__PASS_AUTH__/$PASS_DISABLE/g" $SSH_CONFIG_FILE
debug "Password based login to be disabled to other users as well"

GRACE_TIME=$(grep GRACE_TIME $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$GRACE_TIME" == "" ]; then
	warning "LoginGraceTime is not available in config file. Will be defaulted to 60 seconds"
	GRACE_TIME=60
else 
	info "LoginGraceTime will be set to $GRACE_TIME as per config file"
fi
sed -i "s/__GRACE_TIME__/$GRACE_TIME/g" $SSH_CONFIG_FILE

info "Root login to be permitted to the server"
sed -i "s/__PERMIT_ROOT__/yes/g" $SSH_CONFIG_FILE


MAX_AUTH_TRY=$(grep MAX_AUTH_TRY $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$MAX_AUTH_TRY" == "" ]; then
	warning "MaxAuthTries is not available in config file. Will be defaulted to 4"
	MAX_AUTH_TRY=4
else 
	info "MaxAuthTries will be set to $MAX_AUTH_TRY as per config file"
fi
sed -i "s/__MAX_AUTH_TRY__/$MAX_AUTH_TRY/g" $SSH_CONFIG_FILE

debug "Max session count to be set to 6" 
sed -i "s/__MAX_SESSION_COUNT__/6/g" $SSH_CONFIG_FILE

debug "X11Forwarding is to be set to 'yes' (Specifies whether X11 forwarding is permitted)"
sed -i "s/__X11_FORWARD__/yes/g" $SSH_CONFIG_FILE

debug "ClientAliveInterval to be set to 120 sec. (This will give you 6 minutes of inactivity time)"
sed -i "s/__CLIENT_ALIVE__/120/g" $SSH_CONFIG_FILE

BANNER_TEXT="This is a restricted system. Only explicitely authorized personnel are allowed to login"
echo $BANNER_TEXT > /etc/ssh/banner.text
info "Banner text is to be set"
sed -i "s~__BANNER__~/etc/ssh/banner.text~g" $SSH_CONFIG_FILE

info "Replacing original SSHD_Config with the newly prepared one..."
cp $SSH_CONFIG_FILE /etc/ssh/sshd_config

# restart SSH
debug "Attempting to restart SSH server..."
service sshd restart

if [ $? -eq 0 ]; then
	info "SSH server restarted"
else

	# ssh config change failed. Rollback the changes
	# replace the previously backed up sshd_config
	error "SSHD failed to restart. Attempting rollback" 
	info "In case rollback fails and we lose ssh access, please use VNC Terminal"
	cp $INSTALL_FOLDER/sshd_config /etc/ssh/
	# attempt to restart the server once again
	service sshd restart
	# abort the mission
	exit -1
fi
info "SSH Server is updated. SSH port set to $SSH_PORT. Remember to login using keyfile next time!"

#--------------------------------------------------------
#        INSTALLING WEB SERVER
#--------------------------------------------------------
# Apache webserver installation starts
# we will use yum command. To avoid interaction, we will use -y consenting switch
# If apache is already present, this command will do nothing

debug "Starting to install Apache webserver..."
yum -y install httpd 
if [ $? -eq 0 ]; then
 info "Apache installed"
else
 critical "Apache installation failed"
 exit -1 
fi


# In this step, we will try to determine our primary website name from
# fleeting bunny configuration file. In case, we fail to determine this
# we will prompt the user for input

debug "Trying to determine primary website name"
SITENAME=$(grep SITENAME $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$SITENAME" == "" ]; then
	warning "Primary site name not found in fleeting bunny config. Prompting for input"
	echo "In the following step we configure Apache Webserver as a virtual host"
	echo "Please specify your primary website name (e.g. example.com):"
	read SITENAME
fi
info "Primary site name determined as $SITENAME"

# In this step, we will create the directory structure required to store our websites
# we will also grant necessary permissions to apache user
# If any given website found to be existing, we will prompt user for overwrite

info "Creating document root"
if [ -d "/var/www/$SITENAME" ]; then
	warning "web directory [/var/www/${SITENAME}] already exists"
	SILENT_OVERWRITE=$(getConfigValue "SILENT_OVERWRITE")
	if [ "$SILENT_OVERWRITE" -eq "1" ] || [ "$SILENT_OVERWRITE" == "y" ] || [ "$SILENT_OVERWRITE" == "Y" ] || [ "$SILENT_OVERWRITE" == "yes" ]; then
		ANSWER="y"
	else
		echo "The directory already exists. Overwrite it? (y/n)"
		read ANSWER;
	fi
	if [ "$ANSWER" == "y" ]; then
		info "Specified directory exists, removing the same"
		rm -rf /var/www/$SITENAME
	else 
		critical "Exiting the process as the directory already exists"
		exit -1
	fi
fi
WEB_ROOT="/var/www/$SITENAME/public_html"
mkdir -p $WEB_ROOT
if [ $? -ne 0 ]; then
 critical "Could not create directory $WEB_ROOT" 
 exit -1 
fi
log "Creating other directories for logging, backup etc."
mkdir -p /var/www/$SITENAME/log
mkdir -p /var/www/$SITENAME/backup

log "Granting ownership of web directories to www user"
chown -R apache:apache $WEB_ROOT
if [ $? -ne 0 ]; then
 critical "chown failed to change permission" 
 exit -1 
fi
log "Granting ownership of log directories to www user"
chown -R apache:apache /var/www/$SITENAME/log

log "Granting world-read permission to web directory"
chmod 755 $WEB_ROOT

log "Revoking world read permission from log and backup directory"
chmod 750 /var/www/$SITENAME/log
chmod 700 /var/www/$SITENAME/backup

# Apache Configuration
# ---------------------------------------------------------------------------------------
# Now that Apache web server is installed and running, and directory structures
# are created, we will start configuring the server. This includes setting up 
# ports, host details (that is the website details), and some security and performance
# configurations.

info "Starting Apache Configuration.."

# The apache configuration is stored typically in httpd.conf file. The location of
# this configuration file can be varied depending on the system. In the following
# section, we will try to determine this location. One way to determine this location
# is to qyery the apache binary itself. Apache binary (httpd) when queries with -V 
# switch, shows many information and server configuration file location is one of them.
# (For more please refer to httpd man pages)
# To do this, however, we will need to first determine the apache binary location

debug "Determine httpd binary location.."
APACHE_LOC=$(whereis -b httpd | cut -d' ' -f2)
debug "httpd located at $APACHE_LOC"
debug "Querying apache bin to determine Apache root location"
APACHE_ROOT_LOC=$($APACHE_LOC -V | grep HTTPD_ROOT | cut -d'"' -f2)
debug "Querying apache bin to determine Apache conf file location"
APACHE_CONFIG_LOC=$($APACHE_LOC -V | grep SERVER_CONFIG_FILE | cut -d'"' -f2)
APACHE_CONFIG_LOC="${APACHE_ROOT_LOC}/${APACHE_CONFIG_LOC}"
info "Apache Config file is determined to be located at $APACHE_CONFIG_LOC"

# Now, before we start making any modification to the apache config file,
# it is good idea to take a backup of this file. If anything goes wrong, we can rollback

debug "Backing up config file"
cp $APACHE_CONFIG_LOC $INSTALL_FOLDER
if [ $? -ne 0 ]; then
	critical "Failed to backup Apache Config. Exiting"
	exit -1
fi

# From this point on, we start making the actual modifications in apache config.
# Apache config is largely divided in 3 sections. 
# - The 1st section deals with Apache server process as a whole.
# - The 2nd section define the parameters of the 'main' or 'default' server
# - The 3rd section contains all the settings for virtual hosts
# (For details, please read 
# http://www.techrepublic.com/article/learn-how-to-configure-apache/ )
# 
# The apache config file is mainly written as key-value pairs. The key is called 
# directive and the value of the key is specified after one (or more) blank space.
# For example, in the following line, "Listen" is a directive and "8080" is the value
# Listen 8080  
#
# The technique that we are using below to modify / change directive values is 
# a line-editor in-place replacement. We are using 'sed' as a line editing tool.
# sed -i 's/find/replace/' configfile
# A command like above will read the file "configfile" and replace the string "find"
# with the string "replace"
#

# Configuring Apache Server Port
# This is the port where apache server will be listening for incoming connections
# As always, we first search in Fleeting Bunny config, if not available, we prompt user

APACHE_PORT=$(grep APACHE_PORT $FLEET_BUNN_CONFIG | cut -d'=' -f2)
SECURE_APACHE_PORT=443  # TODO
if [ "$APACHE_PORT" == "" ]; then
	debug "Apache Port value missing in config file. Prompting for user input"
	echo "By Default webservers execute at port 80. You may want to change this"
	echo "Please enter new port number. Just enter to retain default value"
	read APACHE_PORT
	if [ "$APACHE_PORT" == "" ]; then
		APACHE_PORT="80"
	fi
fi
info "Setting Listener port to $APACHE_PORT"
sed -i "s/^Listen .*/Listen $APACHE_PORT/" $APACHE_CONFIG_LOC
if [ $? -ne 0 ]; then
	critical "Failed to modify PORT in Apache Config. Exiting"
	exit -1
fi

# setting up server as Virtual Host
# Virtual Host setting is generally available in the 3rd section of Apache Config
# We are setting the server as virtual host as in the future we might want to host
# multiple websites from the same server

info "Setting up virtual host"
sed -i "s/^#NameVirtualHost .*/NameVirtualHost *:${APACHE_PORT}/" $APACHE_CONFIG_LOC
if [ $? -ne 0 ]; then
	critical "Failed to uncomment NameVirtualHost in Apache Config. Exiting"
	error -1
fi

log "Downloading the virtual host configuration template..."
wget --quiet --tries=3 --output-document=virtual_template.sh https://raw.github.com/akash-mitra/fleeting-bunny/master/templates/apache-vhost
if [ $? -ne 0 ]; then
	debug "Failed to download virtual host template. Using default configuration"
	
	echo "# Following lines are added by Fleeting Bunny" > virtual_template.sh
	echo "# This is a static configuration!" >> virtual_template.sh
	echo "<VirtualHost *:${APACHE_PORT}>" >> virtual_template.sh
    echo "ServerAdmin __SERVER_ADMIN__" >> virtual_template.sh
    echo "DocumentRoot __DOCUMENT_ROOT__" >> virtual_template.sh
    echo "ServerName __SERVER_NAME__" >> virtual_template.sh
    echo "ErrorLog __ERROR_LOG__" >> virtual_template.sh
    echo "CustomLog __CUSTOM_LOG__ combined" >> virtual_template.sh
	echo "</VirtualHost>" >> virtual_template.sh
fi

# Following are some mandatory configuration that we must do in order to setup
# virtual hosting environment under Apache. If we are unable to setup any of these
# values, we exit. At the end of setting up these values in template, we push the
# template to actual config file.

log "Setting up mandatory configuration values in template"
sed -i "s/__APACHE_PORT__/${APACHE_PORT}/" virtual_template.sh
if [ $? -ne 0 ]; then
	critical "Failed to setup virtual server port. Exiting"
	exit -1
fi
sed -i "s/__SERVER_ADMIN__/webmaster@${SITENAME}/" virtual_template.sh
if [ $? -ne 0 ]; then
	critical "Failed to setup server admin. Exiting"
	exit -1
fi
sed -i "s~__DOCUMENT_ROOT__~/var/www/$SITENAME/public_html~" virtual_template.sh
if [ $? -ne 0 ]; then
	critical "Failed to setup document root. Exiting"
	exit -1
fi
sed -i "s/__SERVER_NAME__/www.$SITENAME/" virtual_template.sh
if [ $? -ne 0 ]; then
	critical "Failed to setup server name. Exiting"
	exit -1
fi
sed -i "s~__ERROR_LOG__~/var/www/$SITENAME/log/error~" virtual_template.sh
if [ $? -ne 0 ]; then
	critical "Failed to setup error log. Exiting"
	exit -1
fi
sed -i "s~__CUSTOM_LOG__~/var/www/$SITENAME/log/access~" virtual_template.sh
if [ $? -ne 0 ]; then
	critical "Failed to setup access log. Exiting"
	exit -1
fi
debug "adding the configured virtual host to apache config"
cat virtual_template.sh >> $APACHE_CONFIG_LOC


# At this point, we have successfully setup all the necessary values for virtual 
# server. We will restart apache to check if everything is alright.
# In case of failure, we will rollback the changes

debug "stopping all apache processes"
apachectl -k stop
debug "starting apache again..."
/etc/init.d/httpd start
if [ $? -ne 0 ]; then
    error "Apache failed to restart. Attempting to re-instate server config"
    cp $APACHE_CONFIG_LOC $INSTALL_FOLDER/httpd.conf.debug
    cp $INSTALL_FOLDER/httpd.conf $APACHE_CONFIG_LOC
    log "A copy of current apache conf is stored in $INSTALL_FOLDER for debug purpose"
	log "Attempting restart again"
	/etc/init.d/httpd start
	exit -1
else
	info "Apache server restarted successfully with virtual hosting environment"
	cp $APACHE_CONFIG_LOC $INSTALL_FOLDER/httpd.conf.custom
	
	log "Adding entry in chkconfig so that apache run automatically when the server boots"
	sudo chkconfig httpd on
fi

# Now that Apache is restarted, we will put a small file in the 
# server root so that we can test the webserver by pointing browser here

echo "<html><head><title>Fleeting Bunny - Apache with virtual host</title></head><body>" > ${WEB_ROOT}/index.html
echo "<h1>Fleeting Bunny</h1><hr />Hostname: `hostname`</body></html>" >> ${WEB_ROOT}/index.html

# Apache Fine Tuning
# In the following section, we will perform a few fine tuning of Apache 
# web server that may be useful for performance or security reasons.
# Whether or not to perform this step, can be controlled by setting
# FINE_TUNE_APACHE directive to 0 in FLEET BUNN config file

FINE_TUNE_APACHE=$(grep FINE_TUNE_APACHE $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$FINE_TUNE_APACHE" != "0" ]; then
	info "Fine Tuning Apache Web server..."
	
	# Hide Apache Server Signature
	debug "Switching off Server Signature"
	sed -i 's/^ServerSignature .*/ServerSignature Off/' $APACHE_CONFIG_LOC
	if [ $? -ne 0 ]; then
		warning "Failed to change Apache directive: ServerSignature"
	fi
	
	# Change ServerToken 
	debug "Switching off Server Token"
	sed -i 's/^ServerTokens .*/ServerTokens ProductOnly/' $APACHE_CONFIG_LOC
	if [ $? -ne 0 ]; then
		warning "Failed to change Apache directive: ServerToken"
	fi
	
	# TODO: server pool size regulation optimization 
fi

log "Apache optimization done. Restarting"
apachectl -k stop
/etc/init.d/httpd start
if [ $? -ne 0 ]; then
	warning "Could not restart Apache after optimization. Rolling back to previous state"
	cp $APACHE_CONFIG_LOC $INSTALL_FOLDER/httpd.conf.debug
	cp $INSTALL_FOLDER/httpd.conf.custom $APACHE_CONFIG_LOC
	info "Rollback complete"
	debug "A copy of current apache conf is stored in $INSTALL_FOLDER for debug purpose"
	debug "Attempting restart again"
	/etc/init.d/httpd start
	if [ $? -ne 0 ]; then
		error "Recurrent error. Exiting"
		exit -1
	fi
fi
info "Apache restarted successfully"
APACHE_INSTALLED=1

#--------------------------------------------------------
#        INSTALL PHP
#--------------------------------------------------------

debug "Checking directive for PHP installation"
INSTALL_PHP=$(grep INSTALL_PHP $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$INSTALL_PHP" == "" ]; then
	info "No explicit directive about PHP installation in config file. Will prompt"
	echo "Do you want to install PHP? (y / N)"
	read INSTALL_PHP
fi
if [ "$INSTALL_PHP" == "1" ] || [ "$INSTALL_PHP" == "y" ] || [ "$INSTALL_PHP" == "Y" ]; then
	debug "starting PHP installation"
	yum -y install php php-mysql > /dev/null
	if [ $? -ne 0 ]; then
		critical "Failed to install PHP or PHP-MYSQL"
		exit -1
	else
		info "`php --version | head -1` installed successfully" 
		PHP_INSTALLED=1
	fi
	
	# TODO: PHP Hardening:
	# Many of PHP's inherent security issues can be resolved by using 3rd
	# party packages such as Suhosin that can potentially harden the php 
	# installation from attacks from hackers etc. Suhosin implements a few 
	# low-level protections against bufferoverflows or format string vulnerabilities
	# along with other protections. To know more about suhosin, visit:
	# http://www.hardened-php.net/suhosin/a_feature_list.html
	# 
	# Installing suhosin is as easy as below:
	# yum install php-suhosin
	# 
	# However considering the possibility of any compatibility issues with Joomla
	# I defer Suhosin installation code until 2.0 stable release of fleeting-bunny
	
	
	# Once the PHP is installed in the above step, we will check if we need to 
	# install other PHP modules / modify anything for the proposed content
	# management system. For example, CMS like Joomla or WordPress may require 
	# certain other PHP module or certain changes in php.ini
	
	debug "Determining the location of php.ini file from php_ini_loaded_file()"
	debug "Downloading php-ini"
	wget --quiet --tries=3 --output-document=php-ini.php https://raw.github.com/akash-mitra/fleeting-bunny/master/utility/php-ini 2>&1 1> /dev/null
	if [ $? -eq 0 ]; then
		PHP_CONFIG_LOC=`php php-ini.php`
	else
		warning "Failed to download php-ini.php. Possible connection issue"
		debug "Checking php.ini in the default location"
		PHP_CONFIG_LOC="/etc/php.ini"
	fi
	debug "php.ini located at $PHP_CONFIG_LOC"
	
	
	# configuring PHP memory limit
	# we do not change the default memory limit (128MB) until and unless a 
	# override value is provided in fleeting bunny config
	
	PHP_MEMORY_LIMIT=$(grep PHP_MEMORY_LIMIT $FLEET_BUNN_CONFIG | cut -d'=' -f2)
	if [ "$PHP_MEMORY_LIMIT" == "" ]; then
		debug "No PHP memory limit override found. Default value will be retained"
	else
		sed -i "s~^memory_limit .*$~memory_limit = ${PHP_MEMORY_LIMIT}~" $PHP_CONFIG_LOC
		if [ $? -eq 0 ]; then
			info "PHP memory limit is to be set to [${PHP_MEMORY_LIMIT}]"
		else
			error "Error changing PHP memory limit to [${PHP_MEMORY_LIMIT}]"
		fi
	fi
	
	# TODO: change the php error_log location to site specific log folder?
	# This can be easily done by changing the "error_log" switch in PHP's
	# php.ini file. Need to think if this is to be done 
	
	# we will check the default CMS to be installed, and configure PHP accordingly
	
	CMS=$(grep CMS $FLEET_BUNN_CONFIG | cut -d'=' -f2)
	if [ "$CMS" == "joomla" ] || [ "$CMS" == "Joomla" ] || [ "$CMS" == "JOOMLA" ]; then
		info "Joomla is scheduled to be installed as CMS. Checking additional PHP packages for Joomla"
		
		# Magic Quote GPC changes
		# TODO
	fi
	
else
	warning "Skipping PHP Installation"
fi


# --------------------------------------------------------
#       INSTALL MySQL
# --------------------------------------------------------

debug "Checking directive for MySQL database installation"
INSTALL_MYSQL=$(grep INSTALL_MYSQL $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$INSTALL_MYSQL" == "" ]; then
	debug "No explicit directive about MySQL installation in config file. Will prompt"
	echo "Do you want to install MySQL database? (y / N)"
	read INSTALL_MYSQL
fi
if [ "$INSTALL_MYSQL" == "1" ] || [ "$INSTALL_MYSQL" == "y" ] || [ "$INSTALL_MYSQL" == "Y" ]; then
	debug "Starting MySQL database installation"
	
	# The Database can be installed in the same machine or in some other machine
	# Depending on the value of the parameter LOCAL_DATABASE, installation location
	# may vary. If LOCAL_DATABASE is set to 0, the database will be installed in
	# a separate machine (TODO). For all the other values of this parameter (including
	# the cases where this parameter is not set, the database will be installed on the
	# local machine.
	
	LOCAL_DATABASE=$(grep LOCAL_DATABASE $FLEET_BUNN_CONFIG | cut -d'=' -f2)
	if [ "$LOCAL_DATABASE" == "0" ]; then
		# Remote database installation
		info "The database will be installed in remote machine"
		# TODO
	else # local installation
		info "The database will be installed in the local machine"
		yum -y install mysql-server mysql-client
		
		if [ $? -ne 0 ]; then
			critical "Failed to install MYSQL Server and Client"
			exit -1
		else
			info "`mysql -h localhost -V` installed successfully" 
		fi
		
		debug "Attempting to start MySQL"
		service mysqld start
		if [ $? -ne 0 ]; then
			critical "Failed to start MySQL Server"
			exit -1
		else
			info "MySQL started successfully" 
			debug "Adding entry to chkconfig so that mysql starts automatically at server startup"
			/sbin/chkconfig --levels 235 mysqld on
		fi
		
		#
		# we need to configure MySQL after installation is over
		# This will include: 
		#   - change the MySQL root password 
		#   - remove anonymous user accounts
		#   - disable root logins outside of localhost
		#   - remove test databases
		# We will also create a new database and associate a new user 
		# with the database
		#
		
		# determine the database name to be created
		# If name not present, enter a default name
		MYSQL_NAME=$(grep MYSQL_NAME $FLEET_BUNN_CONFIG | cut -d'=' -f2)
		if [ "$MYSQL_NAME" == "" ]; then
			MYSQL_NAME="`hostname`_d1"
		fi
		
		# determine database user name to be associated with the new database
		# If user name not present, enter a default name
		MYSQL_USER=$(grep MYSQL_USER $FLEET_BUNN_CONFIG | cut -d'=' -f2)
		if [ "$MYSQL_USER" == "" ]; then
			MYSQL_USER="`hostname`_u1"
		fi
		
		# determine mysql password from config file for the new database
		# if no password is provided, generate some random password of 8 character
		MYSQL_PASS=$(grep MYSQL_PASS $FLEET_BUNN_CONFIG | cut -d'=' -f2)
		if [ "$MYSQL_PASS" == "" ]; then
			MYSQL_PASS=`openssl rand -base64 8`
		fi
		
		# generate some random root password for MySQL root
		MYSQL_ROOTPWD=`openssl rand -base64 12`
		
		# create a new temp .sql file with our commands that we will execute 
		# against the newly created database
		MYSQL_TMPFILE=`mktemp --suffix=.sql`

		echo "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOTPWD}') WHERE User='root';" > $MYSQL_TMPFILE
		echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" >> $MYSQL_TMPFILE
		echo "DELETE FROM mysql.user WHERE User='';" >> $MYSQL_TMPFILE
		echo "DROP DATABASE test;" >> $MYSQL_TMPFILE
		echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" >> $MYSQL_TMPFILE
		
		# create a new database with new user
		echo "CREATE DATABASE ${MYSQL_NAME} CHARACTER SET 'utf8';" >> $MYSQL_TMPFILE
		echo "CREATE USER '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASS}';" >> $MYSQL_TMPFILE
		echo "CREATE USER '${MYSQL_USER}'@localhost IDENTIFIED BY '${MYSQL_PASS}';" >> $MYSQL_TMPFILE
		echo "GRANT ALL PRIVILEGES ON ${MYSQL_NAME}.* TO '${MYSQL_USER}'@'127.0.0.1';" >> $MYSQL_TMPFILE
		echo "GRANT ALL PRIVILEGES ON ${MYSQL_NAME}.* TO '${MYSQL_USER}'@localhost;" >> $MYSQL_TMPFILE
		echo "flush privileges;" >> $MYSQL_TMPFILE
		
		cat $MYSQL_TMPFILE | mysql -u root
		
		if [ $? -ne 0 ]; then
			warning "SQL execution error while configuring MySQL database"
		else
			info "MySQL configuration done"
			rm $MYSQL_TMPFILE
		fi
		
		# 
		# Changing a few configuration parameter in my.cnf
		# Following configurations are set for an initial setting
		# assuming the node has 1 GB memory. All of these config
		# should be re-evaluated once MySQL is run for few days in full
		# production environment. For the later stage of optimization, one
		# good place to start is MySQL tuning primer code available at
		# https://launchpadlibrarian.net/78745738/tuning-primer.sh
		#
		debug "Taking back-up of my.cnf"
		cp $MYSQL_CONFIG_LOC $INSTALL_FOLDER
		if [ $? -ne 0 ]; then
			critical "Failed to backup MySQL Config. Exiting"
			exit -1
		fi
		
		info "Modifying my.cnf file with recommended values for 1GB node"
		debug "Downloading MySQL config file template..."
		
		wget --quiet --tries=3 --output-document=my.cnf https://raw.github.com/akash-mitra/fleeting-bunny/master/templates/mysql-config-1gb
		if [ $? -eq 0 ]; then
			debug "Replacing $MYSQL_CONFIG_LOC with downloaded my.cnf"
			cp ./my.cnf $MYSQL_CONFIG_LOC
		else
			warning "Failed to download MySQL Config file. Possible connection issue"
		fi
		
		debug "Attempting MySQL database restart"
		service mysqld restart
		if [ $? -ne 0 ]; then
			warning "Server failed to start"
			debug "Restoring default my.cnf"
			cp ${INSTALL_FOLDER}/my.cnf ${MYSQL_CONFIG_LOC}
			debug "Attempting MySQL database restart (2nd time)"
			service mysqld restart
			if [ $? -ne 0 ]; then
				critical "MySQL failed to restart. Exiting"
				exit -1
			fi
		fi
		
		info "MySQL database restarted successfully"
		DB_INSTALLED=1
	fi # end of local install
else
	warning "Skipping MySQL Installation"
fi


# --------------------------------------------------------
#        ACTIVATE FIREWALL
# --------------------------------------------------------
# TODO
# Below section is pretty primitive. Two more major functionalities
# namely, packet logging and kernel tweaking needs to be added in
# this section, along with common port scanning blocking rules.
# One reference is: Easyfwgen

info "Starting Firewall configuration"

# At this point, we will install and activate iptables firewall 
# in the system provided the same is not already installed

debug "Checking if iptables firewall is already installed"
rpm -q iptables >> /dev/null
if [ $? -ne 0 ]; then
	warning "Firewall not installed by default. Need to run installation"
	debug "Installing Iptables Firewall"
	yum -y install iptables
	if [ $? -eq 0 ]; then
		info "Iptables installed successfully"
		
		# TODO: Auto detect iptables location instead of hard-coding
		IPT="/sbin/iptables"
		IPTS="/sbin/iptables-save"
		IPTR="/sbin/iptables-restore"
		
	else 
		critical "Failed to install iptables. Exiting"
		exit -1
	fi
fi

# Flush old rules, old custom tables if any
debug "Flushing existing rule, if any"
$IPT --flush
$IPT --delete-chain

# we will set a default policy to DROP all packets and then add rules to specifically 
# allow (ACCEPT) packets that may be from trusted IP addresses, or for certain ports 
# on which we have services running such as, HTTP, SSH etc.

# Before applying our rules, we will temporary store all our rules in a rule file and
# later finally add the rules in Firewall
debug "Generating Firewall Rule file"
$IPTS > firewall.rule

# we will start by creating the default rule for all the chains
# We will be blocking all the incoming packets by default
# However, we will allow all the outgoing packets by default
debug "Setting Firewall default: Drop all incoming packets unless explicitly allowed"
echo "-P INPUT DROP" >> firewall.rule
echo "-P OUTPUT ACCEPT" >> firewall.rule

# Allow any packets in our loopback interface (127.0.0.1)
debug "Accept packets in loopback interface"
echo "-A INPUT -i lo -j ACCEPT" >> firewall.rule

# All TCP sessions should begin with SYN
echo "-A INPUT -p tcp ! --syn -m state --state NEW -s 0.0.0.0/0 -j DROP" >> firewall.rule

# Allow established session to receive traffic
echo "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> firewall.rule

# Web Traffic
if [ $APACHE_INSTALLED -eq 1 ]; then

	info "Opening firewall port [$APACHE_PORT] for HTTP traffic"
	# Allow HTTP connection on tcp port $APACHE_PORT determined above
	echo "-A INPUT -p tcp --dport $APACHE_PORT -m state --state NEW -s 0.0.0.0/0 -j ACCEPT" >> firewall.rule

	info "Opening firewall port [$SECURE_APACHE_PORT] for HTTPS traffic"
	# Allow HTTPS connection on tcp port $SECURE_APACHE_PORT determined above
	echo "-A INPUT -p tcp --dport $SECURE_APACHE_PORT -m state --state NEW -s 0.0.0.0/0 -j ACCEPT" >> firewall.rule
fi

# Allow SSH connections on tcp port $SSH_PORT determined before
info "Opening firewall port [$SSH_PORT] for SSH traffic"
echo "-A INPUT -p tcp --dport $SSH_PORT -m state --state NEW -s 0.0.0.0/0 -j ACCEPT" >> firewall.rule

# Accept inbound ICMP messages
debug "Limiting ping to 2 packets per second"
echo "-A INPUT -p icmp -m icmp --icmp-type 8 -m limit --limit 2/sec -j ACCEPT" >> firewall.rule

# And if the server is not acting as a router, we drop all the FORWARD packets
PACKET_FORWARDING=$(getConfigValue "PACKET_FORWARDING")
if [ "$PACKET_FORWARDING" != "1" ]; then 
	debug "By default, drop all forward packets"
	echo "-P FORWARD DROP" >> firewall.rule
fi

# Next, we are going to block all the other traffics to our server.
# The rules in iptables firewall are parsed from top to bottom.
# once a rule is matched against an incoming connection and 
# relevant action is taken, following rules does not affect it. 
# As our rules for allowing ssh and web traffic come first, as long as our 
# rule to block all traffic comes after them, we can still accept the traffic we want.

echo "-A INPUT -j DROP" >> firewall.rule

# now apply these rules 
echo "COMMIT" >> firewall.rule
$IPTR < firewall.rule
