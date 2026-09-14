#!/bin/sh

NDS_USERDATA_NAME="NDS-advanced-drastic"

TEMP_PREFIX=system_
CPU_SCALING_GOVERNOR=scaling_governor
CPU_SCALING_MIN_FREQ=scaling_min_freq
CPU_SCALING_MAX_FREQ=scaling_max_freq

# NOTE:(2026-03-29 11:08:18 +07)Most low-end handled devices using share frequency on all core(policy0 affect all available cores). Setting everything here is more than enough
# Kernels differ on where they expose that policy, so probe both known locations.
NDS_CPU_POLICY_DIRS="/sys/devices/system/cpu/cpufreq/policy0 /sys/devices/system/cpu/cpu0/cpufreq"

# NOTE:(2026-03-29 10:43:28 +07) After intense testing for best cpu freq, 1608000 come with perfect balance for efficient and performance. For any device with cpu freq below 1608000, we will use the max freq instead
NDS_PREFERRED_CPU_FREQ=1608000

# minui-power-control refuses to start outside this list, so h700 gets no deep sleep yet
NDS_POWER_CONTROL_PLATFORMS="tg5040 tg5050 my355 rg35xxplus miyoomini"

# NextUI reports the Trimui Brick as tg5040 with DEVICE=brick. Older MinUI builds
# reported it as its own tg3040 platform with no DEVICE at all.
nds_normalize_platform() {
    if [ "${PLATFORM:-}" = "tg3040" ] && [ -z "${DEVICE:-}" ]; then
        PLATFORM="tg5040"
        DEVICE="brick"
        export PLATFORM DEVICE
    fi
}

nds_init_env() {
    PACK_DIR="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak"
    EMU_DIR="$PACK_DIR/drastic"
    BRICK_DEVICE_DIR="$EMU_DIR/devices/trimui-brick"

    NDS_MINUI_SAVE="$SDCARD_PATH/Saves/NDS"
    NDS_MINUI_CHEAT="$SDCARD_PATH/Cheats/NDS"
    NDS_USERDATA_DIR="$USERDATA_PATH/$NDS_USERDATA_NAME"
    NDS_SHARE_USERDATA_DIR="$SHARED_USERDATA_PATH/$NDS_USERDATA_NAME"
    NDS_DEVICE_FILE="$NDS_USERDATA_DIR/device.txt"

    TEMP_SCALING_FILE="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_GOVERNOR.txt"
    TEMP_SCALING_MIN_FREQ="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_MIN_FREQ.txt"
    TEMP_SCALING_MAX_FREQ="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_MAX_FREQ.txt"

    export PATH="$EMU_DIR:$PACK_DIR/bin:$PATH"
    export LD_LIBRARY_PATH="$EMU_DIR/libs:$PACK_DIR/lib:${LD_LIBRARY_PATH:-}"
    export HOME="$EMU_DIR"
}

nds_cpu_policy_dir() {
    for dir in $NDS_CPU_POLICY_DIRS; do
        if [ -r "$dir/scaling_available_frequencies" ]; then
            echo "$dir"
            return 0
        fi
    done
}

nds_cpu_min_freq() {
    echo "$1" | awk '{for(i=1;i<=NF;i++) if(min=="" || $i<min) min=$i} END{print min}'
}

# NOTE:(2026-03-29 11:08:09 +07)Instead of hardcoding the min/max frequency, we can read it from the system then using awk to pick our desired frequency
nds_cpu_prefer_freq() {
    echo "$1" | awk -v limit="$NDS_PREFERRED_CPU_FREQ" '
        {
            for (i = 1; i <= NF; i++) {
                if (max == "" || $i > max) max = $i
                if ($i <= limit && (val == "" || $i > val)) val = $i
            }
        }
        END { print (val == "" ? max : val) }'
}

# NOTE: (2026-03-29 10:49:44 +07)For future researcher, if you have better idea for cpu governor, feel free to add it here. trngaje-advance-drastic current implementation with heavier game or normal game will never use that much cpu load(mostly highest will be ~50%) except when fast forward is toggle. Beside that, especially when using anything but performance governor, when you access menu and wait for a while(cool down cpu load, the current freq now will be the MIN_CPU_FREQ) and resume back, the game cpu freq will be stuck at that $MIN_CPU_FREQ until you reset the game -> stick to one freq and the highest one, which mean performance governor is the best match.
nds_cpu_configure() {
    if [ -z "${CPU_POLICY_DIR:-}" ]; then
        echo "No cpufreq policy directory available, leaving the governor alone"
        return 0
    fi

    available_freqs="$(cat "$CPU_POLICY_DIR/scaling_available_frequencies")"

    echo "Custom setting for $1 governor"
    case $1 in
    performance)
        echo "$1" >"$CPU_POLICY_DIR/$CPU_SCALING_GOVERNOR" || true
        nds_cpu_prefer_freq "$available_freqs" >"$CPU_POLICY_DIR/$CPU_SCALING_MAX_FREQ" || true
        ;;
    ondemand)
        echo "$1" >"$CPU_POLICY_DIR/$CPU_SCALING_GOVERNOR" || true
        nds_cpu_min_freq "$available_freqs" >"$CPU_POLICY_DIR/$CPU_SCALING_MIN_FREQ" || true
        nds_cpu_prefer_freq "$available_freqs" >"$CPU_POLICY_DIR/$CPU_SCALING_MAX_FREQ" || true
        ;;
    *)
        echo "Unsupported governor: $1"
        ;;
    esac
}

