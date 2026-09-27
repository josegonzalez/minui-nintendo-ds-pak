#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export REPO_DIR

    SDCARD_PATH="$BATS_TEST_TMPDIR/SDCARD"
    export SDCARD_PATH
    export PLATFORM="tg5040"
    export USERDATA_PATH="$SDCARD_PATH/.userdata/$PLATFORM"
    export SHARED_USERDATA_PATH="$SDCARD_PATH/.userdata/shared"
    export LOGS_PATH="$USERDATA_PATH/logs"

    export NDS_PAK_TEST=1
    # shellcheck disable=SC1091
    . "$REPO_DIR/launch.sh"
}

# Build a minimal pak tree with the real DraStic device profiles in place.
fake_pak() {
    unset DEVICE
    PLATFORM="${1:-tg5040}"
    [ -z "${2:-}" ] || DEVICE="$2"
    export PLATFORM DEVICE
    USERDATA_PATH="$SDCARD_PATH/.userdata/$PLATFORM"
    export USERDATA_PATH

    pak_dir="$SDCARD_PATH/Emus/$PLATFORM/NDS.pak"
    mkdir -p "$pak_dir/drastic/config" "$pak_dir/drastic/resources" "$USERDATA_PATH"
    cp -R "$REPO_DIR/drastic/devices" "$pak_dir/drastic/devices"
    cp "$REPO_DIR/drastic/config/drastic.cfg" "$pak_dir/drastic/config/drastic.cfg"
    cp "$REPO_DIR/drastic/config/drastic.cf2" "$pak_dir/drastic/config/drastic.cf2"
    cp "$REPO_DIR/drastic/resources/settings.json" "$pak_dir/drastic/resources/settings.json"

    nds_init_env
    mkdir -p "$NDS_USERDATA_DIR"
}

config_value() {
    awk -F' *= *' -v key="$1" '$1 == key { print $2 }' "${2:-$EMU_DIR/config/drastic.cfg}"
}

profile_config() {
    echo "$REPO_DIR/drastic/devices/$1/config/drastic.cfg"
}

# Stand in for a Pak Store reinstall, which restores the config from the release archive while
# device.txt survives in userdata.
restore_shipped_config() {
    cp -f "$REPO_DIR/drastic/config/drastic.cfg" "$EMU_DIR/config/drastic.cfg"
}

# Stand in for a remap saved from the DraStic menu. nds_config_set treats its key as a regex, so
# it cannot reach a bracketed control name.
remap_control() {
    sed "s/^$(echo "$1" | sed 's/[][]/\\&/g') = .*/$1 = $2/" \
        "$EMU_DIR/config/drastic.cfg" >"$EMU_DIR/config/drastic.cfg.remap"
    mv -f "$EMU_DIR/config/drastic.cfg.remap" "$EMU_DIR/config/drastic.cfg"
}

