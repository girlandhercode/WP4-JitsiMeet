#!/bin/bash

#if we would like to have interactive reconfiguration - then we need to unset DEBIAN_FRONTEND variable (because someone might set it to "noninteractive")
#unset DEBIAN_FRONTEND
#however we will have a noninteractive configuration so we will set this
#export DEBIAN_FRONTEND=noninteractive

# Parse shell args.
# Synopsis: ./script.sh --jvbpass=jvbpass --jicpass=jicpass --usrpass=usrpass --domain=domain
# Note: argument order is not important.
while [[ $# -gt 0 ]]
do
	arg="${1}"

	key="${arg%%=*}"     	# Extract key.
        value="${arg##*=}"	# Extract value.


	case "${key}" in
		--jvbpass)
		ARG_JVBPASS="${value}"
		;;
		--jicpass)
		ARG_JICPASS="${value}"
		;;
		--usrpass)
		ARG_USRPASS="${value}"
		;;
		--domain)
		ARG_DOMAIN="${value}"
		;;
                *)
		echo "Unknown option" >&2
		exit 1
	esac
	shift
done

#for the configuration of the components we need the domain name of the services or the IP where they are running. The user can provide the domain name when running the script (--domain option)
#but if he does not provide this we need to obtain the IP of the docker host where the container is running programatically
#DOMAIN_NAME=194.249.1.108
DOMAIN_NAME=$ARG_DOMAIN
if [[ -z "$ARG_DOMAIN" ]]
then
     DOMAIN_NAME=`curl -s https://api.ipify.org`
     if [[ -z "$DOMAIN_NAME" ]]
     then
          echo "!!!!!!!!!!!!!!USER DID NOT PROVIDE DOMAIN OR IP. WHEN TRYING TO DETERMINE IP OF HOST AUTOMATICALLY THE METHOD FAILED. THE PROGRAM WILL EXIT!!!!!!!!!"
          exit 1 
     fi
fi
     
#now we need to determine the local docker IP - i.e. the IP of the bridge interface this container is using
#LOCAL_DOCKER_INTERFACE=172.17.0.2
LOCAL_DOCKER_INTERFACE=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
if [[ -z "$LOCAL_DOCKER_INTERFACE" ]]
then
        echo "!!!!!!!!!!!!!!THE IP OF THE LOCAL DOCKER INTERFACE (i.e. BRIDGE INTERFACE) COULD NOT BE DETERMINED AUTOMATICALLY PLEASE SET IT MANUALLY. THE PROGRAM WILL NOT WORK OTHERWISE!!!!!!!!!"
        exit 1 
fi

#if the uset set the password use it, if not use the default value
JVB_PASSWORD=${ARG_JVBPASS:-jvbgeslo}
JIC_PASSWORD=${ARG_JICPASS:-jicgeslo}
USR_PASSWORD=${ARG_USRPASS:-usrgeslo}
echo "--------------------THE FOLLOWIN CONFIGURATION DATA WILL BE USED-----------------------------------"
echo "Videobridge password=${JVB_PASSWORD} \
      Jicofo password=${JIC_PASSWORD} \
      User password=${USR_PASSWORD} \
      Domain name=${DOMAIN_NAME} \
      Local docker interface=${LOCAL_DOCKER_INTERFACE}"

