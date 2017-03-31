fleeting-bunny
==============

<p align="center">
<b>This tool is no longer maintained, please use Fairy ("https://github.com/akash-mitra/fairy") instead.
<br>
Fairy is an automated Nginx, PHP FPM Web Server Installer for Cloud Services such as DigitalOcean.</b>
</p>

Fleeting-bunny is a bash script that configures and secures DigitalOcean droplets as web server. Currently it works on  Fedora based Linux only (CentOS, Redhat etc.). 

Fleeting-bunny can be executed in interactive mode or in unattended setup mode and can be heavily customized using local or remotely hosted configuration file.

Depending on the customization switches used, it can do any or all of the following things:

 - Update and Upgrade the box
 - Re-configure and secure existing SSH server
 - Perform a server profile test which includes testing I/O speed etc.
 - Install Apache web server
 - Configure Apache web server as virtual host
 - Optimize few generic aspects of Apache web server 
 - Install and configure PHP
 - Install, configure and secure MySQL database
 - Installs Firewall with generic or customizable rule
 - Tweaks some kernel parameters for security and optimization
 - Email all the customization details to specified email ID
 
