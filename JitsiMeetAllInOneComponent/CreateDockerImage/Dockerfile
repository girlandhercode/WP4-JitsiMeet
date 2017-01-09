FROM ubuntu:16.04
MAINTAINER Jernej Trnkoczy
#Razlaga apt-get install -y : Automatic yes to prompts. Assume "yes" as answer to all prompts and run non-interactively.
#Torej ce das ta -y te ne bo nic spraseval in avtomatsko dal odgovor "yes"
RUN apt-get update \ 
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y vim
#Install Java - the version has to be 1.7 or newer - more info here https://github.com/dockerfile/java/blob/master/oracle-java8/Dockerfile
RUN apt-get install -y --no-install-recommends software-properties-common \
    && echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
    && add-apt-repository -y ppa:webupd8team/java \
    && apt-get update \
    && apt-get install -y oracle-java8-installer \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/oracle-jdk8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

#------------------------install prosody server.-----------------------------------------
#On bare-metal Ubuntu 16.04 it is a matter of one line (apt-get install prosody) - but for docker base image it seems we first need to add the repository
#following the https://prosody.im/download/package_repository
RUN echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | tee -a /etc/apt/sources.list \
    && wget https://prosody.im/files/prosody-debian-packages.key -O- | apt-key add - \
    && apt-get update \
    && apt-get install -y prosody \
    #we have to create a folder where prosody will have the rights to write (and subfolders too - this is why we use -R) it's prosody.pid file.
    # We will put an dummy .keep file so nobody deletes the folder by chance
    && mkdir /var/run/prosody/ \
    && touch /var/run/prosody/.keep \
    && chown -R prosody /var/run/prosody
#now copy a template prosody configuration file into /etc/prosdy/conf.avail/ folder
COPY /prosody/XXX.XXX.XXX.XXX.cfg.lua /etc/prosody/conf.avail/XXX.XXX.XXX.XXX.cfg.lua

#-------------------install jitsi-videobridge component - we will put it in the /root folder-------------------------
WORKDIR /root
#lest download and unzip jitsi-videobridge
RUN wget https://download.jitsi.org/jitsi-videobridge/linux/jitsi-videobridge-linux-x64-797.zip \
    && apt-get install -y unzip \
    && unzip jitsi-videobridge-linux-x64-797.zip \
    #clean the .zip file which is not needed anymore
    && rm jitsi-videobridge-linux-x64-797.zip \
    #inside the /root (which is current workdir) we will make a .sip-communicator folder and put a sip-communicator.properties file containin one line in it
    && mkdir .sip-communicator \
    && echo "org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay=false" > /root/.sip-communicator/sip-communicator.properties \
    #create a folder where the jitsi-videobridge log file will be stored
    && mkdir /var/log/jitsi-videobridge

#------------------install jicofo component - we will put it in the /root folder-------------------------------------
WORKDIR /root
#install ant then download and unzip jicofo, use maven to handle dependencies, use ant to build the thing
RUN apt-get install -y ant \
    && apt-get install -y git \
    && git clone https://github.com/jitsi/jicofo.git
WORKDIR /root/jicofo/lib
RUN wget https://repo1.maven.org/maven2/org/apache/maven/maven-ant-tasks/2.1.3/maven-ant-tasks-2.1.3.pom \
    && wget http://search.maven.org/remotecontent?filepath=org/apache/maven/maven-ant-tasks/2.1.3/maven-ant-tasks-2.1.3.jar \
    && mv remotecontent\?filepath\=org%2Fapache%2Fmaven%2Fmaven-ant-tasks%2F2.1.3%2Fmaven-ant-tasks-2.1.3.jar maven-ant-tasks-2.1.3.jar
WORKDIR /root/jicofo
RUN apt-get install -y maven \
    && mvn -U clean package -DskipTests \
    && ant -lib lib dist.lin64 
WORKDIR /root/jicofo/dist/linux
RUN unzip jicofo-linux-x64-build.SVN.zip \
    && rm jicofo-linux-x64-build.SVN.zip \
    && rm -R /root/.m2 \
    && mkdir /var/log/jicofo


#now prepare the jitsi-meet web app. Because it needs node.js etc. that was causing problems if installed as "root" we will just copy a pre-compiled (on other machine) version into the container
COPY ./jitsi-meet/ /srv/jitsi-meet/
#now I need to create a group www-data and then create user www-data and add it to group www-data
#Why www-data - because the nginx server in container is configured to run as www-data - see file /etc/nginc/nginx.conf
#After that we need to change the owner and group of files in /root/jitsi-meet to www-data (so nginx will be able to access them)
#RUN groupadd www-data \
#    && useradd -G www-data www-data \
#    && chown -R www-data:www-data /root/jitsi-meet
#RUN chown -R www-data:www-data /root/jitsi-meet



#now install nginx server
RUN apt-get install -y nginx
COPY /nginx/XXX.XXX.XXX.XXX /etc/nginx/sites-available/XXX.XXX.XXX.XXX

#to be able to inspect the network we install also the net tools
RUN apt-get install -y net-tools \
#and we will need curl - which will help us to get the IP of docker host from within container - see start.sh script
    && apt-get install -y curl

#-----------------------------expose the ports of the container---------------------------------
EXPOSE 443 444 5347 10000/udp
#-----------------------------now configure and start the components - this will be done by external script that we need to copy in container first-------------------------
COPY /start.sh /root/start.sh 
RUN chmod 777 /root/start.sh
#change the workdir just for convinience - if you log into container afterwards you will be in the /root directory
WORKDIR /root
#CMD /root/start.sh --jvbpass=geslojvb --jicpass=geslojic --usrpass=geslousr --domain=www.jernej.com
ENTRYPOINT ["/root/start.sh"]
