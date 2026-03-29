#!/bin/sh
# MARK: Setup
set -euxo pipefail
exec >>"$LOGS_PATH/NDS.txt" 2>&1

echo "$0" "$@"

# MARK: Variables
EMU_DIR="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak/drastic"
PACK_DIR="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak"

SYSTEM_CPU_DIR="/sys/devices/system/cpu/cpufreq"
# NOTE: Most low-end handled devices using share frequency on all core(policy0 affect all available cores). Setting everything here is more than enough
SYSTEM_CPU_POLICY0="$SYSTEM_CPU_DIR/policy0"
# NOTE: Instead of hardcoding the min/max frequency, we can read it from the system then using awk to pick our desired frequency
AVAILABLE_CPU_FREQS=$(cat "$SYSTEM_CPU_POLICY0/scaling_available_frequencies")
MIN_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{print $1}')
MAX_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{print $NF}')
SECOND_MAX_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{print $(NF-1)}')
THIRD_MAX_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{print $(NF-2)}')
MIDDLE_MAX_CPU_FREQ=$(echo "$AVAILABLE_CPU_FREQS" | awk '{print $(int(NF/2)+1)}')

TEMP_PREFIX=system_
CPU_SCALING_GOVERNOR=scaling_governor
CPU_SCALING_MIN_FREQ=scaling_min_freq
CPU_SCALING_MAX_FREQ=scaling_max_freq
TEMP_SCALING_FILE="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_GOVERNOR.txt"
TEMP_SCALING_MIN_FREQ="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_MIN_FREQ.txt"
TEMP_SCALING_MAX_FREQ="$NDS_USERDATA_DIR/$TEMP_PREFIX$CPU_SCALING_MAX_FREQ.txt"

NDS_MINUI_SAVE="$SDCARD_PATH/Saves/NDS"
NDS_MINUI_CHEAT="$SDCARD_PATH/Cheats/NDS"
NDS_USERDATA_NAME="NDS-advanced-drastic"
NDS_USERDATA_DIR="$USERDATA_PATH/$NDS_USERDATA_NAME"
NDS_SHARE_USERDATA_DIR="$SHARED_USERDATA_PATH/$NDS_USERDATA_NAME"

# MARK: Exports
export PATH="$EMU_DIR:$PACK_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$EMU_DIR/libs:$PACK_DIR/lib:$LD_LIBRARY_PATH"
export HOME="$EMU_DIR"

# MARK: Functions
cleanup() {
	# Restore to default behavior
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
	umount "$EMU_DIR/sav"]
}

nds_cpu_configure() {
	echo "Custom setting for $1 governor"
	case $1 in
		conservative)
			echo "$MIDDLE_MAX_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_min_freq" || true
			echo "$MAX_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_max_freq" || true
			echo 2 >"$SYSTEM_CPU_DIR/$1/sampling_down_factor" || true
			echo 75 >"$SYSTEM_CPU_DIR/$1/up_threshold" || true
			echo 10 >"$SYSTEM_CPU_DIR/$1/down_threshold" || true
			echo 10 >"$SYSTEM_CPU_DIR/$1/freq_step" || true
			echo 1 >"$SYSTEM_CPU_DIR/$1/ignore_nice_load" || true
			;;
		performance)
			echo "$MIN_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_min_freq" || true
			echo "$SECOND_MAX_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_max_freq" || true
			;;
		schedutil)
			echo "$MIDDLE_MAX_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_min_freq" || true
			echo "$SECOND_MAX_CPU_FREQ" >"$SYSTEM_CPU_POLICY0/scaling_max_freq" || true
			;;

	esac
}

nds_launch() {
	# Hacks: Some retro devices will sleep after a while without this
	echo 1 >/tmp/stay_awake
	trap "cleanup" EXIT INT TERM HUP QUIT

	cat "$SYSTEM_CPU_POLICY0/$CPU_SCALING_GOVERNOR" >"$TEMP_SCALING_FILE"
	cat "$SYSTEM_CPU_POLICY0/$CPU_SCALING_MIN_FREQ" >"$TEMP_SCALING_MIN_FREQ"
	cat "$SYSTEM_CPU_POLICY0/$CPU_SCALING_MAX_FREQ" >"$TEMP_SCALING_MAX_FREQ"

	nds_cpu_configure conservative

	# Create all required directories if they don't exist
	mkdir -p "$SDCARD_PATH/Saves/NDS"
	mkdir -p "$SDCARD_PATH/Cheats/NDS"
	mkdir -p "$EMU_DIR/backup"
    mkdir -p "$EMU_DIR/savestates"
    mkdir -p "$SHARED_USERDATA_PATH/NDS-advanced-drastic"

	if [ -d "$EMU_DIR/cheats" ]; then
		if ls -A "$EMU_DIR/cheats" | grep -q .; then
			mv "$EMU_DIR/cheats/*" "$SDCARD_PATH/Cheats/NDS/" || true
		fi
	fi

	mount -o bind "$SDCARD_PATH/Saves/NDS" "$EMU_DIR/backup"
	mount -o bind "$SDCARD_PATH/Cheats/NDS" "$EMU_DIR/cheats"
	mount -o bind "$SHARED_USERDATA_PATH/NDS-advanced-drastic" "$EMU_DIR/savestates"

	# Trigger custom minui-power-control and launch the emulator, make sure to be in the current directory
	cd "$EMU_DIR"
	minui-power-control drastic &
	"$EMU_DIR/drastic" "$*"
}

# MARK: Main
nds_launch "$@"
