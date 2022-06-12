#!/bin/bash
TYPE=$1
NAME=$2
STATE=$3
case $STATE in
  "MASTER")
    logger -t conjur-ha-keepalived "VRRP $TYPE $NAME changed to $STATE state"
    exit 0
    ;;
  "BACKUP"|"FAULT")
    logger -t conjur-ha-keepalived "VRRP $TYPE $NAME changed to $STATE state"
    exit 0
    ;;
  *)
    logger -t conjur-ha-keepalived "Unknown state $STATE for VRRP $TYPE $NAME"
    exit 1
    ;;
esac