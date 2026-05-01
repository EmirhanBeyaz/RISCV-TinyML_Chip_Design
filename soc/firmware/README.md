# Firmware Notes

Bu klasor, henuz build sistemine baglanmamis firmware referans notlari ve
pseudocode dosyalari icindir.

Mevcut dosyalar:

- `ai_demo_flow.c`: AI demo firmware akisini C-benzeri sekilde gosterir.

Gercek firmware fazinda beklenenler:

- RISC-V toolchain secimi
- linker script
- startup code
- UART0/UART1 driver
- AI CSR/MEM driver
- IRQ handler
- ROM/QSPI boot image paketleme
