#!/bin/sh
set -eu

# Get optional var value by name
getv() { eval "echo \"\${$1:-}\""; }
# Get required var value by name
take() { eval "echo \"\${$1?}\""; }
# Set var value by name
setv() { read -r "$1" << VAL
$2
VAL
}

# shellcheck disable=SC2155
kick() {
  local timeout="$1"; shift 1
  local start="$(date +%s)"
  local curr="$start"

  kill "$@" &>/dev/null \
  && while [ "$((curr-start))" -lt "$timeout" ] && chkpid "$@"; do
    sleep .3
    curr="$(date +%s)"
  done \
  && kill -9 "$@" &>/dev/null && sleep .3
}
# shellcheck disable=SC2155
kickall() {
  local timeout="$1"; shift 1
  local any="$(printf "%s\n" "$@" | tr '\n' '|' | sed 's/.$//g')"
  local start="$(date +%s)"
  local curr="$start"

  killall -q "$@" \
  && while [ "$((curr-start))" -lt "$timeout" ] && chkapp "$any"; do
    sleep .3
    curr="$(date +%s)"
  done \
  && killall -9 -q "$@" && sleep .3
}
chkpid() { kill -0 "$@" &>/dev/null; }
chkapp() { pgrep -x "${1:-}" &>/dev/null; }

ip2i() {
  local ip=".$1"
  local i=0; local n=1
  let i+=n*"${ip##*.}"; let n*=256; ip="${ip%.*}"
  let i+=n*"${ip##*.}"; let n*=256; ip="${ip%.*}"
  let i+=n*"${ip##*.}"; let n*=256; ip="${ip%.*}"
  let i+=n*"${ip##*.}"; let n*=256; ip="${ip%.*}"
  echo "$i"
}
i2ip() {
  local i="$1";
  local ip=$((i % 256)); let i/=256
  ip=$((i % 256)).$ip;   let i/=256
  ip=$((i % 256)).$ip;   let i/=256
  ip=$((i % 256)).$ip;   let i/=256
  echo "$ip"
}

i2mask() {
  local i="$1"
  echo $(((2**32 - 1) ^ (2**(32-i) - 1)))
}
addr2net() {
  local ip="${1%/*}"
  local m="${1#*/}"

  [ "$ip" != "$m" ] || m=32
  echo $(($(ip2i "$ip") & $(i2mask "$m")))
}
addr2gw() {
  # shellcheck disable=SC2015
  [ -n "$1" ] && i2ip $(($(addr2net "$1") + 1)) || :
}

ipaddr() { ip -o -4 addr "$@"; }
