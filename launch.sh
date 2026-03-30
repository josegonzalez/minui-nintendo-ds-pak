#!/bin/sh
set -euxo pipefail
rm -f "$LOGS_PATH/NDS.txt"
exec >>"$LOGS_PATH/NDS.txt" 2>&1

echo "$0" "$@"

EMU_DIR="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak/drastic"
PACK_DIR="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak"

SYSTEM_CPU_DIR="/sys/devices/system/cpu/cpufreq"
# NOTE:(2026-03-29 11:08:18 +07)Most low-end handled devices using share frequency on all core(policy0 affect all available cores). Setting everything here is more than enough
SYSTEM_CPU_POLICY0="$SYSTEM_CPU_DIR/policy0"
# NOTE:(2026-03-29 11:08:09 +07)Instead of hardcoding the min/max frequency, we can read it from the system then using awk to pick our desired frequency
AVAILABLE_CPU_FREQS=$(cat "$SYSTEM_CPU_POLICY0/scaling_available_frequencies")
MIN_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{print $1}')
MAX_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{print $NF}')

# NOTE:(2026-03-29 10:43:28 +07) After intense testing for best cpu freq, 1608000 come with perfect balance for efficient and performance. For any device with cpu freq below 1608000, we will use the max freq instead
PREFER_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{for(i=1;i<=NF;i++) if($i<=1608000) val=$i} END{print val}')

NDS_MINUI_SAVE="$SDCARD_PATH/Saves/NDS"
NDS_MINUI_CHEAT="$SDCARD_PATH/Cheats/NDS"
NDS_USERDATA_NAME="NDS-advanced-drastic"
NDS_USERDATA_DIR="$USERDATA_PATH/$NDS_USERDATA_NAME"
NDS_SHARE_USERDATA_DIR="$SHARED_USERDATA_PATH/$NDS_USERDATA_NAME"

TEMP_PREFIX=system_
CPU_SCALING_GOVERNOR=scaling_governor
CPU_SCALING_MIN_FREQ=scaling_min_freq
CPU_SCALING_MAX_FREQ=scaling_max_freq
TEMP_SCALING_FILE="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_GOVERNOR.txt"
TEMP_SCALING_MIN_FREQ="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_MIN_FREQ.txt"
TEMP_SCALING_MAX_FREQ="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_MAX_FREQ.txt"

export PATH="$EMU_DIR:$PACK_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$EMU_DIR/libs:$PACK_DIR/lib:$LD_LIBRARY_PATH"
export HOME="$EMU_DIR"

# NOTE: (2026-03-29 10:49:44 +07)For future researcher, if you have better idea for cpu governor, feel free to add it here. trngaje-advance-drastic current implementation with heavier game or normal game will never use that much cpu load(mostly highest will be ~50%) except when fast forward is toggle. Beside that, especially when using anything but performance governor, when you access menu and wait for a while(cool down cpu load, the current freq now will be the MIN_CPU_FREQ) and resume back, the game cpu freq will be stuck at that $MIN_CPU_FREQ until you reset the game -> stick to one freq and the highest one, which mean performance governor is the best match.
nds_cpu_configure() {
    echo "Custom setting for $1 governor"
    case $1 in
        performance)
            echo "$1" >"$SYSTEM_CPU_POLICY0/$CPU_SCALING_GOVERNOR" || true
            echo "$MIN_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_min_freq" || true
            echo "$PREFER_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_max_freq" || true
            ;;
        *)
            echo "Unsupported governor: $1"
            ;;
    esac
}

# Hack: Force the emulator to run in more stable speed, the UI doesn't provide the option and setting this in the config file will cause the UI to display as none, but the emulator will run in 100%. This has been careful calculate and test to match the best speed it could. Below is the map for the frame_interval value with "Performance->Speed override" setting
# 0 - none
# 100000 - 50%
# 47619 - ~105% -> Just enough so the sound will be as less off sync as possible
# 33333 - 150%
# 25000 - 200%
# 20000 - 250%
# 16666 - 300%
nds_frame_interval_patch() {
    find "$EMU_DIR/config" -name "*.cfg" | while read -r CONFIG_PATH; do
        # If the frame_interval is not 47619 or 100000, set it to 47619
        NDS_CONFIG_SHOULD_PATCH=$(awk -F' = ' '/^frame_interval/ {print !($2>=47619 || $2==100000)}' "$CONFIG_PATH")
        if [ "$NDS_CONFIG_SHOULD_PATCH" -eq 1 ]; then
            sed -i 's/frame_interval *= .*/frame_interval = 47619/' "$CONFIG_PATH"
        fi
    done
}

cleanup() {
    rm -f /tmp/stay_awake

    if [ -f "$TEMP_SCALING_FILE" ]; then
        cat "$TEMP_SCALING_FILE" >"$SYSTEM_CPU_POLICY0/$CPU_SCALING_GOVERNOR" || true
        rm -f "$TEMP_SCALING_FILE"
    fi
    if [ -f "$TEMP_SCALING_MIN_FREQ" ]; then
        cat "$TEMP_SCALING_MIN_FREQ" >"$SYSTEM_CPU_POLICY0/$CPU_SCALING_MIN_FREQ" || true
        rm -f "$TEMP_SCALING_MIN_FREQ"
    fi
    if [ -f "$TEMP_SCALING_MAX_FREQ" ]; then
        cat "$TEMP_SCALING_MAX_FREQ" >"$SYSTEM_CPU_POLICY0/$CPU_SCALING_MAX_FREQ" || true
        rm -f "$TEMP_SCALING_MAX_FREQ"
    fi

    umount "$EMU_DIR/backup" || true
    umount "$EMU_DIR/cheats" || true
    umount "$EMU_DIR/savestates" || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    # Create all required directories if they don't exist
    mkdir -p "$NDS_MINUI_SAVE"
    mkdir -p "$NDS_MINUI_CHEAT"
    mkdir -p "$NDS_USERDATA_DIR"
    mkdir -p "$NDS_SHARE_USERDATA_DIR"
    mkdir -p "$EMU_DIR/backup"
    mkdir -p "$EMU_DIR/savestates"

    cat "$SYSTEM_CPU_POLICY0/$CPU_SCALING_GOVERNOR" >"$TEMP_SCALING_FILE"
    cat "$SYSTEM_CPU_POLICY0/$CPU_SCALING_MIN_FREQ" >"$TEMP_SCALING_MIN_FREQ"
    cat "$SYSTEM_CPU_POLICY0/$CPU_SCALING_MAX_FREQ" >"$TEMP_SCALING_MAX_FREQ"

    # Predefined cpu profile for drastic
    nds_cpu_configure performance
    nds_frame_interval_patch

    if [ -d "$EMU_DIR/cheats" ]; then
        if ls -A "$EMU_DIR/cheats" | grep -q .; then
            mv "$EMU_DIR/cheats/*" "$NDS_MINUI_CHEAT/" || true
        fi
    fi

    mount -o bind "$NDS_MINUI_SAVE" "$EMU_DIR/backup"
    mount -o bind "$NDS_MINUI_CHEAT" "$EMU_DIR/cheats"
    mount -o bind "$NDS_SHARE_USERDATA_DIR" "$EMU_DIR/savestates"

    # Trigger custom minui-power-control and launch the emulator, make sure to be in the current directory
    cd "$EMU_DIR"
    minui-power-control drastic &
    "$EMU_DIR/drastic" "$*"
}

main "$@"
