# FPKG Mac Builder

A macOS app installed as `FPKG Mac Builder.app`.

This version converts game folders and `.ffpfsc` and `.exfat` images. Support for `.gp5` projects and `.ffpkg` and `.ffpfs` formats is planned for future versions. The engine is native `fpkg-cli (Kraken 7)`, integrated from [rdmrocha/fpkg-cli](https://github.com/rdmrocha/fpkg-cli); source files are never modified.

Documented test:

- 40/42 disk images were recognized by automatic analysis.
- Bendy and the Ink Machine was recognized, extracted, and converted.
- Output package: `results/FPKG-d14rvwvj/EP5519-PPSA27616_00-0983640666583317-A0100-V0100.pkg`.
- Full final verification: 10 checks passed, including PFS checksums, NAPS, internal files, and PlayGo CRC.
- The other two dumps had an obsolete collision resolver; the app still reads them with a diagnostic warning.

To use it, open FPKG Mac Builder, choose a supported source, choose a destination folder with enough free space, and click **Create and Verify PKG**. Version 1.0 includes fpkg-cli, the .NET 10 Apple Silicon runtime, LibProsperoPkg, and the `.ffpfsc` reader patch; separate Python or .NET installations are not required.

The destination needs enough space for temporary extraction and the final PKG. For very large games, a disk with at least twice the dump size is recommended.