shipped_configs() {
    echo "$REPO_DIR/drastic/config/drastic.cfg" "$REPO_DIR"/drastic/devices/*/config/drastic.cfg
}

h700_profiles() {
    echo rg28xx rg35xx-sp rg40xx-h rg40xx-v rg-cubexx
}

@test "tg3040 without a device is normalized to a tg5040 brick" {
    PLATFORM="tg3040"
    unset DEVICE
    nds_normalize_platform
    [ "$PLATFORM" = "tg5040" ]
    [ "$DEVICE" = "brick" ]
}

@test "tg3040 with a device is left alone" {
    PLATFORM="tg3040"
    DEVICE="something"
    nds_normalize_platform
    [ "$PLATFORM" = "tg3040" ]
    [ "$DEVICE" = "something" ]
}

@test "trimui devices map onto their drastic profiles" {
    [ "$(nds_device_profile tg5040 brick)" = "trimui-brick" ]
    [ "$(nds_device_profile tg5040 brickpro)" = "trimui-brick" ]
    [ "$(nds_device_profile tg5040 smartpro)" = "trimui-smart-pro" ]
    [ "$(nds_device_profile tg5050 smartpros)" = "trimui-smart-pro" ]
    [ "$(nds_device_profile tg5050 '')" = "trimui-smart-pro" ]
}

@test "an unknown trimui device keeps the shipped brick profile" {
    [ "$(nds_device_profile tg5040 '')" = "trimui-brick" ]
    [ "$(nds_device_profile tg5040 unreleased)" = "trimui-brick" ]
}

@test "h700 devices map onto their drastic profiles" {
    [ "$(nds_device_profile h700 rg28xx)" = "rg28xx" ]
    [ "$(nds_device_profile h700 rg35xxsp)" = "rg35xx-sp" ]
    [ "$(nds_device_profile h700 rg40xxv)" = "rg40xx-v" ]
    [ "$(nds_device_profile h700 rgcubexx)" = "rg-cubexx" ]
}

@test "h700 devices without a profile fall back by analog stick layout" {
    [ "$(nds_device_profile h700 rg40xxh)" = "rg40xx-h" ]
    [ "$(nds_device_profile h700 rg35xxh)" = "rg40xx-h" ]
    [ "$(nds_device_profile h700 rg35xxpro)" = "rg40xx-h" ]
    [ "$(nds_device_profile h700 rg34xxsp)" = "rg40xx-h" ]

    [ "$(nds_device_profile h700 rg35xxplus)" = "rg35xx-sp" ]
    [ "$(nds_device_profile h700 rg34xx)" = "rg35xx-sp" ]
    [ "$(nds_device_profile h700 rgsp)" = "rg35xx-sp" ]
    [ "$(nds_device_profile h700 '')" = "rg35xx-sp" ]
}

@test "every profile the mapping can return exists in the pak" {
    for device in '' brick brickpro smartpro; do
        [ -d "$REPO_DIR/drastic/devices/$(nds_device_profile tg5040 "$device")" ]
    done
    for device in '' smartpros; do
        [ -d "$REPO_DIR/drastic/devices/$(nds_device_profile tg5050 "$device")" ]
    done
    for device in '' rg28xx rg34xx rg34xxsp rg35xxplus rg35xxh rg35xxpro rg35xxsp rg40xxh rg40xxv rgcubexx rgsp; do
        [ -d "$REPO_DIR/drastic/devices/$(nds_device_profile h700 "$device")" ]
    done
}

@test "seeding installs the profile config and records the device" {
    fake_pak h700 rg40xxv

    nds_seed_device_config rg40xx-v

    [ "$(cat "$NDS_DEVICE_FILE")" = "rg40xx-v" ]
    run diff "$EMU_DIR/config/drastic.cfg" "$EMU_DIR/devices/rg40xx-v/config/drastic.cfg"
    [ "$status" -eq 0 ]
    run diff "$EMU_DIR/config/drastic.cf2" "$EMU_DIR/devices/rg40xx-v/config/drastic.cf2"
    [ "$status" -eq 0 ]
}

@test "seeding backs up a config the player changed" {
    fake_pak h700 rg40xxv

    echo "custom" >"$EMU_DIR/config/drastic.cfg"
    nds_seed_device_config rg40xx-v

    [ "$(cat "$NDS_USERDATA_DIR/drastic.cfg.bak")" = "custom" ]
}

@test "seeding copies a profile settings.json when there is one" {
    fake_pak h700 rg28xx

    nds_seed_device_config rg28xx

    run grep -q display_rotate "$EMU_DIR/resources/settings.json"
    [ "$status" -eq 0 ]
}

@test "seeding leaves the shipped settings.json alone without a profile one" {
    fake_pak h700 rg40xxv

    nds_seed_device_config rg40xx-v

    run diff "$EMU_DIR/resources/settings.json" "$REPO_DIR/drastic/resources/settings.json"
    [ "$status" -eq 0 ]
}

@test "a config the player changed is kept for the same device" {
    fake_pak h700 rg40xxv

    nds_seed_device_config rg40xx-v
    echo "remapped" >"$EMU_DIR/config/drastic.cfg"
    nds_seed_device_config rg40xx-v

    [ "$(cat "$EMU_DIR/config/drastic.cfg")" = "remapped" ]
    [ "$(cat "$NDS_DEVICE_FILE")" = "rg40xx-v" ]
}

@test "a config the player saved from the drastic menu is kept" {
    fake_pak h700 rg40xxv

    nds_seed_device_config rg40xx-v
    remap_control "controls_b[CONTROL_INDEX_MENU]" 1039
    nds_seed_device_config rg40xx-v

    [ "$(config_value "controls_b[CONTROL_INDEX_MENU]")" = "1039" ]
    [ ! -f "$NDS_USERDATA_DIR/drastic.cfg.bak" ]
}

# The bug in issue 83: a Pak Store reinstall restores the shipped Trimui config while device.txt
# survives in userdata. Since NextUI rc11 the joystick numbers agree, so the screen orientation is
# what tells the two apart.
@test "a reinstall that restores the shipped config is re-seeded" {
    fake_pak h700 rg35xxsp

    nds_seed_device_config rg35xx-sp
    nds_sav_format_patch
    restore_shipped_config
    [ "$(config_value screen_orientation)" = "1" ]

    nds_seed_device_config rg35xx-sp

    [ "$(config_value screen_orientation)" = "0" ]
    run diff "$EMU_DIR/config/drastic.cfg" "$(profile_config rg35xx-sp)"
    [ "$status" -eq 0 ]
}

@test "a reinstall restores the profile settings.json" {
    fake_pak h700 rg28xx

    nds_seed_device_config rg28xx
    cp -f "$REPO_DIR/drastic/resources/settings.json" "$EMU_DIR/resources/settings.json"
    restore_shipped_config

    nds_seed_device_config rg28xx

    run grep -q display_rotate "$EMU_DIR/resources/settings.json"
    [ "$status" -eq 0 ]
}

# Copying a sibling profile over the config by hand is the obvious workaround for a device the
# mapping guesses wrong, so it has to survive even though those bytes are a shipped profile's.
@test "a hand installed sibling profile is kept" {
    fake_pak h700 rg34xx

    nds_seed_device_config rg35xx-sp
    cp -f "$(profile_config rg40xx-h)" "$EMU_DIR/config/drastic.cfg"
    nds_seed_device_config rg35xx-sp

    run diff "$EMU_DIR/config/drastic.cfg" "$(profile_config rg40xx-h)"
    [ "$status" -eq 0 ]
}

@test "seeding a config that already matches the profile changes nothing" {
    fake_pak h700 rg40xxv

    nds_seed_device_config rg40xx-v
    nds_seed_device_config rg40xx-v

    [ "$(cat "$NDS_DEVICE_FILE")" = "rg40xx-v" ]
    run diff "$EMU_DIR/config/drastic.cfg" "$EMU_DIR/devices/rg40xx-v/config/drastic.cfg"
    [ "$status" -eq 0 ]
    [ ! -f "$NDS_USERDATA_DIR/drastic.cfg.bak" ]
}

@test "an existing backup survives a re-seed of a shipped config" {
    fake_pak h700 rg40xxv

    echo "custom" >"$EMU_DIR/config/drastic.cfg"
    nds_seed_device_config rg40xx-v
    restore_shipped_config
    nds_seed_device_config rg40xx-v

    [ "$(cat "$NDS_USERDATA_DIR/drastic.cfg.bak")" = "custom" ]
}

@test "a deleted config is restored for the recorded device" {
    fake_pak h700 rg40xxv

    nds_seed_device_config rg40xx-v
    rm -f "$EMU_DIR/config/drastic.cfg"
    nds_seed_device_config rg40xx-v

    run diff "$EMU_DIR/config/drastic.cfg" "$EMU_DIR/devices/rg40xx-v/config/drastic.cfg"
    [ "$status" -eq 0 ]
}

# Sourcing launch.sh never runs main, so the suite cannot otherwise catch a helper that strands a
# non-zero status and aborts the launch before the bind mounts.
@test "seeding is safe under errexit" {
    fake_pak h700 rg40xxv

    run sh -ec '. "$REPO_DIR/launch.sh"; nds_init_env; nds_seed_device_config rg40xx-v; nds_seed_device_config rg40xx-v'
    [ "$status" -eq 0 ]
}

@test "seeding runs again when the device changes" {
    fake_pak h700 rg40xxv

    nds_seed_device_config rg40xx-v
    echo "remapped" >"$EMU_DIR/config/drastic.cfg"
    nds_seed_device_config rg-cubexx

    [ "$(cat "$NDS_DEVICE_FILE")" = "rg-cubexx" ]
    run diff "$EMU_DIR/config/drastic.cfg" "$EMU_DIR/devices/rg-cubexx/config/drastic.cfg"
    [ "$status" -eq 0 ]
}

@test "seeding an unknown profile keeps the shipped config" {
    fake_pak h700 rg40xxv

    nds_seed_device_config nonexistent

    [ ! -f "$NDS_DEVICE_FILE" ]
    [ ! -f "$NDS_USERDATA_DIR/drastic.cfg.bak" ]
    run diff "$EMU_DIR/config/drastic.cfg" "$REPO_DIR/drastic/config/drastic.cfg"
    [ "$status" -eq 0 ]
}

joystick_bindings() {
    grep '^controls_b\[' "$1"
}

# A config saved before NextUI rc11: the player's own settings with the old per-model numbers, so
# the menu sits on button 11 (1035) and A on button 3 (1027).
pre_rc11_config() {
    sed -e 's/^controls_b\[CONTROL_INDEX_MENU\] = .*/controls_b[CONTROL_INDEX_MENU] = 1035/' \
        -e 's/^controls_b\[CONTROL_INDEX_A\] = .*/controls_b[CONTROL_INDEX_A] = 1027/' \
        -e 's/^controls_a\[CONTROL_INDEX_A\] = .*/controls_a[CONTROL_INDEX_A] = 97/' \
        -e 's/^screen_swap = .*/screen_swap = 1/' \
        "$(profile_config "$1")" >"$2"
}

