#!/bin/sh
set -eo pipefail
set -x

rm -f "$LOGS_PATH/NDS.txt"
exec >>"$LOGS_PATH/NDS.txt"
exec 2>&1

echo "$0" "$@"

mkdir -p "$USERDATA_PATH/NDS-advanced-drastic"
EMU_DIR="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak/drastic"
PACK_DIR="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak"

export PATH="$EMU_DIR:$PACK_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$EMU_DIR/libs:$PACK_DIR/lib:$LD_LIBRARY_PATH"

cleanup() {
    rm -f /tmp/stay_awake

    if [ -f "$USERDATA_PATH/NDS-advanced-drastic/cpu_governor.txt" ]; then
        cat "$USERDATA_PATH/NDS-advanced-drastic/cpu_governor.txt" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
        rm -f "$USERDATA_PATH/NDS-advanced-drastic/cpu_governor.txt"
    fi
    if [ -f "$USERDATA_PATH/NDS-advanced-drastic/cpu_min_freq.txt" ]; then
        cat "$USERDATA_PATH/NDS-advanced-drastic/cpu_min_freq.txt" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
        rm -f "$USERDATA_PATH/NDS-advanced-drastic/cpu_min_freq.txt"
    fi
    if [ -f "$USERDATA_PATH/NDS-advanced-drastic/cpu_max_freq.txt" ]; then
        cat "$USERDATA_PATH/NDS-advanced-drastic/cpu_max_freq.txt" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
        rm -f "$USERDATA_PATH/NDS-advanced-drastic/cpu_max_freq.txt"
    fi

    umount "$EMU_DIR/backup" || true
    umount "$EMU_DIR/cheats" || true
    umount "$EMU_DIR/savestates" || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor >"$USERDATA_PATH/NDS-advanced-drastic/cpu_governor.txt"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq >"$USERDATA_PATH/NDS-advanced-drastic/cpu_min_freq.txt"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq >"$USERDATA_PATH/NDS-advanced-drastic/cpu_max_freq.txt"
    echo performance >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 1608000 >/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    echo 1800000 >/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

    mkdir -p "$SDCARD_PATH/Saves/NDS"
    mkdir -p "$SDCARD_PATH/Cheats/NDS"
    mkdir -p "$EMU_DIR/backup"

    if [ -d "$EMU_DIR/cheats" ]; then
        if ls -A "$EMU_DIR/cheats" | grep -q .; then
            cd "$EMU_DIR/cheats"
            mv * "$SDCARD_PATH/Cheats/NDS/" || true
        fi
    fi

    mount -o bind "$SDCARD_PATH/Saves/NDS" "$EMU_DIR/backup"
    mount -o bind "$SDCARD_PATH/Cheats/NDS" "$EMU_DIR/cheats"

    mkdir -p "$SHARED_USERDATA_PATH/NDS-advanced-drastic"
    mkdir -p "$EMU_DIR/savestates"
    mount -o bind "$SHARED_USERDATA_PATH/NDS-advanced-drastic" "$EMU_DIR/savestates"

    cd "$EMU_DIR"
    export HOME="$EMU_DIR"
    minui-power-control drastic &
    "$EMU_DIR/drastic" "$*"
}

main "$@"
