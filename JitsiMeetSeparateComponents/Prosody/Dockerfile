FROM ubuntu:16.04
MAINTAINER Jernej Trnkoczy
#We use the DEBIAN_FRONTEND=noninteractive and -y because we need to make the installation "silent" - i.e. automatic yes to prompts and run non-interactively.
RUN apt-get update \ 
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y vim \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y lsb-release \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y net-tools \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2

#------------------------install prosody server.-----------------------------------------
#For Ubuntu16.04 Docker base image we first need to add the repository 
RUN apt-get update \ 
    && echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | tee -a /etc/apt/sources.list \
    && wget https://prosody.im/files/prosody-debian-packages.key -O- | apt-key add - \
    && apt-get update \
    && apt-get install -y prosody \
    #we have to create a folder where prosody will have the rights to write it's prosody.pid file.
    # We will put an dummy .keep file in the folder so nobody deletes the folder by chance
    && mkdir /var/run/prosody/ \
    && touch /var/run/prosody/.keep \
    && chown -R prosody /var/run/prosody
#now copy a template prosody configuration file to the right location
COPY /XXX.XXX.XXX.XXX.cfg.lua /etc/prosody/conf.avail/XXX.XXX.XXX.XXX.cfg.lua

#We could expose the ports here with EXPOSE command - however the ports that will have to be published will vary from the networking setup (all components on a single host, all components on different
#hosts, all containers running as a single Kubernetes pod, components running as different Kubernetes pods, etc...). So we will not EXPOSE anything - but read the comments about the ports!
#Prosody uses different ports (that also depends on the configuration of Prosody). In our example prosody will use the following ports:
#5347 --> port used by external components (jicofo, jvb, muc, ....) to connect to Prosody
#5280 --> port for HTTP communication (BOSH)
#5281 --> port for HTTPS communication
#5269 --> s2s (server-to-server) communication
#5222 --> c2s (client-to-server) communication


#now configure and start the prosody component - this will be done by external script that we need to copy in container first-------------------------
COPY /startprosody.sh /root/startprosody.sh 
RUN chmod 777 /root/startprosody.sh
#change the workdir just for convinience - if you log into container afterwards you will be in the /root directory
WORKDIR /root
ENTRYPOINT ["/root/startprosody.sh"]