@test "a pre-rc11 h700 config gets the profile joystick bindings" {
    fake_pak h700 rg35xxsp
    nds_seed_device_config rg35xx-sp
    pre_rc11_config rg35xx-sp "$EMU_DIR/config/drastic.cfg"
    cp "$EMU_DIR/config/drastic.cfg" "$BATS_TEST_TMPDIR/before.cfg"

    nds_migrate_joystick_layout rg35xx-sp

    [ "$(joystick_bindings "$EMU_DIR/config/drastic.cfg")" = "$(joystick_bindings "$(profile_config rg35xx-sp)")" ]
    [ "$(config_value "controls_a[CONTROL_INDEX_A]")" = "97" ]
    [ "$(config_value screen_swap)" = "1" ]
    run diff "$NDS_JOYSTICK_BACKUP_DIR/drastic.cfg" "$BATS_TEST_TMPDIR/before.cfg"
    [ "$status" -eq 0 ]
    [ "$(cat "$NDS_JOYSTICK_LAYOUT_FILE")" = "trimui" ]
}

@test "per-game configs are moved to the rc11 joystick layout too" {
    fake_pak h700 rg40xxh
    nds_seed_device_config rg40xx-h
    pre_rc11_config rg40xx-h "$EMU_DIR/config/Game.cfg"

    nds_migrate_joystick_layout rg40xx-h

    [ "$(config_value "controls_b[CONTROL_INDEX_MENU]" "$EMU_DIR/config/Game.cfg")" = "1032" ]
    [ "$(config_value "controls_b[CONTROL_INDEX_A]" "$EMU_DIR/config/Game.cfg")" = "1025" ]
    [ "$(config_value screen_swap "$EMU_DIR/config/Game.cfg")" = "1" ]
    [ -f "$NDS_JOYSTICK_BACKUP_DIR/Game.cfg" ]
}

