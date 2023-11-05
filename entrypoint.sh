#!/bin/sh

if echo "$@" | grep -qEv "^(/app/)?kaspad"; then
  exec dumb-init -- "$@"
elif echo "$@" | grep -qE "\--externalip(=| )"; then
  exec dumb-init -- "$@"
else
  externalIp4=$(dig -4 TXT +short +nocomments +timeout=2 +tries=3 o-o.myaddr.l.google.com @ns1.google.com | sed 's/;;.*//' | sed 's/"//g')
  externalIp6=$(dig -4 TXT +short +nocomments +timeout=2 +tries=3 o-o.myaddr.l.google.com @ns1.google.com | sed 's/;;.*//' | sed 's/"//g')
  if [ -n "$externalIp4" ]; then
    externalIp=$externalIp4
  elif [ -n "$externalIp6" ]; then
    externalIp=$externalIp6
  fi
  if [ -n "$externalIp" ]; then
    if echo "$@" | grep -qE "\--listen(=| )"; then
      externalIp="${externalIp}:$(echo "$@" | grep -oP "\--listen(=| )\S+:\K\d+( |$)" | tail -1)"
    fi
    echo "Public address resolved to: $externalIp"
    exec dumb-init -- "$@" --externalip="$externalIp"
  else
    echo "Public address not found"
    exec dumb-init -- "$@"
  fi
fi

