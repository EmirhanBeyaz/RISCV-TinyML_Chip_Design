Source repo: `openhwgroup/core-v-mcu`
Source commit: `18cd273678a0c876bc0249128b10b2f358c43581`
Repository URL: `https://github.com/openhwgroup/core-v-mcu`

Copied blocks:
- `rtl/apb_gpio`
- `rtl/apb_timer_unit`
- `rtl/includes/pulp_soc_defines.svh`

Current local location:
- `soc/third_party/peripherals/rtl/apb_gpio`
- `soc/third_party/peripherals/rtl/apb_timer_unit`
- `soc/third_party/peripherals/rtl/includes/pulp_soc_defines.svh`

Notes:
- `apb_gpio.sv` defines module `apb_gpiov2`.
- `apb_gpiov2` depends on macros from `pulp_soc_defines.svh`.
- These are raw vendor copies. They are not integrated into the local SoC yet.
- `iverilog` does not accept the current upstream `apb_gpiov2` coding style without adaptation.
- `verilator` parses the files but reports multiple lint warnings on the upstream sources.