@test "a freshly seeded h700 config is not backed up by the joystick migration" {
    fake_pak h700 rg40xxv
    nds_seed_device_config rg40xx-v

    nds_migrate_joystick_layout rg40xx-v

    [ ! -d "$NDS_JOYSTICK_BACKUP_DIR" ]
    [ "$(cat "$NDS_JOYSTICK_LAYOUT_FILE")" = "trimui" ]
    run diff "$EMU_DIR/config/drastic.cfg" "$(profile_config rg40xx-v)"
    [ "$status" -eq 0 ]
}

@test "the joystick migration runs only once" {
    fake_pak h700 rg35xxsp
    nds_seed_device_config rg35xx-sp
    pre_rc11_config rg35xx-sp "$EMU_DIR/config/drastic.cfg"

    nds_migrate_joystick_layout rg35xx-sp
    remap_control "controls_b[CONTROL_INDEX_MENU]" 1033
    nds_migrate_joystick_layout rg35xx-sp

    [ "$(config_value "controls_b[CONTROL_INDEX_MENU]")" = "1033" ]
}

@test "the joystick migration leaves trimui configs alone" {
    fake_pak tg5040 brick
    pre_rc11_config rg35xx-sp "$EMU_DIR/config/drastic.cfg"
    cp "$EMU_DIR/config/drastic.cfg" "$BATS_TEST_TMPDIR/before.cfg"

    nds_migrate_joystick_layout trimui-brick

    run diff "$EMU_DIR/config/drastic.cfg" "$BATS_TEST_TMPDIR/before.cfg"
    [ "$status" -eq 0 ]
    [ ! -f "$NDS_JOYSTICK_LAYOUT_FILE" ]
}

@test "the joystick migration skips an unknown profile" {
    fake_pak h700 rg40xxv
    pre_rc11_config rg40xx-v "$EMU_DIR/config/drastic.cfg"

    nds_migrate_joystick_layout nonexistent

    [ "$(config_value "controls_b[CONTROL_INDEX_MENU]")" = "1035" ]
    [ ! -f "$NDS_JOYSTICK_LAYOUT_FILE" ]
}