nds_cpu_save_setting() {
    source_path="$CPU_POLICY_DIR/$1"
    target_path="$2"

    rm -f "$target_path"
    [ -r "$source_path" ] || return 0
    cat "$source_path" >"$target_path"
}

nds_cpu_restore_setting() {
    source_path="$1"
    target_path="$CPU_POLICY_DIR/$2"

    [ -f "$source_path" ] || return 0
    cat "$source_path" >"$target_path" || true
    rm -f "$source_path"
}

nds_cpu_save_state() {
    [ -n "${CPU_POLICY_DIR:-}" ] || return 0

    nds_cpu_save_setting "$CPU_SCALING_GOVERNOR" "$TEMP_SCALING_FILE"
    nds_cpu_save_setting "$CPU_SCALING_MIN_FREQ" "$TEMP_SCALING_MIN_FREQ"
    nds_cpu_save_setting "$CPU_SCALING_MAX_FREQ" "$TEMP_SCALING_MAX_FREQ"
}

nds_cpu_restore_state() {
    [ -n "${CPU_POLICY_DIR:-}" ] || return 0

    nds_cpu_restore_setting "$TEMP_SCALING_FILE" "$CPU_SCALING_GOVERNOR"
    nds_cpu_restore_setting "$TEMP_SCALING_MIN_FREQ" "$CPU_SCALING_MIN_FREQ"
    nds_cpu_restore_setting "$TEMP_SCALING_MAX_FREQ" "$CPU_SCALING_MAX_FREQ"
}

nds_buffer_size_patch() {
    echo "Custom setting for $PLATFORM"
    case $PLATFORM in
    tg5040)
        export ALSA_CONFIG_PATH="$BRICK_DEVICE_DIR/alsa/nds_alsa.conf"
        export ALSA_ASOUNDRC="$BRICK_DEVICE_DIR/alsa/.asoundrc"
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        ;;
    esac
}

# Advanced DraStic ships a config per device under drastic/devices. They differ in
# screen orientation and in the SDL joystick button block, so the wrong one leaves the
# device with unusable controls. h700 devices without their own profile fall back to
# the closest sibling, picked by whether the device has analog sticks.
nds_device_profile() {
    platform="${1:-}"
    device="${2:-}"

    case "$platform" in
    h700)
        case "$device" in
        rg28xx) echo "rg28xx" ;;
        rg35xxsp) echo "rg35xx-sp" ;;
        rg40xxv) echo "rg40xx-v" ;;
        rgcubexx) echo "rg-cubexx" ;;
        rg40xxh | rg35xxh | rg35xxpro | rg34xxsp) echo "rg40xx-h" ;;
        *) echo "rg35xx-sp" ;;
        esac
        ;;
    tg5050)
        echo "trimui-smart-pro"
        ;;
    *)
        case "$device" in
        smartpro) echo "trimui-smart-pro" ;;
        *) echo "trimui-brick" ;;
        esac
        ;;
    esac
}

# Seed once per device so that remapping done inside the DraStic settings menu survives
# later launches. The previous config is kept next to the marker file.
nds_seed_device_config() {
    profile="$1"
    profile_dir="$EMU_DIR/devices/$profile"

    if [ ! -d "$profile_dir" ]; then
        echo "No DraStic profile named $profile, keeping the shipped config"
        return 0
    fi

    if [ -f "$NDS_DEVICE_FILE" ] && [ "$(cat "$NDS_DEVICE_FILE")" = "$profile" ]; then
        return 0
    fi

    echo "Seeding DraStic config from the $profile profile"

    if [ -f "$EMU_DIR/config/drastic.cfg" ]; then
        cp -f "$EMU_DIR/config/drastic.cfg" "$NDS_USERDATA_DIR/drastic.cfg.bak"
    fi

    for name in drastic.cfg drastic.cf2; do
        if [ -f "$profile_dir/config/$name" ]; then
            cp -f "$profile_dir/config/$name" "$EMU_DIR/config/$name"
        fi
    done

    if [ -f "$profile_dir/resources/settings.json" ]; then
        cp -f "$profile_dir/resources/settings.json" "$EMU_DIR/resources/settings.json"
    fi

    echo "$profile" >"$NDS_DEVICE_FILE"
}

