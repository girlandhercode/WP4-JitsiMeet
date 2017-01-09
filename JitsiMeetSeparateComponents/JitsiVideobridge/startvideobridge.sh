#!/bin/bash

#This script will configure and start the jitsi videobridge component

# Parse shell args.
# Synopsis: ./script.sh --jvbpass=jvbpass --domain=domain --xmpphost=xmpphost --xmppport=xmppport
# Note: argument order is not important.
while [[ $# -gt 0 ]]
do
	arg="${1}"

	key="${arg%%=*}"     	# Extract key.
        value="${arg##*=}"	# Extract value.


	case "${key}" in
		#Password that videobridge component will use when registering with prosody. It must be the same as the one provided when configuring prosody.
                --jvbpass)
		ARG_JVBPASS="${value}"
		;;
                #--domain parameter tells part of the "whole name" under which the videobridge external component was defined in Prosody configuration.
                #This "whole name" is then used to bind the videobridge XMPP external component to Prosody server. If Prosody configuration contains Component "jitsi-videobridge:194.249.1.108" then 
                #the --domain parameter shoul be 194.249.1.108 
		--domain)
		ARG_DOMAIN="${value}"
		;;
                #--subdomain parameter tells part of the "whole name" under which the videobridge external component was defined in Prosody configuration.
                #This "whole name" is then used to bind the videobridge XMPP external component to Prosody server. If Prosody configuration contains Component "jitsi-videobridge:194.249.1.108" then 
                #the --subdomain parameter shoul be jitsi-videobridge 
		--subdomain)
		ARG_SUBDOMAIN="${value}"
		;;
                #this is the hostname of the XMPP server (Prosody). What to put here depends on the network configuration. If you have containers in the same subnet (e.g. on one Docker host machine)
                #then you can put a local IP address of the prosody container (the IP of the network interface that was configured in the component_interface="172.17.0.2" line of prosody cfg.lua file.
                #If this is not the case and the containers are on different subnets (and cannot "see each others local IP") then you shoudl put the public IP or the domainname of the host that is hosting the
                #XMPP container (and has appropriate port forwarding to the container configured). In some cases (within Kubernetes pod or with linked containers) it might also be possible to use "localhost"
		--host)
		ARG_XMPPHOST="${value}"
		;;
                #this is the port of the XMPP server - this should be the component port that Prosody is configured to listen on (and is 5347 in default Prosody configuration). 
		--port)
		ARG_XMPPPORT="${value}"
		;;
                *)
		echo "Unknown option" >&2
		exit 1
	esac
	shift
done

# all of the parameters are mandatory - if any of them was not provided then exit immidiately
if [[ -z "$ARG_JVBPASS" ]]
then
     echo "The argument jvbpass is mandatory!"
     exit 1
elif [[ -z "$ARG_DOMAIN" ]]
then
     echo "The argument domain is mandatory!"
     exit 1
elif [[ -z "$ARG_SUBDOMAIN" ]]
then
     echo "The argument subdomain is mandatory!"
     exit 1
elif [[ -z "$ARG_XMPPHOST" ]]
then 
     echo "The argument host is mandatory!"
     exit 1
elif [[ -z "$ARG_XMPPPORT" ]]
then 
     echo "The argument port is mandatory!"
     exit 1
fi
     
#now we need to determine the local docker IP (i.e. the IP of the bridge interface this container is using) because we need to put it in the sip-communicator.properties file
#LOCAL_DOCKER_INTERFACE=172.17.0.2
LOCAL_DOCKER_INTERFACE=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
if [[ -z "$LOCAL_DOCKER_INTERFACE" ]]
then
        echo "FATAL: The IP of the local docker interface could not be determined automatically!"
        exit 1 
fi


PUBLIC_VISIBLE_IP=`curl -s https://api.ipify.org`
if [[ -z "$PUBLIC_VISIBLE_IP" ]]
then
        echo "FATAL: The public IP of container host could not be determined automatically!"
        exit 1 
fi

#lets define the location of the videobridge log file, and make this variable an  environment variables (with "export") - environment varable means that all the child processes will be able to access it
export JVB_LOG=/var/log/jitsi-videobridge/jvb.log
#make empty log file
touch $JVB_LOG
#and change permissions so everybody is able to write to it
chmod 666 $JVB_LOG



echo "--------------------THE FOLLOWING CONFIGURATION DATA WAS USED-----------------------------------" | tee -a "$JVB_LOG"
echo "Videobridge password=${ARG_JVBPASS}" | tee -a "$JVB_LOG"
echo "Videobridge domain=${ARG_DOMAIN}" | tee -a "$JVB_LOG"
echo "Videobridge subdomain=${ARG_SUBDOMAIN}" | tee -a "$JVB_LOG"
echo "XMPP host=${ARG_XMPPHOST}" | tee -a "$JVB_LOG"
echo "XMPP port=${ARG_XMPPPORT}" | tee -a "$JVB_LOG"
echo "The publically visible IP saved to sip-communicator.properties=${PUBLIC_VISIBLE_IP}" | tee -a "$JVB_LOG"
echo "Local docker interface saved to sip-communicator.properties=${LOCAL_DOCKER_INTERFACE}" | tee -a "$JVB_LOG"

#------------------configure jitsi-videobridge------------------------------------------------------------------------------------------------
#inside the /root directory (which is the home directory of the user that will start videobridge) we make a .sip-communicator folder and put a sip-communicator.properties file containin three lines in it
mkdir /root/.sip-communicator
echo 'org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay=false' > /root/.sip-communicator/sip-communicator.properties
echo 'org.jitsi.videobridge.NAT_HARVESTER_LOCAL_ADDRESS='$LOCAL_DOCKER_INTERFACE'' >>  /root/.sip-communicator/sip-communicator.properties
echo 'org.jitsi.videobridge.NAT_HARVESTER_PUBLIC_ADDRESS='$PUBLIC_VISIBLE_IP''  >>  /root/.sip-communicator/sip-communicator.properties

#start the videobridge
#ATTENTION - we are outputing to log file which is inside the container and grows indefinitely - and this is not appropriate "production ready" solutiom.
#We could logrotate the file (see http://superuser.com/questions/291368/log-rotation-of-stdout) - however cron + logrotate inside the container is again not the right solution!
#The issue is complex - see https://www.loggly.com/blog/top-5-docker-logging-methods-to-fit-your-container-deployment-strategy/ for more.... 
/root/jitsi-videobridge-linux-x64-813/jvb.sh --secret="$ARG_JVBPASS" --domain="$ARG_DOMAIN" --subdomain="$ARG_SUBDOMAIN" --host="$ARG_XMPPHOST" --port="$ARG_XMPPPORT" >> $JVB_LOG 2>&1 &

#let's see the last lines of log file. The -f means to "output appended data as the file grows".
#This will keep the container "alive" - otherwise it will exit if run in background.
tail -f $JVB_LOG