@test "the joystick migration keeps the reference config as it ships" {
    fake_pak h700 rg40xxv
    cp "$REPO_DIR/drastic/config/drastic_original.cfg" "$EMU_DIR/config/drastic_original.cfg"

    nds_migrate_joystick_layout rg40xx-v

    run diff "$EMU_DIR/config/drastic_original.cfg" "$REPO_DIR/drastic/config/drastic_original.cfg"
    [ "$status" -eq 0 ]
}

@test "copying joystick bindings rewrites only controls_b lines" {
    fake_pak h700 rg35xxsp
    pre_rc11_config rg35xx-sp "$BATS_TEST_TMPDIR/target.cfg"
    echo "not_a_real_key = 5" >>"$BATS_TEST_TMPDIR/target.cfg"
    grep -v '^controls_b\[' "$BATS_TEST_TMPDIR/target.cfg" >"$BATS_TEST_TMPDIR/expected.txt"

    nds_config_copy_joystick "$(profile_config rg35xx-sp)" "$BATS_TEST_TMPDIR/target.cfg"

    [ "$(grep -v '^controls_b\[' "$BATS_TEST_TMPDIR/target.cfg")" = "$(cat "$BATS_TEST_TMPDIR/expected.txt")" ]
    [ "$(joystick_bindings "$BATS_TEST_TMPDIR/target.cfg")" = "$(joystick_bindings "$(profile_config rg35xx-sp)")" ]
}

@test "the joystick migration is safe under errexit" {
    fake_pak h700 rg35xxsp
    pre_rc11_config rg35xx-sp "$EMU_DIR/config/drastic.cfg"

    run sh -ec '. "$REPO_DIR/launch.sh"; nds_init_env; nds_seed_device_config rg35xx-sp; nds_migrate_joystick_layout rg35xx-sp; nds_migrate_joystick_layout rg35xx-sp'
    [ "$status" -eq 0 ]
}

# The shipped config being a byte copy of one profile is what lets seeding tell a fresh extract
# of the pak apart from a config the player has saved.
@test "the shipped config is a copy of the profile launch.sh names" {
    [ "$NDS_SHIPPED_PROFILE" = "trimui-brick" ]

    run diff "$REPO_DIR/drastic/config/drastic.cfg" "$(profile_config trimui-brick)"
    [ "$status" -eq 0 ]
    run diff "$REPO_DIR/drastic/config/drastic.cf2" \
        "$REPO_DIR/drastic/devices/trimui-brick/config/drastic.cf2"
    [ "$status" -eq 0 ]
}

@test "sav format is forced on so saves land in Saves/NDS" {
    fake_pak h700 rg35xxsp

    nds_seed_device_config rg35xx-sp
    nds_config_set "$EMU_DIR/config/drastic.cfg" backup_use_sav_format 0

    nds_sav_format_patch
    [ "$(config_value backup_use_sav_format)" = "1" ]
}

@test "sav format patching leaves the rest of the config untouched" {
    fake_pak h700 rg35xxsp

    nds_seed_device_config rg35xx-sp
    nds_config_set "$EMU_DIR/config/drastic.cfg" backup_use_sav_format 0
    before="$(grep -cv backup_use_sav_format "$EMU_DIR/config/drastic.cfg")"
    nds_sav_format_patch
    after="$(grep -cv backup_use_sav_format "$EMU_DIR/config/drastic.cfg")"

    [ "$before" = "$after" ]
    [ "$(config_value screen_orientation)" = "0" ]
}

@test "every device profile already enables the sav format" {
    for config in $(shipped_configs); do
        [ "$(config_value backup_use_sav_format "$config")" = "1" ]
    done
}

# NextUI rc11 puts MENU on SDL button 8 on every h700 model, the same number Trimui uses.
@test "profiles bind the menu to the menu button" {
    for profile in $(h700_profiles) trimui-brick trimui-smart-pro; do
        [ "$(config_value "controls_b[CONTROL_INDEX_MENU]" "$(profile_config "$profile")")" = "1032" ]
    done
}

@test "every h700 profile uses the trimui numbers for the built-in buttons" {
    brick="$(profile_config trimui-brick)"

    for profile in $(h700_profiles); do
        config="$(profile_config "$profile")"
        for control in A B X Y L R START SELECT MENU; do
            key="controls_b[CONTROL_INDEX_$control]"
            [ "$(config_value "$key" "$config")" = "$(config_value "$key" "$brick")" ]
        done
    done
}

