FROM shimaore/opensips:1.11.1
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  iptables-dev \
  libjson0 \
  libnetfilter-conntrack-dev \
  make \
  netcat \
  python-application \
  python-cjson \
  python-dev \
  python-gnutls \
  python-twisted-core \
  supervisor

# Install Node.js using `n`.
RUN git clone https://github.com/tj/n.git
WORKDIR n
RUN make install
WORKDIR ..
RUN n io 1.7.1
ENV NODE_ENV production

# Prepare mediaproxy
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

# Node.js code
RUN npm install && npm cache clean

# 5708: supervisord HTTP
# 5060: default proxy_port for `client` profile
# 5070: default proxy_port for `registrant` profile
# 8560: httpd_port (MI-JSON interface)
EXPOSE 5708 5060 5060/udp 5070 5070/udp 8560
# Configure supervisord, etc.
CMD ["supervisord","-n"]
