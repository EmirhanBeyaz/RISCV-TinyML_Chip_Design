#!/bin/bash

unset GTK_PATH
unset GIO_MODULE_DIR
unset LD_LIBRARY_PATH

echo "[INFO] AI CSR waveform aciliyor..."
gtkwave ai_csr.vcd ai_csr.gtkw &

echo "[INFO] UART waveform aciliyor..."
gtkwave uart.vcd uart.gtkw &

echo "[INFO] GPIO waveform aciliyor..."
gtkwave gpio.vcd gpio.gtkw &

echo "[INFO] IRQ Router waveform aciliyor..."
gtkwave irq_router.vcd irq_router.gtkw &