# rc11 leaves buttons 11 and 12 unused and has nothing above 14, and L2/R2 are triggers that rest at
# the negative end of axes 2 and 5, so binding that direction would read as held all the time.
@test "no h700 profile binds a joystick input rc11 never sends or always sends" {
    for profile in $(h700_profiles); do
        run awk -F' *= *' '/^controls_b\[/ {
            v = $2 + 0
            if (v == 1035 || v == 1036 || (v >= 1039 && v < 1088) || v == 1218 || v == 1221) {
                print $1 " = " v
                bad = 1
            }
        } END { exit bad }' "$(profile_config "$profile")"
        [ "$status" -eq 0 ]
    done
}

@test "every h700 profile can navigate and leave the drastic menu" {
    for profile in $(h700_profiles); do
        config="$(profile_config "$profile")"
        [ "$(config_value "controls_b[CONTROL_INDEX_UI_SELECT]" "$config")" = "1025" ]
        [ "$(config_value "controls_b[CONTROL_INDEX_UI_BACK]" "$config")" != "65535" ]
        [ "$(config_value "controls_b[CONTROL_INDEX_UI_EXIT]" "$config")" != "65535" ]
    done
}

# README: "Select + L: Quick load", "Select + R: Quick save".
@test "every h700 profile puts quick save on R and quick load on L" {
    for profile in $(h700_profiles); do
        config="$(profile_config "$profile")"
        [ "$(config_value "controls_b[CONTROL_INDEX_HOT_SAVE_STATE]" "$config")" = "1029" ]
        [ "$(config_value "controls_b[CONTROL_INDEX_HOT_LOAD_STATE]" "$config")" = "1028" ]
    done
}

@test "every shipped config binds the same keys in the same order" {
    reference="$(sed 's/ =.*//' "$REPO_DIR/drastic/config/drastic.cfg")"

    for config in $(shipped_configs); do
        [ "$(sed 's/ =.*//' "$config")" = "$reference" ]
    done
}

# libadvdrastic.so dropped CONTROL_INDEX_SWAP_ORIENTATION_A/B and renamed the layout controls, so
# a config still using the old names loses those bindings silently.
@test "every shipped config speaks the schema the bundled library writes" {
    for config in $(shipped_configs); do
        run grep -qE "SWAP_ORIENTATION|CHANGE_LAYOUT_DEC|CHANGE_LAYOUT_INC" "$config"
        [ "$status" -ne 0 ]

        for key in ADVANCE_CONTROL_INDEX_CHANGE_LAYOUT_PREV CONTROL_INDEX_HOT_CHANGE_LAYOUT_PREV \
            CONTROL_INDEX_HOLD_FAST_FORWARD CONTROL_INDEX_HOT_TOGGLE_SHOW_FRAME_COUNTER; do
            run grep -q "^controls_b\[$key\] = " "$config"
            [ "$status" -eq 0 ]
        done
    done
}

@test "setting a config key rewrites only that key" {
    fake_pak tg5040 brick

    before="$(wc -l <"$EMU_DIR/config/drastic.cfg")"
    orientation="$(config_value screen_orientation)"
    nds_config_set "$EMU_DIR/config/drastic.cfg" frame_interval 47619

    [ "$(config_value frame_interval)" = "47619" ]
    [ "$(config_value screen_orientation)" = "$orientation" ]
    [ "$(wc -l <"$EMU_DIR/config/drastic.cfg")" = "$before" ]
}

@test "setting a config key does not add one that is absent" {
    fake_pak tg5040 brick

    nds_config_set "$EMU_DIR/config/drastic.cfg" not_a_real_key 1

    run grep -q not_a_real_key "$EMU_DIR/config/drastic.cfg"
    [ "$status" -ne 0 ]
}

@test "the cpu policy directory prefers policy0" {
    policy="$BATS_TEST_TMPDIR/policy0"
    percpu="$BATS_TEST_TMPDIR/cpu0"
    mkdir -p "$policy" "$percpu"
    echo "1008000 1200000" >"$policy/scaling_available_frequencies"
    echo "1008000 1200000" >"$percpu/scaling_available_frequencies"
    NDS_CPU_POLICY_DIRS="$policy $percpu"

    [ "$(nds_cpu_policy_dir)" = "$policy" ]
}

@test "the cpu policy directory falls back to the per cpu path" {
    policy="$BATS_TEST_TMPDIR/policy0"
    percpu="$BATS_TEST_TMPDIR/cpu0"
    mkdir -p "$policy" "$percpu"
    echo "1008000 1200000" >"$percpu/scaling_available_frequencies"
    NDS_CPU_POLICY_DIRS="$policy $percpu"

    [ "$(nds_cpu_policy_dir)" = "$percpu" ]
}

