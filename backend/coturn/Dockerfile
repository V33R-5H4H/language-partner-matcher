FROM coturn/coturn:4.6.2-alpine

USER root
COPY turnserver.conf /etc/coturn/turnserver.conf

# Standard STUN/TURN ports
EXPOSE 3478/tcp
EXPOSE 3478/udp
EXPOSE 5349/tcp
EXPOSE 5349/udp

# Dynamic Relay Port Range
EXPOSE 49152-65535/udp

ENTRYPOINT ["turnserver", "-c", "/etc/coturn/turnserver.conf"]
