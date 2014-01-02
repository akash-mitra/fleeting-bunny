#!/usr/bin/env bash
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
# - Intital Version
#
#---------------------------------------------------------

set -o pipefail

__DIR__="$(cd "$(dirname "${0}")"; echo $(pwd))"
__BASE__="$(basename "${0}")"
__FILE__="${__DIR__}/${__BASE__}"

# user defined function for logging
log () { echo "`hostname` | `date '+%F | %H:%M:%S |'` $1"; }

# Set Default Parameter Values
VERSION="0.01"
MYSQL_CONFIG_LOC="/etc/my.cnf"
INSTALL_FOLDER="/home/setup/"
LOG_FILE="./setup.log"
FLEET_BUNN_CONFIG="./input.ini"
SSH_CONFIG_FILE="./sshd-config"

# run the wizard first to get all the configuration information from user
# show a prompt

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
echo "Press any key to continue..."
read input
clear


# check if root, if not get out
if [ `id -u` != "0" ]; then
echo "Run this ${__FILE__} as root"
 exit -1
else
log "Initiating Setup script version: $VERSION as root"
fi

# check if the Fleeting Bunny config file already exists.
# If not we will just create a blank file to avoid "File Not Found"
# ugly error messages through out the setup process

if [ ! -f $FLEET_BUNN_CONFIG ]; then
   log "WARNING! Fleeting Bunny config file not present"
   echo "# Blank Fleeting Bunny Configuration File - AUTO CREATED" > $FLEET_BUNN_CONFIG
fi
 
# Log current system state
log "System Details: `uname -a`"
log "IP address is : `ifconfig eth0 | grep "inet " | cut -d':' -f2 | cut -d' ' -f1`"

# perform a quick server benchmarking to take note of various 
# server parameters such as CPU, RAM, I/O speed etc

log "Attempt to perform server benchmarking..."
wget --quiet --tries=3 https://raw.github.com/akash-mitra/fleeting-bunny/master/utility/profile.sh
if [ $? -eq 0 ]; then
	bash profile.sh
else
	log "WARNING: Failed to download Profile.sh. Possible connection issue"
fi

# update and upgrade the server
log "Performing yum update"
yum -y update >/dev/null
if [ $? -eq 0 ]; then
log "Update successful"
fi
log "Attempting to upgrade server"
yum -y upgrade > /dev/null
if [ $? -eq 0 ]; then
log "Upgrade Successful"
fi

# create a new staging folder to store prestine copy of products
log "Creating setup directory"
if [ -d $INSTALL_FOLDER ]; then
	log "WARNING: Fleeting Bunny Install directory already exists"
else
	 mkdir $INSTALL_FOLDER
fi

if [ $? -ne 0 ]; then
  echo "Failed to create setup directory under /"
  exit -1
fi

# copy a list of softwares to setup directory
# TODO


# download templates for different server config files
rm -f sshd_template.sh
log "Downloading SSH template..."
wget --quiet --tries=3 --output-document=sshd-config https://raw.github.com/akash-mitra/fleeting-bunny/master/templates/sshd-config 2>&1 1> /dev/null


#--------------------------------------------------------
# securing the SSH server
#--------------------------------------------------------
log "Strengthening the security of the SSH server..."
# SSH
# backup the current ssh config file
cp /etc/ssh/sshd_config $INSTALL_FOLDER
log "Backed up sshd_config under $INSTALL_FOLDER"

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
	log "WARNING! SSH port info not available in config file. Will prompt user"
	echo "Default SSH Port is 22. We suggest you change it."
	echo "Question 1: Which port would you like to run your SSH client [1024-65000]?"
	read SSH_PORT
fi
sed -i "s/__PORT__/$SSH_PORT/g" $SSH_CONFIG_FILE
log "SSH Port to be set to [$SSH_PORT]"

