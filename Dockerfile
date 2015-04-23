FROM shimaore/opensips:1.11.1
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  libjson0 \
  libnetfilter-conntrack-dev \
  iptables-dev \
  netcat \
  python-dev \
  python-application \
  python-gnutls \
  python-twisted-core \
  python-cjson \
  supervisor
RUN mkdir /run/mediaproxy && chown opensips.opensips /run/mediaproxy

# Start opensips part.
COPY . /home/opensips
RUN chown -R opensips.opensips /home/opensips
USER opensips
RUN mkdir -p log run/opensips run/mediaproxy
# Build mediaproxy-dispatcher
WORKDIR vendor
RUN tar xzvf mediaproxy-2.6.1.tar.gz
WORKDIR mediaproxy-2.6.1
RUN ./build_inplace
WORKDIR ../..

# 5708: supervisord HTTP
# 5060: default proxy_port for `client` profile
# 5070: default proxy_port for `registrant` profile
# 8560: httpd_port (MI-JSON interface)
EXPOSE 5708 5060 5060/udp 5070 5070/udp 8560
# Configure supervisord, etc.
CMD ["supervisord","-n"]