@test "the cpu policy directory is empty when cpufreq is unavailable" {
    NDS_CPU_POLICY_DIRS="$BATS_TEST_TMPDIR/missing"

    [ -z "$(nds_cpu_policy_dir)" ]
}

@test "cpu settings survive a save and restore round trip" {
    fake_pak tg5040 brick
    CPU_POLICY_DIR="$BATS_TEST_TMPDIR/policy0"
    mkdir -p "$CPU_POLICY_DIR"
    echo "1008000 1200000 1608000" >"$CPU_POLICY_DIR/scaling_available_frequencies"
    echo "schedutil" >"$CPU_POLICY_DIR/scaling_governor"
    echo "1008000" >"$CPU_POLICY_DIR/scaling_min_freq"
    echo "1200000" >"$CPU_POLICY_DIR/scaling_max_freq"

    nds_cpu_save_state
    nds_cpu_configure ondemand
    [ "$(cat "$CPU_POLICY_DIR/scaling_governor")" = "ondemand" ]
    [ "$(cat "$CPU_POLICY_DIR/scaling_min_freq")" = "1008000" ]
    [ "$(cat "$CPU_POLICY_DIR/scaling_max_freq")" = "1608000" ]

    nds_cpu_restore_state
    [ "$(cat "$CPU_POLICY_DIR/scaling_governor")" = "schedutil" ]
    [ "$(cat "$CPU_POLICY_DIR/scaling_min_freq")" = "1008000" ]
    [ "$(cat "$CPU_POLICY_DIR/scaling_max_freq")" = "1200000" ]
    [ ! -f "$TEMP_SCALING_FILE" ]
}

@test "cpu save skips settings the kernel does not expose" {
    fake_pak tg5040 brick
    CPU_POLICY_DIR="$BATS_TEST_TMPDIR/policy0"
    mkdir -p "$CPU_POLICY_DIR"
    echo "schedutil" >"$CPU_POLICY_DIR/scaling_governor"

    run nds_cpu_save_state
    [ "$status" -eq 0 ]
    [ "$(cat "$TEMP_SCALING_FILE")" = "schedutil" ]
    [ ! -f "$TEMP_SCALING_MIN_FREQ" ]

    run nds_cpu_restore_state
    [ "$status" -eq 0 ]
}

@test "cpu state functions are inert without a policy directory" {
    fake_pak tg5040 brick
    CPU_POLICY_DIR=""

    run nds_cpu_save_state
    [ "$status" -eq 0 ]
    run nds_cpu_restore_state
    [ "$status" -eq 0 ]
}

@test "the performance governor leaves the minimum frequency alone" {
    fake_pak tg5040 brick
    CPU_POLICY_DIR="$BATS_TEST_TMPDIR/policy0"
    mkdir -p "$CPU_POLICY_DIR"
    echo "1008000 1200000 1608000" >"$CPU_POLICY_DIR/scaling_available_frequencies"
    echo "1200000" >"$CPU_POLICY_DIR/scaling_min_freq"

    nds_cpu_configure performance

    [ "$(cat "$CPU_POLICY_DIR/scaling_governor")" = "performance" ]
    [ "$(cat "$CPU_POLICY_DIR/scaling_min_freq")" = "1200000" ]
    [ "$(cat "$CPU_POLICY_DIR/scaling_max_freq")" = "1608000" ]
}

@test "an unknown governor is reported and changes nothing" {
    fake_pak tg5040 brick
    CPU_POLICY_DIR="$BATS_TEST_TMPDIR/policy0"
    mkdir -p "$CPU_POLICY_DIR"
    echo "1008000 1608000" >"$CPU_POLICY_DIR/scaling_available_frequencies"

    run nds_cpu_configure conservative
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unsupported governor: conservative"* ]]
    [ ! -f "$CPU_POLICY_DIR/scaling_governor" ]
}

@test "cpu tuning is skipped without a policy directory" {
    CPU_POLICY_DIR=""

    run nds_cpu_configure ondemand
    [ "$status" -eq 0 ]
}

@test "the preferred frequency is the fastest one within the limit" {
    [ "$(nds_cpu_prefer_freq "408000 1008000 1608000 1800000")" = "1608000" ]
    [ "$(nds_cpu_prefer_freq "408000 1008000 1512000")" = "1512000" ]
}