PASS_DISABLE=$(grep PASS_DISABLE $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$PASS_DISABLE" == "" ]; then
	log  "WARNING! SSH Password Auth info not available in config file. Will prompt user"
	echo "We suggest you disable password authentication for other users as well."
	echo "When you disable password, you will need key file to login"
	echo "Question 2: Should we keep password authentication (yes / no)?"
	read PASS_DISABLE
fi
sed -i "s/__PASS_AUTH__/$PASS_DISABLE/g" $SSH_CONFIG_FILE
log "Password based login to be disabled to other users as well"

GRACE_TIME=$(grep GRACE_TIME $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$GRACE_TIME" == "" ]; then
	log "WARNING: LoginGraceTime is not available in config file. Will be defaulted to 60 seconds"
	GRACE_TIME=60
else 
	log "LoginGraceTime will be set to $GRACE_TIME as per config file"
fi
sed -i "s/__GRACE_TIME__/$GRACE_TIME/g" $SSH_CONFIG_FILE

log "Root login to be permitted to the server"
sed -i "s/__PERMIT_ROOT__/yes/g" $SSH_CONFIG_FILE


MAX_AUTH_TRY=$(grep MAX_AUTH_TRY $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$MAX_AUTH_TRY" == "" ]; then
	log "WARNING: MaxAuthTries is not available in config file. Will be defaulted to 4"
	MAX_AUTH_TRY=4
else 
	log "MaxAuthTries will be set to $MAX_AUTH_TRY as per config file"
fi
sed -i "s/__MAX_AUTH_TRY__/$MAX_AUTH_TRY/g" $SSH_CONFIG_FILE

log "Max session count to be set to 6" 
sed -i "s/__MAX_SESSION_COUNT__/6/g" $SSH_CONFIG_FILE

log "X11Forwarding is to be set to 'yes' (Specifies whether X11 forwarding is permitted)"
sed -i "s/__X11_FORWARD__/yes/g" $SSH_CONFIG_FILE

log "ClientAliveInterval to be set to 120 sec. (This will give you 6 minutes of inactivity time)"
sed -i "s/__CLIENT_ALIVE__/120/g" $SSH_CONFIG_FILE

BANNER_TEXT="This is a restricted system. Only explicitely authorized personnel are allowed to login"
echo $BANNER_TEXT > /etc/ssh/banner.text
log "Banner text is to be set"
sed -i "s~__BANNER__~/etc/ssh/banner.text~g" $SSH_CONFIG_FILE

log "Replacing original SSHD_Config with the newly prepared one..."
cp $SSH_CONFIG_FILE /etc/ssh/sshd_config

# restart SSH
log "Attempting to restart SSH server..."
service sshd restart

if [ $? -eq 0 ]; then
	log "... SSH server restarted"
else

	# ssh config change failed. Rollback the changes
	# replace the previously backed up sshd_config
	log "FATAL ERROR: SSHD failed to restart. Attempting rollback" 
	log "INFO: In case rollback fails and we lose ssh access, please use VNC"
	cp $INSTALL_FOLDER/sshd_config /etc/ssh/
	# attempt to restart the server once again
	service sshd restart
	# abort the mission
	exit -1
fi
echo "SSH Server is updated. SSH port set to $SSH_PORT. Remember to login using keyfile next time!"

#--------------------------------------------------------
#        INSTALLING WEB SERVER
#--------------------------------------------------------
# Apache webserver installation starts
# we will use yum command. To avoid interaction, we will use -y consenting switch
# If apache is already present, this command will do nothing

log "Install Apache webserver..."
yum -y install httpd 
if [ $? -eq 0 ]; then
 log "Apache installed"
else
 log "Apache installation failed"
 exit -1 
fi


# In this step, we will try to determine our primary website name from
# fleeting bunny configuration file. In case, we fail to determine this
# we will prompt the user for input

log "Trying to determine primary website name"
SITENAME=$(grep SITENAME $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$SITENAME" == "" ]; then
	log "WARNING: Primary site name not found in fleeting bunny config. Prompting for input"
	echo "In the following step we configure Apache Webserver as a virtual host"
	echo "Please specify your primary website name (e.g. example.com):"
	read SITENAME
fi
log "Primary site name determined as $SITENAME"

# In this step, we will create the directory structure required to store our websites
# we will also grant necessary permissions to apache user
# If any given website found to be existing, we will prompt user for overwrite

log "Creating document root"
if [ -d "/var/www/$SITENAME" ]; then
	echo "The directory already exists. Overwrite it? (y/n)"
	read ANSWER;
	if [ "$ANSWER" == "y" ]; then
		log "Specified directory exists, removing the same"
		rm -rf /var/www/$SITENAME
	else 
		log "Exiting the process as the directory already exists"
		exit -1
	fi
fi
WEB_ROOT="/var/www/$SITENAME/public_html"
mkdir -p $WEB_ROOT
if [ $? -ne 0 ]; then
 log "Could not create directory $WEB_ROOT" 
 exit -1 
fi
log "Creating other directories for logging, backup etc."
mkdir -p /var/www/$SITENAME/log
mkdir -p /var/www/$SITENAME/backup

log "Granting ownership of web directories to www user"
chown -R apache:apache $WEB_ROOT
if [ $? -ne 0 ]; then
 log "chown failed to change permission" 
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

log "Starting Apache Configuration.."

# The apache configuration is stored typically in httpd.conf file. The location of
# this configuration file can be varied depending on the system. In the following
# section, we will try to determine this location. One way to determine this location
# is to qyery the apache binary itself. Apache binary (httpd) when queries with -V 
# switch, shows many information and server configuration file location is one of them.
# (For more please refer to httpd man pages)
# To do this, however, we will need to first determine the apache binary location

log "Determine httpd binary location.."
APACHE_LOC=$(whereis -b httpd | cut -d' ' -f2)
log "httpd located at $APACHE_LOC"
log "Querying apache bin to determine Apache root location"
APACHE_ROOT_LOC=$($APACHE_LOC -V | grep HTTPD_ROOT | cut -d'"' -f2)
log "Querying apache bin to determine Apache conf file location"
APACHE_CONFIG_LOC=$($APACHE_LOC -V | grep SERVER_CONFIG_FILE | cut -d'"' -f2)
APACHE_CONFIG_LOC="${APACHE_ROOT_LOC}/${APACHE_CONFIG_LOC}"
log "Config file is determined to be located at $APACHE_CONFIG_LOC"

# Now, before we start making any modification to the apache config file,
# it is good idea to take a backup of this file. If anything goes wrong, we can rollback

log "Backing up config file"
cp $APACHE_CONFIG_LOC $INSTALL_FOLDER
if [ $? -ne 0 ]; then
	log "Failed to backup Apache Config. Exiting"
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
if [ "$APACHE_PORT" == "" ]; then
	log "Apache Port value missing in config file. Prompting for user input"
	echo "By Default webservers execute at port 80. You may want to change this"
	echo "Please enter new port number. Just enter to retain default value"
	read APACHE_PORT
	if [ "$APACHE_PORT" == "" ]; then
		APACHE_PORT="80"
	fi
fi
log "Setting Listener port to $APACHE_PORT"
sed -i "s/^Listen .*/Listen $APACHE_PORT/" $APACHE_CONFIG_LOC
if [ $? -ne 0 ]; then
	log "Failed to modify PORT in Apache Config. Exiting"
	exit -1
fi

# setting up server as Virtual Host
# Virtual Host setting is generally available in the 3rd section of Apache Config
# We are setting the server as virtual host as in the future we might want to host
# multiple websites from the same server

log "Setting up virtual host"
sed -i "s/^#NameVirtualHost .*/NameVirtualHost *:80/" $APACHE_CONFIG_LOC
if [ $? -ne 0 ]; then
	log "Failed to uncomment NameVirtualHost in Apache Config. Exiting"
	exit -1
fi

log "Downloading the virtual host configuration template..."
wget --quiet --tries=3 --output-document=virtual_template.sh https://raw.github.com/akash-mitra/fleeting-bunny/master/templates/apache-vhost
if [ $? -ne 0 ]; then
	log "Failed to download virtual host template. Using default configuration"
	
	echo "# Following lines are added by Fleeting Bunny" > virtual_template.sh
	echo "# This is a static configuration!" >> virtual_template.sh
	echo "<VirtualHost *:80>" >> virtual_template.sh
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
sed -i "s/__SERVER_ADMIN__/webmaster@${SITENAME}/" virtual_template.sh
if [ $? -ne 0 ]; then
	echo "Failed to setup server admin. Exiting"
	exit -1
fi
sed -i "s~__DOCUMENT_ROOT__~/var/www/$SITENAME/public_html~" virtual_template.sh
if [ $? -ne 0 ]; then
	echo "Failed to setup document root. Exiting"
	exit -1
fi
sed -i "s/__SERVER_NAME__/www.$SITENAME/" virtual_template.sh
if [ $? -ne 0 ]; then
	echo "Failed to setup server name. Exiting"
	exit -1
fi
sed -i "s~__ERROR_LOG__~/var/www/$SITENAME/log/error~" virtual_template.sh
if [ $? -ne 0 ]; then
	echo "Failed to setup error log. Exiting"
	exit -1
fi
sed -i "s~__CUSTOM_LOG__~/var/www/$SITENAME/log/access~" virtual_template.sh
if [ $? -ne 0 ]; then
	echo "Failed to setup access log. Exiting"
	exit -1
fi
log "adding the configured virtual host to apache config"
cat virtual_template.sh >> $APACHE_CONFIG_LOC


# At this point, we have successfully setup all the necessary values for virtual 
# server. We will restart apache to check if everything is alright.
# In case of failure, we will rollback the changes

log "stopping all apache processes"
apachectl -k stop
log "starting apache again..."
/etc/init.d/httpd start
if [ $? -ne 0 ]; then
    log "FATAL ERROR: Apache failed to restart. Attempting to re-instate server config"
    cp $APACHE_CONFIG_LOC $INSTALL_FOLDER/httpd.conf.debug
    cp $INSTALL_FOLDER/httpd.conf $APACHE_CONFIG_LOC
    log "A copy of current apache conf is stored in $INSTALL_FOLDER for debug purpose"
	log "Attempting restart again"
	/etc/init.d/httpd start
	exit -1
else
	log "Apache server restarted successfully with virtual hosting environment"
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
	log "Fine Tuning Apache Web server..."
	
	# Hide Apache Server Signature
	log "Switching off Server Signature"
	sed -i 's/^ServerSignature .*/ServerSignature Off/' $APACHE_CONFIG_LOC
	if [ $? -ne 0 ]; then
		log "WARNING: Failed to change Apache directive: ServerSignature"
	fi
	
	# Change ServerToken 
	log "Switching off Server Token"
	sed -i 's/^ServerTokens .*/ServerTokens ProductOnly/' $APACHE_CONFIG_LOC
	if [ $? -ne 0 ]; then
		log "WARNING: Failed to change Apache directive: ServerToken"
	fi
	
	# TODO: server pool size regulation optimization 
fi

log "Apache optimization done. Restarting"
apachectl -k stop
/etc/init.d/httpd start
if [ $? -ne 0 ]; then
	log "Error: Could not restart Apache after optimization. Rolling back to previous state"
	cp $APACHE_CONFIG_LOC $INSTALL_FOLDER/httpd.conf.debug
	cp $INSTALL_FOLDER/httpd.conf.custom $APACHE_CONFIG_LOC
	log "Rollback complete"
	log "A copy of current apache conf is stored in $INSTALL_FOLDER for debug purpose"
	log "Attempting restart again"
	/etc/init.d/httpd start
	if [ $? -ne 0 ]; then
		log "FATAL ERROR: Recurrent error. Exiting"
		exit -1
	fi
fi
log "Apache restarted successfully"
	

#--------------------------------------------------------
#        INSTALL PHP
#--------------------------------------------------------

log "Checking directive for PHP installation"
INSTALL_PHP=$(grep INSTALL_PHP $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$INSTALL_PHP" == "" ]; then
	log "No explicit directive about PHP installation in config file. Will prompt"
	echo "Do you want to install PHP? (y / N)"
	read INSTALL_PHP
fi
if [ "$INSTALL_PHP" == "1" ] || [ "$INSTALL_PHP" == "y" ] || [ "$INSTALL_PHP" == "Y" ]; then
	log "starting PHP installation"
	yum -y install php php-mysql > /dev/null
	if [ $? -ne 0 ]; then
		log "FATAL ERROR: Failed to install PHP or PHP-MYSQL"
		exit -1
	else
		log "`php --version | head -1` installed successfully" 
	fi
	
	# Once the PHP is installed in the above step, we will check if we need to 
	# install other PHP modules / modify anything for the proposed content
	# management system. For example, CMS like Joomla or WordPress may require 
	# certain other PHP module or certain changes in php.ini
	
	log "Determining the location of php.ini file from php_ini_loaded_file()"
	log "Downloading php-ini"
	wget --quiet --tries=3 --output-document=php-ini.php https://raw.github.com/akash-mitra/fleeting-bunny/master/utility/php-ini 2>&1 1> /dev/null
	if [ $? -eq 0 ]; then
		PHP_CONFIG_LOC=`php php-ini.php`
	else
		log "WARNING: Failed to download php-ini.php. Possible connection issue"
		log "Checking php.ini in the default location"
		PHP_CONFIG_LOC="/etc/php.ini"
	fi
	log "php.ini located at $PHP_CONFIG_LOC"
	
	
	CMS=$(grep CMS $FLEET_BUNN_CONFIG | cut -d'=' -f2)
	if [ "$CMS" == "joomla" ] || [ "$CMS" == "Joomla" ] || [ "$CMS" == "JOOMLA" ]; then
		log "Joomla is scheduled to be installed as CMS. Checking additional packages for Joomla"
		
		# Magic Quote GPC changes
		# TODO
	fi
else
	log "WARNING: Skipping PHP Installation"
fi


# --------------------------------------------------------
#       INSTALL MySQL
# --------------------------------------------------------

log "Checking directive for MySQL database installation"
INSTALL_MYSQL=$(grep INSTALL_MYSQL $FLEET_BUNN_CONFIG | cut -d'=' -f2)
if [ "$INSTALL_MYSQL" == "" ]; then
	log "No explicit directive about MySQL installation in config file. Will prompt"
	echo "Do you want to install MySQL database? (y / N)"
	read INSTALL_MYSQL
fi
if [ "$INSTALL_MYSQL" == "1" ] || [ "$INSTALL_MYSQL" == "y" ] || [ "$INSTALL_MYSQL" == "Y" ]; then
	log "Starting MySQL database installation"
	
	# The Database can be installed in the same machine or in some other machine
	# Depending on the value of the parameter LOCAL_DATABASE, installation location
	# may vary. If LOCAL_DATABASE is set to 0, the database will be installed in
	# a separate machine (TODO). For all the other values of this parameter (including
	# the cases where this parameter is not set, the database will be installed on the
	# local machine.
	
	LOCAL_DATABASE=$(grep LOCAL_DATABASE $FLEET_BUNN_CONFIG | cut -d'=' -f2)
	if [ "$LOCAL_DATABASE" == "0" ]; then
		# Remote database installation
		log "The database will be installed in remote machine"
		# TODO
	else # local installation
		log "The database will be installed in the local machine"
		yum -y install mysql-server mysql-client
		
		if [ $? -ne 0 ]; then
			log "FATAL ERROR: Failed to install MYSQL Server and Client"
			exit -1
		else
			log "`mysql -h localhost -V` installed successfully" 
		fi
		
		log "Attempting to start MySQL"
		service mysqld start
		if [ $? -ne 0 ]; then
			log "FATAL ERROR: Failed to start MySQL Server"
			exit -1
		else
			log "MySQL started successfully" 
			log "Adding entry to chkconfig so that mysql starts automatically at server startup"
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
			log "WARNING: SQL execution error"
		else
			log "MySQL configuration done"
			# rm $MYSQL_TMPFILE
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
		log "Taking back-up of my.cnf"
		cp $MYSQL_CONFIG_LOC $INSTALL_FOLDER
		if [ $? -ne 0 ]; then
			log "Failed to backup MySQL Config. Exiting"
			exit -1
		fi
		
		log "Modifying my.cnf file with recommended values for 1GB node"
		log "Downloading MySQL config file template..."
		
		wget --quiet --tries=3 --output-document=my.cnf https://raw.github.com/akash-mitra/fleeting-bunny/master/templates/mysql-config-1gb
		if [ $? -eq 0 ]; then
			log "Replacing $MYSQL_CONFIG_LOC with downloaded my.cnf"
			cp ./my.cnf $MYSQL_CONFIG_LOC
		else
			log "WARNING: Failed to download MySQL Config file. Possible connection issue"
		fi
		
		log "Attempting MySQL database restart"
		service mysqld restart
		if [ $? -ne 0 ]; then
			log "WARNING: Server failed to start"
			log "Restoring default my.cnf"
			cp ${INSTALL_FOLDER}/my.cnf ${MYSQL_CONFIG_LOC}
			log "Attempting MySQL database restart (2nd time)"
			service mysqld restart
			if [ $? -ne 0 ]; then
				log "FATAL ERROR: MySQL failed to restart. Exiting"
				exit -1
			fi
		fi
		
		log "MySQL database restarted successfully"
		
	fi # end of local install
else
	log "WARNING: Skipping MySQL Installation"
fi
