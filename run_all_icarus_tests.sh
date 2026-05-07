#!/bin/bash
set -e

echo "===================================="
echo " AI CSR TEST"
echo "===================================="
iverilog -g2012 -o sim_ai_csr.vvp \
  ./soc/soc_map_pkg.sv \
  ./soc/soc_ai_csr.sv \
  ./soc/tb_ai_csr_icarus.sv

vvp sim_ai_csr.vvp


echo ""
echo "===================================="
echo " UART TEST"
echo "===================================="
iverilog -g2012 -s tb_uart_icarus -o sim_uart.vvp \
  -I./soc/third_party/uart/rtl \
  -I./soc/third_party/uart/rtl/uart \
  ./soc/third_party/uart/rtl/uart/uart_tx.v \
  ./soc/third_party/uart/rtl/uart/uart_rx.v \
  ./soc/soc_axi_lite_uart.sv \
  ./soc/tb_uart_icarus.sv

vvp sim_uart.vvp


echo ""
echo "===================================="
echo " IRQ ROUTER TEST"
echo "===================================="
iverilog -g2012 -s tb_soc_irq_router -o sim_irq_router.vvp \
  ./soc/soc_map_pkg.sv \
  ./soc/soc_irq_router.sv \
  ./soc/tb_soc_irq_router.sv

vvp sim_irq_router.vvp


echo ""
echo "===================================="
echo " GPIO TEST"
echo "===================================="
iverilog -g2012 -s tb_gpio_icarus -o sim_gpio.vvp \
  ./soc/third_party/peripherals/rtl/apb_gpio/rtl/apb_gpio.sv \
  ./soc/soc_apb_gpio.sv \
  ./soc/tb_gpio_icarus.sv

vvp sim_gpio.vvp


echo ""
echo "===================================="
echo " ALL TESTS COMPLETED"
echo "===================================="
