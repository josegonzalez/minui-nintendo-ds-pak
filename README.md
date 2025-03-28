# minui-nintendo-ds-pak

A MinUI Emu Pak for Nintendo DS, wrapping the standalone Advanced Drastic Nintendo DS emulator (version 1.0.8).

## Requirements

This pak is designed and tested on the following MinUI Platforms and devices:

- `tg5040`: Trimui Brick (formerly `tg3040`)

Use the correct platform for your device.

## Installation

1. Mount your MinUI SD card.
2. Download the latest release from Github. It will be named `NDS.pak.zip`.
3. Copy the zip file to `/Emus/$PLATFORM/NDS.pak.zip`.
4. Extract the zip in place, then delete the zip file.
5. Confirm that there is a `/Emus/$PLATFORM/NDS.pak/launch.sh` file on your SD card.
6. Create a folder at `/Roms/Nintendo DS (NDS)` and place your roms in this directory.
7. Unmount your SD Card and insert it into your MinUI device.

## Key Controls

- L2: Toggle stylus / dpad
- R2: Swap screen0/1
- Menu: Call setting menu
- Select: Hot key
- Select + Left: Decrease layout index
- Select + Right: Increase layout index
- Select + Y: Change themes
- Select + B: Toggle blur / pixel mode
- Select + Start: Display steward custom settings
- Select + L: Quick load
- Select + R: Quick save

## Credits

- @trngaje for maintaining Advanced Drastic and related projects
- @karimlevallois for putting together the pak + adding Brick-specific styling
- anyone else I'm missing

## License

This project is based on DraStic, which is proprietary software. Please refer to the original DraStic license for more information on it's license.
