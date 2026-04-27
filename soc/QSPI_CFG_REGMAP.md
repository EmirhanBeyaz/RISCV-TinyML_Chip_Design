# QSPI CFG Register Map

Base address: `SOC_QSPI_CFG_BASE_ADDR`

Registers:
- `0x000` `ID`
  `0x5153_5049` (`"QSPI"`)
- `0x004` `VERSION`
  Current version field.
- `0x008` `STATUS`
  Legacy summary view.
  - `bit0` `boot_active`
  - `bit1` `boot_done`
  - `bit2` `boot_enable`
  - `bit3` `flash_busy`
  - `bit4` `flash_init_done`
  - `bit5` `cfg_cmd_ready`
  - `bit6` `cfg_rsp_pending`
  - `bit7` `init_active`
  - `bit8` `init_done`
  - `bit9` `init_error`
- `0x00C` `COPY_WORDS`
  Boot-copy word count.
- `0x010` `XIP_BASE`
  Local XIP window base address.
- `0x014` `IMEM_BASE`
  Local IMEM base address.
- `0x018` `SCRATCH0`
  Software scratch register.
- `0x01C` `SCRATCH1`
  Software scratch register.
- `0x020` `CFG_CMD`
  Raw `qflexpress` config command write port.
- `0x024` `CFG_RSP`
  Last software-visible config response.
- `0x028` `FLASH_STATUS`
  Focused flash/config handshake view.
  - `bit0` `flash_busy`
  - `bit1` `flash_init_done`
  - `bit2` `cfg_cmd_ready`
  - `bit3` `cfg_rsp_pending`
- `0x02C` `INIT_STATUS`
  QSPI init sequencer state.
  - `bit0` `init_active`
  - `bit1` `init_done`
  - `bit2` `init_error`
  - `bits[15:8]` `init_error_code`
  - `bits[23:16]` `init_step_index`
- `0x030` `INIT_LAST_RSP`
  Last response captured by the init sequencer.
- `0x034` `LAST_CFG_CMD`
  Last software command accepted through `CFG_CMD`.

Current init error codes:
- `0x01`: command handshake timeout
- `0x02`: response timeout
