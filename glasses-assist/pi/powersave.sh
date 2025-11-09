#!/usr/bin/env bash
set -e
if command -v iw >/dev/null 2>&1; then
  iw dev wlan0 set txpower fixed 1000 2>/dev/null || true
fi
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo powersave | sudo tee "$g" >/dev/null || true
done
echo "Powersave applied."