nds_config_set() {
    config_path="$1"
    key="$2"
    value="$3"

    awk -v key="$key" -v value="$value" '
        $0 ~ "^" key " *=" { print key " = " value; next }
        { print }' "$config_path" >"$config_path.tmp"
    mv -f "$config_path.tmp" "$config_path"
}

# The pak bind mounts Saves/NDS onto the emulator backup directory, so saves have to be
# written in .sav format. Some device profiles ship 0, which writes .dsv instead.
nds_sav_format_patch() {
    config_path="$EMU_DIR/config/drastic.cfg"
    [ -f "$config_path" ] || return 0

    nds_config_set "$config_path" backup_use_sav_format 1
}

# Cheats dropped into the pak get moved out to the shared MinUI cheats directory before
# that directory is bind mounted over the top of them.
nds_migrate_cheats() {
    [ -d "$EMU_DIR/cheats" ] || return 0

    for cheat in "$EMU_DIR/cheats/"*; do
        [ -e "$cheat" ] || continue
        mv -f "$cheat" "$NDS_MINUI_CHEAT/" || true
    done
}

# Extract zip ROMs to a temp directory before launching
nds_resolve_rom_path() {
    NDS_ROM_PATH="$1"

    case "$(echo "$NDS_ROM_PATH" | tr '[:upper:]' '[:lower:]')" in
    *.zip)
        TEMP_ROM_DIR="$(mktemp -d /tmp/nds_rom_XXXXXX)"
        "$PACK_DIR/bin/unzip" -o "$NDS_ROM_PATH" -d "$TEMP_ROM_DIR"
        NDS_ROM_PATH="$(find "$TEMP_ROM_DIR" -name "*.nds" | head -1)"
        ;;
    esac
}

nds_start_power_control() {
    for platform in $NDS_POWER_CONTROL_PLATFORMS; do
        if [ "$platform" = "$PLATFORM" ]; then
            minui-power-control drastic &
            return 0
        fi
    done

    echo "minui-power-control does not support $PLATFORM, deep sleep is unavailable"
}

cleanup() {
    rm -f /tmp/stay_awake

    if [ -n "${TEMP_ROM_DIR:-}" ] && [ -d "$TEMP_ROM_DIR" ]; then
        rm -rf "$TEMP_ROM_DIR"
    fi

    nds_cpu_restore_state

    umount "$EMU_DIR/backup" || true
    umount "$EMU_DIR/cheats" || true
    umount "$EMU_DIR/savestates" || true
}

main() {
    # shellcheck disable=SC3040 # busybox ash supports pipefail
    set -euxo pipefail

    CPU_POLICY_DIR=""
    TEMP_ROM_DIR=""

    nds_normalize_platform
    nds_init_env

    rm -f "$LOGS_PATH/NDS.txt"
    exec >>"$LOGS_PATH/NDS.txt" 2>&1

    echo "$0" "$@"

    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    # Create all required directories if they don't exist
    mkdir -p "$NDS_MINUI_SAVE"
    mkdir -p "$NDS_MINUI_CHEAT"
    mkdir -p "$NDS_USERDATA_DIR"
    mkdir -p "$NDS_SHARE_USERDATA_DIR"
    mkdir -p "$EMU_DIR/backup"
    mkdir -p "$EMU_DIR/savestates"

    CPU_POLICY_DIR="$(nds_cpu_policy_dir)"
    nds_cpu_save_state

    # Predefined cpu profile for drastic
    nds_cpu_configure ondemand
    nds_buffer_size_patch

    nds_seed_device_config "$(nds_device_profile "$PLATFORM" "${DEVICE:-}")"
    nds_sav_format_patch

    nds_migrate_cheats

    mount -o bind "$NDS_MINUI_SAVE" "$EMU_DIR/backup"
    mount -o bind "$NDS_MINUI_CHEAT" "$EMU_DIR/cheats"
    mount -o bind "$NDS_SHARE_USERDATA_DIR" "$EMU_DIR/savestates"

    nds_resolve_rom_path "$*"

    # Trigger custom minui-power-control and launch the emulator, make sure to be in the current directory
    cd "$EMU_DIR"
    nds_start_power_control
    LD_PRELOAD="$EMU_DIR/libs/libadvdrastic.so" "$EMU_DIR/drastic" "$NDS_ROM_PATH"
}

if [ "${NDS_PAK_TEST:-}" != "1" ]; then
    main "$@"
fi