#lets define the variables that will hold the locations of the log files, and make them environment variables (with "export") - environment varable means that all the child processes will be able to access it
export JVB_LOG=/var/log/jitsi-videobridge/jvb.log
export JIC_LOG=/var/log/jicofo/jicofo.log
#if the log file of videobridge  does not exist in the container it means that the container was not run - configured and then commited to docker repository. 
#Of course we could do that - but then the container would be usable only on the machine for which it was made for...
#However most of the time we will use a "generic" container that was never run before (there is no log file in container) - in this case lets configure this container 
if [ ! -f "$JVB_LOG" ]; then
      #-----------------configure prosody---------------------------------------------------------------------------------------------------------
      cp /etc/prosody/conf.avail/XXX.XXX.XXX.XXX.cfg.lua /etc/prosody/conf.avail/$DOMAIN_NAME.cfg.lua && \
      sed -i 's/XXX.XXX.XXX.XXX/'$DOMAIN_NAME'/g' /etc/prosody/conf.avail/$DOMAIN_NAME.cfg.lua && \
      sed -i 's/YOURSECRET1/'$JVB_PASSWORD'/g' /etc/prosody/conf.avail/$DOMAIN_NAME.cfg.lua && \
      sed -i 's/YOURSECRET2/'$JIC_PASSWORD'/g' /etc/prosody/conf.avail/$DOMAIN_NAME.cfg.lua && \
      ln -s /etc/prosody/conf.avail/$DOMAIN_NAME.cfg.lua /etc/prosody/conf.d/$DOMAIN_NAME.cfg.lua && \
      #it is possible to create certificate using prosodyctl utility - however it is not possible to make it "silently"
      #so instead we will use plain openssl 
      #DEBIAN_FRONTEND=noninteractive prosodyctl cert generate $DOMAIN_NAME && \
      DEBIAN_FRONTEND=noninteractive openssl req \
                                     -new -x509 -days 365 -nodes \
                                     -subj '/C=SI/ST=Osrednjeslovenska/L=Ljubljana/CN='$DOMAIN_NAME'' \
                                     -newkey rsa:2048 -keyout '/var/lib/prosody/'$DOMAIN_NAME'.key' -out '/var/lib/prosody/'$DOMAIN_NAME'.crt' && \
      prosodyctl register focus auth.$DOMAIN_NAME $USR_PASSWORD 


      #------------------configure jitsi-videobridge------------------------------------------------------------------------------------------------
      echo 'org.jitsi.videobridge.NAT_HARVESTER_LOCAL_ADDRESS='$LOCAL_DOCKER_INTERFACE'' >>  /root/.sip-communicator/sip-communicator.properties && \
      echo 'org.jitsi.videobridge.NAT_HARVESTER_PUBLIC_ADDRESS='$DOMAIN_NAME''  >>  /root/.sip-communicator/sip-communicator.properties


      #------------------conigure the jitsi-meet web app---------------------------------------------------------------------------------------------
      sed -i 's/XXX.XXX.XXX.XXX/'$DOMAIN_NAME'/g' /srv/jitsi-meet/config.js

      #------------------configure nginx server------------------------------------------------------------------------------------------------------
      cp /etc/nginx/sites-available/XXX.XXX.XXX.XXX /etc/nginx/sites-available/$DOMAIN_NAME && \
      sed -i 's/XXX.XXX.XXX.XXX/'$DOMAIN_NAME'/g' /etc/nginx/sites-available/$DOMAIN_NAME && \
      ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/$DOMAIN_NAME

            

      #we make the empty log files for jitsi-videobridge and jicofo
      touch $JVB_LOG && \
      touch $JIC_LOG && \
      #and change their permissions so everybody is able to write to them
      chmod 666 $JVB_LOG && \
      chmod 666 $JIC_LOG
fi

#now lets start all the needed components
#prosody
prosodyctl start
#jitsi-videobridge
#ATTENTION - we are outputing to log file which is inside the container and grows indefinitely - and this is not appropriate "production ready" solutiom.
#We could logrotate the file (see http://superuser.com/questions/291368/log-rotation-of-stdout) - however cron + logrotate inside the container is again not the right solution!
#The issue is complex - see https://www.loggly.com/blog/top-5-docker-logging-methods-to-fit-your-container-deployment-strategy/ for more.... 
/root/jitsi-videobridge-linux-x64-797/jvb.sh --host=localhost --domain="$DOMAIN_NAME" --port=5347 --secret="$JVB_PASSWORD" >> $JVB_LOG 2>&1 &
#jicofo
/root/jicofo/dist/linux/jicofo-linux-x64-build.SVN/jicofo.sh --domain="$DOMAIN_NAME" --host=localhost --secret="$JIC_PASSWORD" --user_domain=auth."$DOMAIN_NAME" --user_name=focus --user_password="$USR_PASSWORD" >> $JIC_LOG 2>&1 &
#nginx
service nginx start



#let's see the last lines of log file. The -f means to "output appended data as the file grows". This is only to keep the container "alive" - otherwise it will exit if run in background.
tail -f $JVB_LOG
#/bin/bash
