#!/bin/sh

# Drop $1 when the home button is pressed, so the loop can stop without the
# hold-power reboot.
#
# NOTE: Nickel grabs the input device exclusively, so this sees nothing until
#       trmnl.sh has killed it. That is the normal case here.
# NOTE: The home button shares its node with the power button, which is how the
#       device is woken, so the key code matters: reacting to any key would stop
#       the loop on every wake.

FLAG=${1:-/tmp/trmnl_stop}
KEY_HOME=102
KEY_POWER=116
# A tap to wake is comfortably under this; a deliberate hold to exit is
# comfortably over it, well short of the firmware's own hold-to-power-off.
POWER_HOLD_MS=1500

# 1. Check for dedicated home button
device=$(./bin/fbink/input_scan -q -p -m home -x touchscreen 2>/dev/null | cut -d, -f1)
if [ -n "$device" ] && [ -e "$device" ]; then
    ./scripts/log.sh "Watching ${device} for the home button" "DEBUG"
    exec ./bin/luajit lua/watch_key.lua "$device" "$KEY_HOME" "$FLAG"
fi

# 2. Check for page-turn buttons (e.g. Kobo Libra 2, Forma, Libra H2O)
device=$(./bin/fbink/input_scan -q -p -m pagination -x touchscreen 2>/dev/null | cut -d, -f1)
if [ -n "$device" ] && [ -e "$device" ]; then
    ./scripts/log.sh "Watching ${device} for page-turn buttons to exit loop" "DEBUG"
    exec ./bin/luajit lua/watch_key.lua "$device" "0" "$FLAG" "0"
fi

# 3. No home or page buttons (e.g. Clara HD): fall back to the power button,
# which every scheduled wake also presses, so a plain press can't mean stop.
# Holding it does, since a scheduled wake never holds it.
device=$(./bin/fbink/input_scan -q -p -m power -x touchscreen 2>/dev/null | cut -d, -f1)
if [ -z "$device" ] || [ ! -e "$device" ]; then
    ./scripts/log.sh "No home or power button found, the loop cannot be stopped by a button" "WARN"
    exit 0
fi

./scripts/log.sh "No home button, watching ${device} for a ${POWER_HOLD_MS}ms power button hold" "DEBUG"
exec ./bin/luajit lua/watch_key.lua "$device" "$KEY_POWER" "$FLAG" "$POWER_HOLD_MS"
