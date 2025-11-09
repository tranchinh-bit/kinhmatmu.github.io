#!/usr/bin/env bash
set -e
case "$1" in
  normal)    sudo systemctl set-environment FPS=25 WIDTH=1280 HEIGHT=720 ;;
  powersave) sudo systemctl set-environment FPS=20 WIDTH=960  HEIGHT=540 ;;
  *) echo "Usage: $0 {normal|powersave}"; exit 1 ;;
esac
sudo systemctl restart rtsp.service
echo "Switched to $1 profile."
