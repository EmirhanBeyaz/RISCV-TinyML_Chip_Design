Source repository: `ZipCPU/qspiflash`
Repository URL: `https://github.com/ZipCPU/qspiflash`
Imported commit: `f0a3d2ac4c0e2d4bd2a7847bc0df24bb3a7c11ad`
License: `LGPL-3.0`

Vendored files:
- `rtl/qflexpress.v`
- `autodata/qflexpress.txt`
- `sw/flashdrvr.cpp`
- `README.md`

Notes:
- `qflexpress.v` is the selected Quad-SPI/XIP-capable upstream RTL core.
- This repo currently uses it through local wrappers:
  - `soc_qspi_xip.sv`
  - `soc_axi_lite_qspi_xip.sv`
- The first integration target is `read/XIP + boot-copy`.
- Full flash erase/program control through the local `qspi_cfg` block is intentionally deferred to a later phase.
- The local vendored `qflexpress.v` copy contains a minimal parser-compatibility patch:
  - internal `localparam` declarations were moved out of the module parameter list
  - the trailing comma after `OPT_STARTUP_FILE` was removed
