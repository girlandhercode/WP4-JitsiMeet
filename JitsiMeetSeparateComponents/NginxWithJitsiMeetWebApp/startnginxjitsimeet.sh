#!/bin/bash

#This script will configure jitsi-meet web app, configure nginx server and then start the server with the app.

# Parse shell args.
# Synopsis: ./script.sh --xmppdomain=xmppdomain --confsubdomain=confsubdomain --jvbsubdomain=jvbsubdomain --nginxdomain=nginxdomain --xmpphost=xmpphost
# Note: argument order is not important.
while [[ $# -gt 0 ]]
do
	arg="${1}"

	key="${arg%%=*}"     	# Extract key.
        value="${arg##*=}"	# Extract value.


	case "${key}" in
		#this is the main XMPP domain - it must be the same as written in the Prosody configuration file
                --xmppdomain)
		ARG_XMPPDOMAIN="${value}"
		;;
		#this is the subdomain (first part of string Component "conference.194.249.1.108) of the conference component - it should be the same as the one in the Prosody config file
                --confsubdomain)
		ARG_CONFSUBDOMAIN="${value}"
		;;
		#this is the subdomain (first part of the string Component "jitsi-videobridge.194.249.1.108) of the videobridge component - it should be the same as the one in the Prosody config
                --jvbsubdomain)
		ARG_JVBSUBDOMAIN="${value}"
		;;
		#this is the public IP or domain name where nginx server is accessible. This parameter is optional and if it is not provided by the user then the script will try to find
                #public IP of the host that is hosting the nginx container programatically.
                --nginxdomain)
                ARG_NGINXDOMAIN="${value}"
                ;;
                #this is the routable address where Prosody server can be reached (nginx will proxy-forward all BOSH requests to Prosody). The value depends on the networking setup. If both
                #nginx and prosody containers are on the same host then we can use the private IP of Prosody container (because it is routable). But if the containers are on two separate
                #hosts then we need to put public IP or domain name of Docker host where Prosody is running (and there have to be -p 5280:5280 port forwarding on this host - by default
                # Prosody is listening on port 5280 for BOSH requests)
                --xmpphost)
                ARG_XMPPHOST="${value}"
                ;;
                *)
		echo "Unknown option" >&2
		exit 1
	esac
	shift
done

if [[ -z "$ARG_XMPPDOMAIN" ]]
then
     echo "The argument --xmppdomain is mandatory!"
     exit 1
elif [[ -z "$ARG_CONFSUBDOMAIN" ]]
then
     echo "The argument --confsubdomain is mandatory!"
     exit 1
elif [[ -z "$ARG_JVBSUBDOMAIN" ]]
then
     echo "The argument --jvbsubdomain is mandatory!"
     exit 1
elif [[ -z "$ARG_XMPPHOST" ]]
then
     echo "The argument --xmpphost is mandatory!"
     exit 1
elif [[ -z "$ARG_NGINXDOMAIN" ]]
then
     #for the configuration of jitsi-meet web app and the nginx config file we need the domain name or the IP where nginx is running. The user can provide this parameter when running the 
     #script (--nginxdomain option) but if he does not provide this we need to obtain the IP of the docker host where the container is running programatically
     ARG_NGINXDOMAIN=`curl -s https://api.ipify.org`
     if [[ -z "$ARG_NGINXDOMAIN" ]]
     then
          echo "FATAL: Automatically determining the public IP of the host of nginx container failed!"
          exit 1 
     fi
fi


     
export NGINX_LOG=/var/log/nginx/access.log
touch $NGINX_LOG
chmod 666 $NGINX_LOG


echo "--------------------THE FOLLOWIN CONFIGURATION WAS USED FOR THE CONFIGURATION OF JITSI-MEET WEB APP AND NGINX SERVER---------------------------" | tee -a "$NGINX_LOG"
echo "XMPP server domain=${ARG_XMPPDOMAIN}" | tee -a "$NGINX_LOG"
echo "XMPP server routable IP=${ARG_XMPPHOST}" | tee -a "$NGINX_LOG"
echo "Conference component subdomain=${ARG_CONFSUBDOMAIN}" | tee -a "$NGINX_LOG"
echo "Vidoebridge component subdomain=${ARG_JVBSUBDOMAIN}" | tee -a "$NGINX_LOG"
echo "Nginx server domain=${ARG_NGINXDOMAIN}" | tee -a "$NGINX_LOG"



#------------------conigure the jitsi-meet web app---------------------------------------------------------------------------------------------
sed -i 's/XXX.XXX.XXX.XXX/'$ARG_XMPPDOMAIN'/g' /srv/jitsi-meet/config.js
sed -i 's/TTT.TTT.TTT/'$ARG_CONFSUBDOMAIN'/g' /srv/jitsi-meet/config.js
sed -i 's/UUU.UUU.UUU/'$ARG_JVBSUBDOMAIN'/g' /srv/jitsi-meet/config.js
sed -i 's/YYY.YYY.YYY.YYY/'$ARG_NGINXDOMAIN'/g' /srv/jitsi-meet/config.js

#------------------configure nginx server------------------------------------------------------------------------------------------------------
cp /etc/nginx/sites-available/AAA.AAA.AAA.AAA /etc/nginx/sites-available/$ARG_NGINXDOMAIN && \
sed -i 's/AAA.AAA.AAA.AAA/'$ARG_NGINXDOMAIN'/g' /etc/nginx/sites-available/$ARG_NGINXDOMAIN && \
sed -i 's/BBB.BBB.BBB.BBB/'$ARG_XMPPHOST'/g' /etc/nginx/sites-available/$ARG_NGINXDOMAIN && \
ln -s /etc/nginx/sites-available/$ARG_NGINXDOMAIN /etc/nginx/sites-enabled/$ARG_NGINXDOMAIN
      
#Now lets create the SSL certificates. If prosody and nginx are on the same bare metal or on the same container - then nginx could use the same certificates that we created during
#prosody installation. However now we have them in separate containers - so we can make a new certificate for nginx
mkdir /etc/nginx/ssl
DEBIAN_FRONTEND=noninteractive openssl req \
                             -new -x509 -days 365 -nodes \
                             -subj '/C=SI/ST=Osrednjeslovenska/L=Ljubljana/CN='$ARG_NGINXDOMAIN'' \
                             -newkey rsa:2048 -keyout '/etc/nginx/ssl/'$ARG_NGINXDOMAIN'.key' -out '/etc/nginx/ssl/'$ARG_NGINXDOMAIN'.crt' 

            
#strt nginx
service nginx start

#let's see the last lines of log file. The -f means to "output appended data as the file grows". 
#This will keep the container "alive" - otherwise it will exit if run in background.
tail -f $NGINX_LOG
