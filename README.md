# Dabdoob

**Dabdoob** is a cross-platform launcher and content manager for [Cataclysm: Dark Days Ahead](https://github.com/CleverRaven/Cataclysm-DDA) and its forks, such as [Cataclysm: The Last Generation](https://github.com/Cataclysm-TLG/Cataclysm-TLG/) and [Cataclysm: Bright Nights](https://github.com/cataclysmbnteam/Cataclysm-BN). It is based on [qrrk's Catapult launcher](https://github.com/qrrk/Catapult) to resume its development and to create the "perfect" launcher that does everything you could hope for.

[**Download latest release**](https://github.com/Hihahahalol/Catapult_Dabdoob/releases/latest)  |  [**See all releases**](https://github.com/Hihahahalol/Catapult_Dabdoob/releases)



![Dabdoob UI](./.github/Dabdoob_ui.gif)

## Features

- Automatic game download and installation (stable or experimental releases).
- Ability to install multiple versions of the game and switch between them.
- Updating the game while preserving user data (saved games, settings, mods, etc).
- Mod management: Select and download from our list of mods that are verified to be working for the version of Cataclysm you selected.
- Automatic download and installation of soundpacks and tilesets.
- Customization of game fonts.
- Automatic and manual saved game backups (30 times faster than Catapult too!).
- Multilingual interface.
- Fully portable and can be carried on a removable drive.
- Good support for HiDPI displays: UI is automatically scaled with screen DPI, with ability to adjust the scale manually.

## Installation

None required. The launcher is a single, self-contained executable. Just [download](https://github.com/Hihahahalol/Catapult_TLG/releases/latest) it to a separate folder and run.

### Linux
- You need write permission in the folder that contains the Dabdoob executable.
- The Dabdoob executable [should have execution permission enabled](https://askubuntu.com/a/485001).
- The game needs the following dependencies, Some distros come with these preinstalled, but others don't.: `sdl2`, `sdl2_image`, `sdl2_ttf`, `sdl2_mixer`, `freetype2`, `zip`
    - On Debian based distros (Ubuntu, Mint, etc.): `sudo apt install libsdl2-image libsdl2-ttf libsdl2-mixer libfreetype6 zip`
    - On Arch based distros `sudo pacman -S sdl2 sdl2_image sdl2_ttf sdl2_mixer zip`
    - On Fedora based distros `sudo dnf install SDL2 SDL2_image SDL2_ttf SDL2_mixer freetype zip`

#### Packaging

- For Arch Linux, an [official AUR package](https://aur.archlinux.org/packages/catapult-bin) is available.

### Mac OS (Will be available in a few days)

 - You only need to disable gatekeeper for Dabdoob, or disable it altogether. Check this guide for more information: https://disable-gatekeeper.github.io/

## System requirements

- 64-bit operating system.
- Windows 7+ or Linux.
- OpenGL 2.1 support.

## Can you include my mod/tileset/soundpack/etc?

Of course! Please check [Content_Request](Content_Request.md) for the requirements and what you need to do

## Contact

Feel free to create an issue on the Github. You can also find me on [TLG's Discord](https://discord.com/invite/zT9sXmZNCK)

## Contributing

While this will likely change, for the time being, the launcher is solo maintained by me. Consider buying me a [ko-fi](https://ko-fi.com/hihahahalol)

