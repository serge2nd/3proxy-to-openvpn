#!/bin/sh
set -eu
. app-env.sh

kickall 2 3proxy openvpn || :
rm -rf "${OVPN_PIDS_DIR:?}"/* || :

if [ -n "$NETS" ]; then
  seq 0 $((N_NETS-1)) | xargs -n1 pub_env
else
  N_NETS=1
  pub0_ip="$(hostname -i)"
  line="$(ipaddr | grep "$pub0_ip")"
  pub0_if="$(echo "$line" | awk '{print $2}')"
  pub0_addr="$(echo "$line" | awk '{print $4}')"
  pub0_gw="$(addr2gw "$pub0_addr")"
fi
NETS=$(seq 0 $((N_NETS-1)))

for i in $NETS; do
  iptables -t nat -A POSTROUTING -o "$(getv "pub${i}_if")" -j MASQUERADE
done

# Re-run 3proxy on tunnels reload
while true; do
  ovpn_restarted=0
  for i in $OVPN_IDS; do
    ensure_ovpn "$i"
  done

  if [ "$ovpn_restarted" -gt "0" ]; then
    kickall 1 3proxy || :
    _3proxy_cfg="$(resolve "$_3PROXY_CFG")"
    echo "--- 3PROXY_CFG ---"
    echo "$_3proxy_cfg"
    echo "--- END_3PROXY_CFG ---"
    echo "$_3proxy_cfg" | 3proxy
  fi

  sleep 2
done
