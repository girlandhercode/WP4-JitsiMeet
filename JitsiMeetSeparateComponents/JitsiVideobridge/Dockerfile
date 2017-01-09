FROM ubuntu:16.04
MAINTAINER Jernej Trnkoczy
#Explanation of DEBIAN_FRONTEND=noninteractive and -y : Thiw will achieve "silent" installation i.e. automatic yes to prompts and run non-interactively.
RUN apt-get update \ 
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y vim \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y net-tools \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2

#Install Java - the version has to be 1.7 or newer - more info here https://github.com/dockerfile/java/blob/master/oracle-java8/Dockerfile
RUN apt-get install -y --no-install-recommends software-properties-common \
    && echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
    && add-apt-repository -y ppa:webupd8team/java \
    && apt-get update \
    && apt-get install -y oracle-java8-installer \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/oracle-jdk8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle
#-------------------install jitsi-videobridge component - we will put it in the /root folder-------------------------
WORKDIR /root
#lest download and unzip jitsi-videobridge
RUN wget https://download.jitsi.org/jitsi-videobridge/linux/jitsi-videobridge-linux-x64-813.zip \
    && apt-get update \
    && apt-get install -y unzip \
    && unzip jitsi-videobridge-linux-x64-813.zip \
    #clean the .zip file which is not needed anymore
    && rm jitsi-videobridge-linux-x64-813.zip \
    #create a folder where the jitsi-videobridge log file will be stored
    && mkdir /var/log/jitsi-videobridge

#We could EXPOSE ports here - however this depends on the networking configuration. For example it is different if we want to run components on different Docker hosts or all on one docker host (where they
#can communicate using local docker interfaces). Also if we run containers in one Kubernetes pod or with linked containers (where they can communicate using localhost). So we will rather make some comments
#on used ports and we will publish/expose when running the container
#443 --> this is the port of jitsi-videobridge Jetty server which is used if the video streams cannot be streamed using UDP
#10000/udp --> this is the port where all UDP streams of all users will be sent. Jitsi-videobridge is by default configured for this "single UDP port" functionallity.However it is possible to use
#videobridge also in multi-UDP-port setup - where each user has different UDP port picked in the range from 10000-20000 (but we do not want to use that!)


#-----------------------------now configure and start the components - this will be done by external script that we need to copy in container first-------------------------
COPY /startvideobridge.sh /root/startvideobridge.sh 
RUN chmod 777 /root/startvideobridge.sh
#change the workdir just for convinience - if you log into container afterwards you will be in the /root directory
WORKDIR /root
ENTRYPOINT ["/root/startvideobridge.sh"]
