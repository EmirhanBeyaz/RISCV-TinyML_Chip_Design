#!/bin/bash
set -e

rm -rf obj_dir verilator_soc_compile.log

verilator -sv --timing --binary \
  --top-module tb_soc_benchmark_icarus \
  -Wno-fatal \
  -Wno-DECLFILENAME \
  -Wno-UNUSEDSIGNAL \
  -Wno-UNDRIVEN \
  -Wno-WIDTH \
  -Wno-CASEINCOMPLETE \
  -Wno-UNOPTFLAT \
  -I./soc \
  -I./soc/include \
  -I./cv32e40p/rtl \
  -I./cv32e40p/rtl/include \
  -I./cv32e40p/rtl/vendor/pulp_platform_fpnew/src \
  -I./cv32e40p/rtl/vendor/pulp_platform_common_cells/include \
  -I./soc/third_party/uart/rtl \
  -I./soc/third_party/uart/rtl/uart \
  -I./soc/third_party/peripherals/rtl/apb_gpio/rtl \
  -f ./soc/verilator_soc_files_nofpu.f \
  2>&1 | tee verilator_soc_compile.log
