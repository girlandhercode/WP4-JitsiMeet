-- here we define the port and the interface where prosody will receive requests from other components. If a request will come to some other port or network interface it will be ignored
-- but because prosody runs in container now - we need to provide the interface of containier (or maybe just localhost if we are running all four containers in one Kubernetes pod)
component_ports = { 5347 }
component_interface = "YYY.YYY.YYY.YYY"
-- the same goes for the client-to-server communication - we define the interface to be used. Since we do not specify the port it will be prosody default 5222
c2s_interfaces = { "YYY.YYY.YYY.YYY" }
-- the same goes for the server-to-server communication - we define the interface to be used. Since we do not specify the port it will be prosody default 5269
s2s_interfaces = { "YYY.YYY.YYY.YYY" }
-- we also define the interface to be used for HTTP and HTTPS traffic. Prosody has a small HTTP/HTTPS server that is used for example for BOSH (allows to use XMPP over HTTP, so XMPP apps can also
-- run in web pages - is similar than websockets). 
-- since we did not specify the ports prosody will use default 5280 for HTTP 
http_interfaces = { "YYY.YYY.YYY.YYY" }
-- since we did not specify the ports prosody will use default 5281 for HTTPS
https_interfaces = { "YYY.YYY.YYY.YYY" }


-- here comes the definition of the main prosody domain
VirtualHost "XXX.XXX.XXX.XXX"
      authentication = "anonymous"
      ssl = {
            key = "/var/lib/prosody/XXX.XXX.XXX.XXX.key";
            certificate = "/var/lib/prosody/XXX.XXX.XXX.XXX.crt";
      }
      modules_enabled = {
            -- bosh module is needed because jitsi-meet web app will send BOSH requests to nginx server, which will only porxy/forward them to the XMPP server (over HTTP of course - so we need BOSH)
            "bosh";
            -- pubsub module is used so the components (e.g. videobridge) can send various information to prosody. For example there can be multiple videobridges connected to the same Prosody server
            -- at the same time. They are sending the information which of the videobridges is currently handling the most sessions (using pubsub). This information is then used by jicofo for load
            -- balancing (it takes the videobridge with the smallest number of sessions) - see jicofo load balancing...
            "pubsub";
      }

-- this is another definition of domain (sub domain of the main domain) that will be used for jicofo component (which will act as prosody client when handling the videoconference sessions)
VirtualHost "auth.XXX.XXX.XXX.XXX"
      authentication = "internal_plain"
-- we need to add focus user (the user which is used by jicofo component when making, managing and destroying videoconference sessions) to the admins - so it will actually be able to create and
-- destroy new prosody users (when handling the videoconference sessions)
admins = { "focus@auth.XXX.XXX.XXX.XXX" }

-- now we define three prosody components
-- the first component is "internal component" and is used to handle multi-user-chat
Component "conference.XXX.XXX.XXX.XXX" "muc"
-- the second component is "external component" - it is the jitsi-videobridge that handles UDP stream forwarding
Component "jitsi-videobridge.XXX.XXX.XXX.XXX"
      component_secret = "YOURSECRET1"
-- the third component is also "external component" - it is the jicofo that handles signalling (creating, managing and destroying videoconference sessions)
Component "focus.XXX.XXX.XXX.XXX"
      component_secret = "YOURSECRET2"

