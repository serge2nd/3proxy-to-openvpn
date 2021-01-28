FROM alpine
ARG TPROXY_VER=0.9.3
ARG TPROXY_DIST=3proxy-$TPROXY_VER
ARG TPROXY_SRC_URL=https://github.com/z3APA3A/3proxy/archive/$TPROXY_VER.tar.gz
ARG TPROXY_PLUGINS_DIR=/usr/local/3proxy/libexec
ARG EXPOSED=8090-8099

ENV \
# VPN tunnels count
N=10 \
# `openvpn` start timeout
OVPN_TIMEOUT=5 \
# `openvpn` base arguments
OVPN_BASE_ARGS="--config /dev/stdin" \
# to write `openvpn` PIDs
OVPN_PIDS_DIR="/var/run/ovpn" \
# to write `openvpn` logs
OVPN_LOGS_DIR="/var/log/ovpn" \
# to write 3proxy logs
TPROXY_LOGS_DIR="/var/log/3proxy"

ADD . /

RUN apk add --no-cache --virtual .build-essential        \
        gcc g++ libc-dev linux-headers make              &&\
    wget -qO- "$TPROXY_SRC_URL" | tar -xz                &&\
    make -C "$TPROXY_DIST" -f Makefile.Linux             &&\
    mkdir -p "$TPROXY_LOGS_DIR"                          &&\
    mkdir -p "$TPROXY_PLUGINS_DIR"                       &&\
    cp "$TPROXY_DIST"/bin/3proxy  "/bin/"                &&\
    cp "$TPROXY_DIST"/bin/*.ld.so "$TPROXY_PLUGINS_DIR/" &&\
    rm -rf "$TPROXY_DIST" && apk del .build-essential    &&\
    apk add --no-cache openvpn                           &&\
    mkdir -p "$OVPN_PIDS_DIR"                            &&\
    mkdir -p "$OVPN_LOGS_DIR"

EXPOSE $EXPOSED
