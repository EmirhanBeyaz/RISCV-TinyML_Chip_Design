Source repository: `ZipCPU/qspiflash`
Repository URL: `https://github.com/ZipCPU/qspiflash`
Selected commit: `f0a3d2ac4c0e2d4bd2a7847bc0df24bb3a7c11ad`
License: `LGPL-3.0`

Selected upstream files for the first integration phase:
- `rtl/qflexpress.v`
- `autodata/qflexpress.txt`
- `sw/flashdrvr.cpp`
- `README.md`

Current local destination:
- `soc/third_party/qspi_xip/rtl/qflexpress.v`
- `soc/third_party/qspi_xip/autodata/qflexpress.txt`
- `soc/third_party/qspi_xip/reference/flashdrvr.cpp`

Why this set:
- `qflexpress.v` is the actual Quad SPI flash RTL core.
- `qflexpress.txt` documents the intended system-level integration and parameter defaults.
- `flashdrvr.cpp` documents the raw control command encoding used by the core.
- `README.md` captures the upstream role and license context.

Notes:
- The first hardware integration target is `XIP read + boot-copy`.
- Direct erase/program control through `qspi_cfg` is intentionally deferred.
- A local wrapper layer will isolate the SoC from the upstream Wishbone-style interface.
