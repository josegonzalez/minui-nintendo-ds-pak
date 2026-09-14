# minui-nintendo-ds-pak

A MinUI Emu Pak for Nintendo DS, wrapping the standalone Advanced Drastic Nintendo DS emulator (version 1.0.8).

## Requirements

This pak is designed and tested on the following MinUI Platforms and devices:

- `tg5040`: Trimui Brick (formerly `tg3040`) and Trimui Smart Pro
- `tg5050`: Trimui Smart Pro S
- `h700`: Anbernic RG28XX, RG34XX, RG34XX SP, RG35XX Plus, RG35XX 2024, RG35XX H, RG35XX Pro, RG35XX SP, RG40XX H, RG40XX V, RG Cube XX and RG SP

Use the correct platform for your device. The `h700` and `tg5050` platforms are provided by NextUI, so those devices need NextUI rather than stock MinUI.

## Installation

1. Mount your MinUI SD card.
2. Download the latest release from Github. It will be named `NDS.pak.zip`.
3. Copy the zip file to `/Emus/$PLATFORM/NDS.pak.zip`.
4. Extract the zip in place, then delete the zip file.
5. Confirm that there is a `/Emus/$PLATFORM/NDS.pak/launch.sh` file on your SD card.
6. Create a folder at `/Roms/Nintendo DS (NDS)` and place your roms in this directory.
7. Unmount your SD Card and insert it into your MinUI device.

## Device Configuration

Advanced Drastic ships a separate configuration per device, and they differ in screen orientation and button mapping. On the first launch the pak picks the profile that matches your device and copies it into `drastic/config/`, then records the choice in `/.userdata/$PLATFORM/NDS-advanced-drastic/device.txt`. The previous configuration is kept alongside it as `drastic.cfg.bak`.

| Device | Profile |
| --- | --- |
| Trimui Brick, Trimui Brick Pro | `trimui-brick` |
| Trimui Smart Pro, Trimui Smart Pro S | `trimui-smart-pro` |
| RG28XX | `rg28xx` |
| RG35XX SP | `rg35xx-sp` |
| RG40XX V | `rg40xx-v` |
| RG Cube XX | `rg-cubexx` |
| RG34XX SP, RG35XX H, RG35XX Pro, RG40XX H | `rg40xx-h` |
| RG34XX, RG35XX Plus, RG35XX 2024, RG SP | `rg35xx-sp` |

Devices without a profile of their own use the closest one, chosen by whether the device has analog sticks.

Seeding only happens once per device, so any remapping done inside the Drastic settings menu is kept on later launches. Delete `device.txt` to have the profile applied again.

## Key Controls

- L2: Toggle stylus / dpad
- R2: Swap screen0/1
- Menu: Call setting menu
- Select: Hot key
- Select + Left: Decrease layout index
- Select + Right: Increase layout index
- Select + Y: Change themes
- Select + B: Toggle blur / pixel mode
- Select + Start: Display steward custom settings (Trimui Brick only)
- Select + L: Quick load
- Select + R: Quick save

## Deep Sleep & Shutdown

Deep sleep is supported on compatible devices. Click the power button to enter deep sleep. Click again to resume the game. To shut down, hold the power button for 2 seconds. **Note:** Shutdown does not save or resume the game and any unsaved progress will be lost. For more information and issues, see [MinUI Power Control](https://github.com/ben16w/minui-power-control).

MinUI Power Control does not support `h700` yet, so the power button keeps its default behaviour on those devices.

## Saves & States

- Save states are stored in the `/.userdata/shared/NDS-advanced-drastic/` directory.
- Game saves are stored in the `/Saves/NDS/` directory.

## Development

- `make build` downloads the bundled binaries into `bin/`.
- `make lint` runs shellcheck against `launch.sh`.
- `make test` runs the [bats](https://github.com/bats-core/bats-core) suite in `test/`.
- `make release` produces `dist/NDS.pak.zip`.

## Credits

- @trngaje for maintaining Advanced Drastic and related projects
- @karimlevallois for putting together the pak + adding Brick-specific styling
- anyone else I'm missing

## License

This project is based on DraStic, which is proprietary software. Please refer to the original DraStic license for more information on it's license.
