VirtualHost "XXX.XXX.XXX.XXX"
      authentication = "anonymous"
      ssl = {
            key = "/var/lib/prosody/XXX.XXX.XXX.XXX.key";
            certificate = "/var/lib/prosody/XXX.XXX.XXX.XXX.crt";
      }
      modules_enabled = {
            "bosh";
            "pubsub";
      }
VirtualHost "auth.XXX.XXX.XXX.XXX"
      authentication = "internal_plain"

admins = { "focus@auth.XXX.XXX.XXX.XXX" }

Component "conference.XXX.XXX.XXX.XXX" "muc"

Component "jitsi-videobridge.XXX.XXX.XXX.XXX"
      component_secret = "YOURSECRET1"

Component "focus.XXX.XXX.XXX.XXX"
      component_secret = "YOURSECRET2"

