#!/bin/bash

# this script is used to configure prosody server and start it.

# Parse shell args.
# Synopsis: ./script.sh --jvbpass=jvbpass --jicpass=jicpass --usrpass=usrpass --domain=domain
# Note: argument order is not important.
while [[ $# -gt 0 ]]
do
	arg="${1}"

	key="${arg%%=*}"     	# Extract key.
        value="${arg##*=}"	# Extract value.


	case "${key}" in
		#This is the password for videobridge external component. It is written to Prosody configuration file. This parameter is mandatory.
                --jvbpass)
		ARG_JVBPASS="${value}"
		;;
                #This is the password for jicofo external component. It is written to Prosody configuration file. This parameter is mandatory.
		--jicpass)
		ARG_JICPASS="${value}"
		;;
                #This is the password for the "focus" user (that is created with prosodyclt commnad below). Jicofo component will, besides acting as a Prosody component, act as a Prosody client
                #as well. When jicofo will act as client it will do this as "focus" user - in this case jicofo will have to use this password. The password is written to the Prosody 
                #configuration file. This parameter is mandatory.
		--usrpass)
		ARG_USRPASS="${value}"
		;;
                #This is the "main XMPP domain" - it can be either IP or domain name (in the latter you will need DNS). It is written to Prosody configuration file on several places, e.g. 
                #certificates section, domain and subdomain section, components description section etc. --> see the template prosody configuration file. This parameter is not mandatory - if
                #the user does not specify it then the script will try to automatically determine the IP address to be used instead.
		--domain)
		ARG_DOMAIN="${value}"
		;;
                *)
		echo "Unknown option" >&2
		exit 1
	esac
	shift
done

if [[ -z "$ARG_JVBPASS" ]]
then
     echo "The argument --jvbpass is mandatory!"
     exit 1
elif [[ -z "$ARG_JICPASS" ]]
then 
     echo "The argument --jicpass is mandatory!"
     exit 1
elif [[ -z "$ARG_USRPASS" ]]
then 
     echo "The argument --usrpass is mandatory!"
     exit 1
elif [[ -z "$ARG_DOMAIN" ]]
then
     #for the configuration of the prosody  we need the domain name or the public IP where the prosody will be running. The user can provide the domain name when running the script (--domain option)
     #but if he does not provide this we need to obtain the IP of the docker host where the container is running programatically
     ARG_DOMAIN=`curl -s https://api.ipify.org`
     if [[ -z "$ARG_DOMAIN" ]]
     then
          echo "FATAL: User did not provide domain parameter and determining the IP of host automatically failed!"
          exit 1 
     fi
fi
     
#now we need to determine the local docker IP - i.e. the IP of the bridge interface this container is using. We will then use this IP when defining the interfaces where Prosody will listen
#This will be put it in the "global section" of the prosody configuration file - check below...
#LOCAL_DOCKER_INTERFACE=172.17.0.2
LOCAL_DOCKER_INTERFACE=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
if [[ -z "$LOCAL_DOCKER_INTERFACE" ]]
then
        echo "FATAL: The IP of the lodal docker interface could not be determined automatically!"
        exit 1 
fi

export PROSODY_LOG=/var/log/prosody/prosody.log
touch $PROSODY_LOG 
chmod 666 $PROSODY_LOG


echo "--------------------THE FOLLOWIN PROSODY CONFIGURATION DATA WAS USED-----------------------------------" | tee -a "$PROSODY_LOG"
echo "Videobridge password=${ARG_JVBPASS}" | tee -a "$PROSODY_LOG"
echo "Jicofo password=${ARG_JICPASS}" | tee -a "$PROSODY_LOG"
echo "User password=${ARG_USRPASS}" | tee -a "$PROSODY_LOG"
echo "Domain name=${ARG_DOMAIN}" | tee -a "$PROSODY_LOG"
echo "Local container interface where Prosody will listen=${LOCAL_DOCKER_INTERFACE}" | tee -a "$PROSODY_LOG"
echo "-----------------------------------------------------------------------------------------------------------" | tee -a "$PROSODY_LOG"


#-----------------configure prosody---------------------------------------------------------------------------------------------------------
#copy the template configuration file to appropriate location and replace the values in this file
cp /etc/prosody/conf.avail/XXX.XXX.XXX.XXX.cfg.lua /etc/prosody/conf.avail/$ARG_DOMAIN.cfg.lua
sed -i 's/YYY.YYY.YYY.YYY/'$LOCAL_DOCKER_INTERFACE'/g' /etc/prosody/conf.avail/$ARG_DOMAIN.cfg.lua
sed -i 's/XXX.XXX.XXX.XXX/'$ARG_DOMAIN'/g' /etc/prosody/conf.avail/$ARG_DOMAIN.cfg.lua
sed -i 's/YOURSECRET1/'$ARG_JVBPASS'/g' /etc/prosody/conf.avail/$ARG_DOMAIN.cfg.lua
sed -i 's/YOURSECRET2/'$ARG_JICPASS'/g' /etc/prosody/conf.avail/$ARG_DOMAIN.cfg.lua
ln -s /etc/prosody/conf.avail/$ARG_DOMAIN.cfg.lua /etc/prosody/conf.d/$ARG_DOMAIN.cfg.lua
#create the necessary SSL certificates (note: we will not use prosodyclt cert generate command because we cannot make it "silent" - instead we will use plain openssl)
DEBIAN_FRONTEND=noninteractive openssl req \
                             -new -x509 -days 365 -nodes \
                             -subj '/C=SI/ST=Osrednjeslovenska/L=Ljubljana/CN='$ARG_DOMAIN'' \
                             -newkey rsa:2048 -keyout '/var/lib/prosody/'$ARG_DOMAIN'.key' -out '/var/lib/prosody/'$ARG_DOMAIN'.crt' && \
#register the focus user
prosodyctl register focus auth.$ARG_DOMAIN $ARG_USRPASS 
            
#start prosody
prosodyctl start
#let's see the last lines of log file. The -f means to "output appended data as the file grows".
#This will keep container "alive" - otherwise it will exit if run in background.
tail -f $PROSODY_LOG
