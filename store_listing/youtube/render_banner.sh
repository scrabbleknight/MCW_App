#!/bin/sh
# Renders banner.html to banner.png (2560x1440) with headless Chrome.
set -e
cd "$(dirname "$0")"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --allow-file-access-from-files \
  --force-device-scale-factor=1 \
  --window-size=2560,1440 \
  --virtual-time-budget=5000 \
  --screenshot="$PWD/banner.png" \
  "file://$PWD/banner.html"
