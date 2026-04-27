Source repository: `KASIRGA-KIZIL/tekno-kizil`
Source URL: `https://github.com/KASIRGA-KIZIL/tekno-kizil`
License: `GPL-3.0`
Imported commit: `6aa876ad8a199281e575545008aa1e55345532b3`

Vendored files:
- `rtl/tanimlamalar.vh`
- `rtl/uart/uart_tx.v`
- `rtl/uart/uart_rx.v`

Notes:
- The original project exposes these UART building blocks behind a Wishbone register block.
- This repo reuses only the UART TX/RX cores and wraps them with a local AXI-Lite register interface.
- `rtl/tanimlamalar.vh` is a compatibility stub because these UART files include it but do not consume shared defines.
