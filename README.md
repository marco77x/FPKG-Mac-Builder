# FPKG Mac Builder

FPKG Mac Builder is a macOS Apple Silicon application for creating verified debug `.pkg` packages from PS5 game images and folders.

The engine is `fpkg-cli` with BuiltIn Kraken level 7 compression. The current interface accepts game folders and `.ffpfsc` and `.exfat` images. Interface support for `.gp5` projects and `.ffpkg` and `.ffpfs` formats is planned for future versions. `.ffpfsc` containers are read in streaming mode through the virtual-source support.

## Status

Build 1.0 has been verified with real PS5 game images: icon, Content ID, Title ID, version, image mode, and size are read correctly. The direct backend was verified by creating and fully checking a Kraken 7 PKG.

## Local build

The project requires macOS 14 or later on Apple Silicon. The release includes the required runtimes and the license texts for distributed components.

The GUI is in [`mac-app/Main.swift`](mac-app/Main.swift), the coordinator is in [`mac-app/bridge.py`](mac-app/bridge.py), and the backend launcher is in [`mac-app/fpkg-direct-launcher`](mac-app/fpkg-direct-launcher).

## Licenses and distribution

`fpkg-cli` is a separate project by [rdmrocha/fpkg-cli](https://github.com/rdmrocha/fpkg-cli). The release distributes prebuilt components with their corresponding notices: LibProsperoPkg is GPL-3.0-or-later, while the .NET runtime and other components retain their own licenses and notices. When redistributing the `.app`, keep these files and make the corresponding source available for GPL components; official references are collected in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Complete builds are published as GitHub Release assets.
