FROM shimaore/docker.opensips:v4.3.0
MAINTAINER Stéphane Alnet <stephane@shimaore.net>
ENV NODE_ENV production

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  make \
  supervisor \
  && \
  git clone https://github.com/tj/n.git n.git && \
  cd n.git && \
  make install && \
  cd .. && \
  rm -rf n.git && \
  n 8.3.0

# Start opensips part.
COPY . /home/opensips
RUN chown -R opensips.opensips /home/opensips
USER opensips
WORKDIR /home/opensips

RUN mkdir -p log run/opensips \
  && npm install && npm cache -f clean

USER root
RUN \
  apt-get purge -y \
    build-essential \
    ca-certificates \
    cpp-6 \
    gcc-6 \
    curl \
    git \
    make \
  && apt-get autoremove -y \
  && apt-get clean

USER opensips
# 5708: supervisord HTTP
# 5060: default proxy_port for `client` profile
# 5070: default proxy_port for `registrant` profile
# 8560: httpd_port (MI-JSON interface)
EXPOSE 5708 5060 5060/udp 5070 5070/udp 8560
# Configure supervisord, etc.
CMD ["/home/opensips/supervisord.conf.sh"]
