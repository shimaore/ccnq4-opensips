FROM shimaore/opensips:1.11.0
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
  python-cjson
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
RUN cp ../config.ini .
WORKDIR ../..

# Configure supervisord, etc.
CMD ["supervisord","-n"]
