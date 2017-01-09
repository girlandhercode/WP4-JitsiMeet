FROM ubuntu:16.04
MAINTAINER Jernej Trnkoczy
# -y means: Automatic yes to prompts. Assume "yes" as answer to all prompts and run non-interactively.
RUN apt-get update \ 
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y vim \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y net-tools \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y curl


#now prepare the jitsi-meet web app. Because it needs node.js etc. that was causing problems if installed as "root" we will just copy a pre-compiled (on other machine) version into the container
COPY ./jitsi-meet/ /srv/jitsi-meet/

#now install nginx server
RUN apt-get install -y nginx
COPY /AAA.AAA.AAA.AAA /etc/nginx/sites-available/AAA.AAA.AAA.AAA

#The ports that this container is using:
#444 --> this is the port for https connections coming from clients in web browsers

#-----------------------------now configure and start the nginx - we will do that with an external script that we need to copy in container first-------------------------
COPY /startnginxjitsimeet.sh /root/startnginxjitsimeet.sh 
RUN chmod 777 /root/startnginxjitsimeet.sh
#change the workdir just for convinience - if you log into container afterwards you will be in the /root directory
WORKDIR /root
ENTRYPOINT ["/root/startnginxjitsimeet.sh"]
