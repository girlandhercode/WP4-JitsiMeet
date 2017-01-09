#!/bin/bash

#This script will configure and start the jicofo component

# Parse shell args.
# Synopsis: ./script.sh --domain=domain --subdomain=subdomain --host=host --port=port --jicpass=jvbpass --userdomain=userdomain --username=username  --usrpass=usrpass
# Note: argument order is not important.
while [[ $# -gt 0 ]]
do
	arg="${1}"

	key="${arg%%=*}"     	# Extract key.
        value="${arg##*=}"	# Extract value.


	case "${key}" in
		#this parameter together with --subdomain parameter tells the "whole "name" under which the jicofo external component is registered in Prosody configuration.
                #This "whole name" is then used to bind the jicofo XMPP external component to Prosody server. If Prosoci configuration contains Component "focus.194.249.1.108" then the
                #--domain shoudl be 194.249.1.108 and --subdomain should be focus.
                --domain)
		ARG_DOMAIN="${value}"
		;;
                #Together with --domain tells the "whole name" to bind external component to Prosody server (see above).
                --subdomain)
		ARG_SUBDOMAIN="${value}"
		;;
                #this is the hostname of the XMPP server (Prosody). What to put here depends on the network configuration. If you have containers in the same subnet (e.g. on one Docker
                #machine) then you can put a local IP address of the prosody container (the IP of the network interface that was configured in the component_interface="172.17.0.2" line of prosodc cfg.lua file)
                #If this is not the case and the containers are on different subnets (and cannot "see each others local IP") then you should put the public IP or domainname of the host that is hosting the
                #XMPP container (and has port forwarding to the container configured).
                --host)
		ARG_HOST="${value}"
		;;
                #this is the port of the XMPP server - this should be the port for external components defined in the Prosody configuration
                --port)
		ARG_PORT="${value}"
		;;
                #sets the shared secret used to authenticate focus component to the XMPP server. Should be the same as the password for focus component in the Prosody configuration file
                --jicpass)
		ARG_JICPASS="${value}"
		;;
                #specifies the name of XMPP domain used by the focus user to login. Should be the same as the one specified in the Prosody configuration. Example value "auth.194.249.1.108"
                --userdomain)
		ARG_USERDOMAIN="${value}"
		;;
                #specifies the username used by the focus XMPP user to login. Should be the same as the one specified in the Prosody configuration file. Exmaple value "focus"
                --username)
		ARG_USERNAME="${value}"
		;;
                #specifies the password used by focus XMPP user to login. Should be the one that was set when registering "focus" user with "prosodyctl register focus auth.194.249.1.108 usrgeslo"
                --usrpass)
		ARG_USRPASS="${value}"
		;;
		*)
		echo "Unknown option" >&2
		exit 1
	esac
	shift
done

#all of the parameters are mandatory - if not all are provided then exit
if [[ -z "$ARG_DOMAIN" ]]
then
      echo "The argument domain is mandatory!"
      exit 1
elif [[ -z "$ARG_HOST" ]]
then 
      echo "The argument host is mandatory!"   
      exit 1
elif [[ -z "$ARG_PORT" ]]
then 
      echo "The argument port is mandatory!"   
      exit 1
elif [[ -z "$ARG_SUBDOMAIN" ]]
then 
      echo "The argument subdomain is mandatory!"   
      exit 1
elif [[ -z "$ARG_JICPASS" ]]
then 
      echo "The argument jicpass is mandatory!"   
      exit 1
elif [[ -z "$ARG_USERDOMAIN" ]]
then 
      echo "The argument userdomain is mandatory!"   
      exit 1
elif [[ -z "$ARG_USERNAME" ]]
then 
      echo "The argument username is mandatory!"   
      exit 1
elif [[ -z "$ARG_USRPASS" ]]
then 
      echo "The argument usrpass is mandatory!"   
      exit 1
fi

 
#lets define the location of the jicofo log file, and make this variable an  environment variable (with "export") - environment varable means that all the child processes will be able to access it
export JIC_LOG=/var/log/jicofo/jicofo.log
#we make the empty log file for jicofo
touch $JIC_LOG
#and change its permissions so everybody is able to write to it
chmod 666 $JIC_LOG

    
echo "--------------------THE FOLLOWING CONFIGURATION DATA WILL BE USED-----------------------------------" | tee -a "$JIC_LOG"
echo "Jicofo component domain=${ARG_DOMAIN}" | tee -a "$JIC_LOG"
echo "Jicofo component subdomain=${ARG_SUBDOMAIN}" | tee -a "$JIC_LOG"
echo "XMPP host=${ARG_HOST}" | tee -a "$JIC_LOG"
echo "XMPP port=${ARG_PORT}" | tee -a "$JIC_LOG"
echo "Jicofo password=${ARG_JICPASS}" | tee -a "$JIC_LOG"
echo "User domain=${ARG_USERDOMAIN}" | tee -a "$JIC_LOG"
echo "Username=${ARG_USERNAME}" | tee -a "$JIC_LOG"
echo "User password=${ARG_USRPASS}" | tee -a "$JIC_LOG"

#now lets start jicofo
#ATTENTION - we are outputing to log file which is inside the container and grows indefinitely - and this is not appropriate "production ready" solutiom.
#We could logrotate the file (see http://superuser.com/questions/291368/log-rotation-of-stdout) - however cron + logrotate inside the container is again not the right solution!
#The issue is complex - see https://www.loggly.com/blog/top-5-docker-logging-methods-to-fit-your-container-deployment-strategy/ for more.... 
/root/jicofo/dist/linux/jicofo-linux-x64-build.SVN/jicofo.sh --domain="$ARG_DOMAIN" --host="$ARG_HOST" --port="$ARG_PORT" --subdomain="$ARG_SUBDOMAIN" --secret="$ARG_JICPASS" --user_domain="$ARG_USERDOMAIN" --user_name="$ARG_USERNAME" --user_password="$ARG_USRPASS" >> $JIC_LOG 2>&1 &

#let's see the last lines of log file. The -f means to "output appended data as the file grows".
#This will keep the container "alive" - otherwise it will exit if run in background.
tail -f $JIC_LOG
