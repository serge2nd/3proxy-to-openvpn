#!/bin/sh
set -eu
. common-env.sh

# shellcheck disable=SC2086,SC2116
NETS="$(echo ${NETS:-})"
# shellcheck disable=SC2034
N_NETS="$(echo "$NETS" | awk '{print NF}')"

# Identificators of available OpenVPN configs
# shellcheck disable=SC2015
OVPN_IDS=$(for i in $(seq 0 $((N-1))); do
  cfg="$(getv "OVPN${i}_CFG")"
  args="$(getv "OVPN${i}_ARGS")"
  [ -n "$cfg" ] || [ -n "$args" ] && echo "$i" || :
done)

# shellcheck disable=SC2046
resolve() {
  echo "$1" | sed \
  $(for i in $NETS; do echo "\
  -e ""s/@PUB${i}_IP/$(take "pub${i}_ip")/g""\
  -e ""s/@PUB${i}_GW/$(take "pub${i}_gw")/g"
  done) \
  $(for i in $OVPN_IDS; do echo "\
  -e ""s/@TUN${i}_IP/$(getv "tun${i}_ip")/g""\
  -e ""s/@TUN${i}_GW/$(getv "tun${i}_gw")/g"
  done)
}

# shellcheck disable=SC2015,SC2046,SC2086,SC2155
ensure_ovpn() {
  local i="$1"
  local start="$(date +%s)"; local curr="$start"

  if ! ipaddr | grep -Eq "\stun$i\s"; then
    [ -f "$OVPN_PIDS_DIR/$i.pid" ] && kick 2 "$(cat "$OVPN_PIDS_DIR/$i.pid")" || :
    setv "tun${i}_ip" ""

    getv "OVPN${i}_CFG" | openvpn \
      --daemon \
      --log "$OVPN_LOGS_DIR/$i.log" \
      --writepid "$OVPN_PIDS_DIR/$i.pid" \
      --dev "tun$i" \
      $OVPN_BASE_ARGS \
      $(resolve "$(getv "OVPN${i}_ARGS")") \
    || curr=$((start+OVPN_TIMEOUT))

    while [ "$((curr-start))" -lt "$OVPN_TIMEOUT" ] && [ -z "$(getv "tun${i}_ip")" ]; do
      sleep .3
      tun_env "$i"
      curr="$(date +%s)"
    done

    if [ -n "$(getv "tun${i}_ip")" ]; then
      let ovpn_restarted+=1
    else
      echo "OpenVPN start $i failed, see $OVPN_LOGS_DIR/$i.log"
    fi
  fi
}

# shellcheck disable=SC2155
pub_env() {
  local i="$1"
  local netaddr="$(echo "$NETS" | awk "{print \$$((i + 1))}")"
  local lines="$(ipaddr | awk '{print $2"/"$4}')"
  local line; local addr; local net

  for line in $lines; do
    addr="${line#*/}"
    net="$(addr2net "$netaddr")"

    if [ "$(addr2net "$addr")" -eq "$net" ]; then
      setv "pub${i}_ip" "${addr%/*}"
      setv "pub${i}_gw" "$(i2ip $((net + 1)))"
      setv "pub${i}_if" "${line%%/*}"
      break
    fi
  done
}
# shellcheck disable=SC2155
tun_env() {
  local i="$1"
  local addr="$(ipaddr | grep -E "\stun$i\s" | awk '{print $4}')"

  setv "tun${i}_ip" "${addr%/*}"
  setv "tun${i}_gw" "$(addr2gw "$addr")"
}
