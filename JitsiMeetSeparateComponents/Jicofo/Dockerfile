FROM ubuntu:16.04
MAINTAINER Jernej Trnkoczy
#Explanation of DEBIAN_FRONTEND=noninteractive and -y : this will ensure "silent install" i.e. automatic yes to prompts and run non-interactively.
RUN apt-get update \ 
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y vim \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y net-tools \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2 \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y unzip

#Install Java - the version has to be 1.7 or newer - more info here https://github.com/dockerfile/java/blob/master/oracle-java8/Dockerfile
RUN apt-get install -y --no-install-recommends software-properties-common \
    && echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
    && add-apt-repository -y ppa:webupd8team/java \
    && apt-get update \
    && apt-get install -y oracle-java8-installer \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/oracle-jdk8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

#------------------install jicofo component - we will put it in the /root folder-------------------------------------
WORKDIR /root
#install ant then download and unzip jicofo, use maven to handle dependencies, use ant to build the thing
RUN apt-get update \
    && apt-get install -y ant \
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

#I think that Jicofo does not need any ports published/exposed. There is no "client" that speaks directly with jicofo. All the signalling is sent from client to nginx which fowards BOSH requests
#to Prosody - and then it is Prosody that sends XMPP messages to/from Jicofo

#-----------------------------now configure and start Jicofo - this will be done by external script that we need to copy in container first-------------------------
COPY /startjicofo.sh /root/startjicofo.sh 
RUN chmod 777 /root/startjicofo.sh
#change the workdir just for convinience - if you log into container afterwards you will be in the /root directory
WORKDIR /root
ENTRYPOINT ["/root/startjicofo.sh"]