@test "the preferred frequency falls back to the maximum when nothing qualifies" {
    [ "$(nds_cpu_prefer_freq "1800000 2000000")" = "2000000" ]
}

@test "the minimum frequency does not depend on list order" {
    [ "$(nds_cpu_min_freq "1800000 408000 1008000")" = "408000" ]
    [ "$(nds_cpu_min_freq "408000 1008000 1800000")" = "408000" ]
}

@test "a plain rom path is passed through untouched" {
    fake_pak tg5040 brick

    nds_resolve_rom_path "$SDCARD_PATH/Roms/NDS/Game.nds"

    [ "$NDS_ROM_PATH" = "$SDCARD_PATH/Roms/NDS/Game.nds" ]
    [ -z "$TEMP_ROM_DIR" ]
}

@test "a zipped rom is extracted and the nds inside it is returned" {
    fake_pak tg5040 brick
    command -v unzip >/dev/null || skip "unzip is not installed"
    mkdir -p "$PACK_DIR/bin"
    ln -sf "$(command -v unzip)" "$PACK_DIR/bin/unzip"

    mkdir -p "$SDCARD_PATH/Roms/NDS"
    (cd "$BATS_TEST_TMPDIR" && echo rom >Game.nds && zip -q Game.zip Game.nds)
    mv "$BATS_TEST_TMPDIR/Game.zip" "$SDCARD_PATH/Roms/NDS/Game.zip"

    TEMP_ROM_DIR=""
    nds_resolve_rom_path "$SDCARD_PATH/Roms/NDS/Game.zip"

    [ -n "$TEMP_ROM_DIR" ]
    [ "$NDS_ROM_PATH" = "$TEMP_ROM_DIR/Game.nds" ]
    rm -rf "$TEMP_ROM_DIR"
}

@test "an uppercase zip extension is still extracted" {
    fake_pak tg5040 brick
    command -v unzip >/dev/null || skip "unzip is not installed"
    mkdir -p "$PACK_DIR/bin"
    ln -sf "$(command -v unzip)" "$PACK_DIR/bin/unzip"

    mkdir -p "$SDCARD_PATH/Roms/NDS"
    (cd "$BATS_TEST_TMPDIR" && echo rom >Game.nds && zip -q Game.ZIP Game.nds)
    mv "$BATS_TEST_TMPDIR/Game.ZIP" "$SDCARD_PATH/Roms/NDS/Game.ZIP"

    TEMP_ROM_DIR=""
    nds_resolve_rom_path "$SDCARD_PATH/Roms/NDS/Game.ZIP"

    [ "$NDS_ROM_PATH" = "$TEMP_ROM_DIR/Game.nds" ]
    rm -rf "$TEMP_ROM_DIR"
}

@test "cheats are migrated out before the bind mount" {
    fake_pak tg5040 brick

    mkdir -p "$EMU_DIR/cheats" "$NDS_MINUI_CHEAT"
    echo cheat >"$EMU_DIR/cheats/Game.cht"
    nds_migrate_cheats

    [ -f "$NDS_MINUI_CHEAT/Game.cht" ]
    [ ! -f "$EMU_DIR/cheats/Game.cht" ]
}

@test "cheat migration is a no-op for an empty directory" {
    fake_pak tg5040 brick

    mkdir -p "$EMU_DIR/cheats" "$NDS_MINUI_CHEAT"
    run nds_migrate_cheats
    [ "$status" -eq 0 ]
}

@test "the bundled libraries come before the system ones" {
    fake_pak h700 rg40xxh
    export LD_LIBRARY_PATH="/system/lib"
    nds_init_env

    case "$LD_LIBRARY_PATH" in
    "$EMU_DIR/libs":*"/system/lib"*) ;;
    *) return 1 ;;
    esac
}

@test "alsa overrides are only exported on tg5040" {
    fake_pak h700 rg40xxh
    unset ALSA_CONFIG_PATH ALSA_ASOUNDRC

    run nds_buffer_size_patch
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unsupported platform: h700"* ]]

    fake_pak tg5040 brick
    nds_buffer_size_patch
    [ "$ALSA_CONFIG_PATH" = "$EMU_DIR/devices/trimui-brick/alsa/nds_alsa.conf" ]
    [ "$ALSA_ASOUNDRC" = "$EMU_DIR/devices/trimui-brick/alsa/.asoundrc" ]
}

@test "power control is started only on the platforms it supports" {
    PLATFORM="h700"
    run nds_start_power_control
    [ "$status" -eq 0 ]
    [[ "$output" == *"does not support h700"* ]]
}
