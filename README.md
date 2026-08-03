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

- For Arch Linux, an [official AUR package](https://aur.archlinux.org/packages/catapult-dabdoob) is available.

### Mac OS (Beta)

 - You only need to disable gatekeeper for Dabdoob, or disable it altogether. Check this guide for more information: https://disable-gatekeeper.github.io/

## Building from Source

The native Windows helper module requires **CMake 3.14+**, a **C++ compiler supporting C++14 or later**, and Python 3.6+ to build.
Without the native helper module, Dabdoob will still run, but it will not be able to detect the work area of the screen on Windows, which may result in the launcher being partially off-screen on some monitors and the taskbar being hidden behind the launcher window. The native helper module is not required on Linux or macOS.

### Prerequisites

**All platforms:**
- CMake 3.14 or later: [Download here](https://cmake.org/download/)
- Python 3.6 or later: [Download here](https://www.python.org/downloads/)

**Windows:**
- Build tools for visual studio (MSVC) or MinGW-w64. The easiest way to get this is to install Visual Studio Community Edition with the "Desktop development with C++" workload.
  - [Download Visual Studio Community](https://visualstudio.microsoft.com/downloads/) (free)
    - Or via winget in terminal: `winget install Microsoft.VisualStudio.2022.Community`
  - Or just the [Build Tools for Visual Studio](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
  - Or via winget in terminal: `winget install Microsoft.VisualStudio.2022.BuildTools`
- Install CMake and Python via winget:
  ```powershell
  winget install Kitware.CMake
  winget install Python.Python.3.11
  # or if you want a whole Python distribution with conda, you can install Miniconda3:
  winget install Anaconda.Miniconda3
  ```

**Linux:**
- GCC 5.0+ or Clang 3.4+
  - **Debian/Ubuntu:** `sudo apt install build-essential cmake python3`
  - **Arch:** `sudo pacman -S base-devel cmake python`
  - **Fedora:** `sudo dnf install gcc gcc-c++ cmake python3`

**macOS:**
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew (optional but recommended): `brew install cmake python3`

### Build Instructions

```bash
# Navigate to the project root
cd /path/to/Catapult_Dabdoob

# Run the build script
py ./build.py
```

This will:
1. Create a `build/` directory with CMake configuration
2. Compile native helper modules (x64)
3. Output the DLL to `bin/Release/win32_helper.dll`

The compiled DLL will be automatically picked up by Godot when you run the project.

## System requirements

- 64-bit operating system.
- Windows 7+ or Linux.
- OpenGL 2.1 support.

## Can you include my mod/tileset/soundpack/etc?

Of course! Please check [Content_Request](Content_Request.md) for the requirements and what you need to do

## Contact

Feel free to create an issue on the Github. You can also find me on [TLG's Discord](https://discord.com/invite/zT9sXmZNCK)

## Contributing

Checkout [CONTRIBUTING.md](CONTRIBUTING.md).

