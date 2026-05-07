#!/bin/bash
# CV32E40P Jüri Canlı Demo Scripti
# Kullanım:
#   chmod +x juri_demo.sh
#   ./juri_demo.sh          # testleri çalıştırır, benchmark derler, özet üretir
#   ./juri_demo.sh waves    # VCD dosyalarını GTKWave ile açar
#   ./juri_demo.sh clean    # üretilen demo çıktılarını temizler
#
# Bu dosyayı proje kökünde çalıştır: ./soc ve ./cv32e40p klasörleri aynı dizinde olmalı.

set -u

ROOT="$(pwd)"
ART="$ROOT/presentation_artifacts"
LOG="$ART/logs"
WAVES="$ART/waves"
SW="$ROOT/soc/sw"
SUMMARY="$ART/juri_demo_summary.md"
PASS=0
FAIL=0

C0=""; CG=""; CR=""; CY=""; CB=""; CC=""
if [ -t 1 ]; then
  C0="\033[0m"; CG="\033[32m"; CR="\033[31m"; CY="\033[33m"; CB="\033[34m"; CC="\033[1m"
fi

banner(){ echo; echo -e "${CB}${CC}============================================================${C0}"; echo -e "${CB}${CC}$1${C0}"; echo -e "${CB}${CC}============================================================${C0}"; }
ok(){ echo -e "${CG}[PASS]${C0} $1"; PASS=$((PASS+1)); }
fail(){ echo -e "${CR}[FAIL]${C0} $1"; FAIL=$((FAIL+1)); }
info(){ echo -e "${CY}[INFO]${C0} $1"; }

prep(){ mkdir -p "$ART" "$LOG" "$WAVES" "$SW"; }
need_tool(){ command -v "$1" >/dev/null 2>&1 || { fail "Araç bulunamadı: $1"; return 1; }; }
need_file(){ [ -f "$1" ] || { fail "Dosya bulunamadı: $1"; return 1; }; }

clean(){
  rm -rf "$ART"
  rm -f sim_ai_csr.vvp sim_uart.vvp sim_irq_router.vvp sim_gpio.vvp
  rm -f ai_csr.vcd uart.vcd irq_router.vcd gpio.vcd
  rm -f ai_csr.gtkw uart.gtkw irq_router.gtkw gpio.gtkw
  rm -f "$SW/benchmark.elf" "$SW/benchmark.bin" "$SW/benchmark.hex" "$SW/benchmark_imem.hex" "$SW/benchmark_disasm.txt"
  echo "Temizlik tamamlandı."
}

make_gtkw(){
  banner "GTKWave düzen dosyaları hazırlanıyor"

cat > ai_csr.gtkw <<'GEOF'
[dumpfile] "ai_csr.vcd"
[timestart] 0
[size] 1400 800
[pos] -1 -1
[sst_width] 280
[signals_width] 260
@28
tb_ai_csr_icarus.clk
tb_ai_csr_icarus.rst_ni
@200
-
@28
tb_ai_csr_icarus.awvalid
tb_ai_csr_icarus.awready
tb_ai_csr_icarus.wvalid
tb_ai_csr_icarus.wready
tb_ai_csr_icarus.bvalid
tb_ai_csr_icarus.bready
@200
-
@28
tb_ai_csr_icarus.arvalid
tb_ai_csr_icarus.arready
tb_ai_csr_icarus.rvalid
tb_ai_csr_icarus.rready
@22
tb_ai_csr_icarus.rdata[31:0]
tb_ai_csr_icarus.rd[31:0]
@200
-
@28
tb_ai_csr_icarus.accel_start
tb_ai_csr_icarus.accel_done
tb_ai_csr_icarus.irq
@22
tb_ai_csr_icarus.input_base[31:0]
tb_ai_csr_icarus.input_len[31:0]
tb_ai_csr_icarus.output_base[31:0]
tb_ai_csr_icarus.uart_baud_div[15:0]
GEOF

cat > uart.gtkw <<'GEOF'
[dumpfile] "uart.vcd"
[timestart] 0
[size] 1400 800
[pos] -1 -1
[sst_width] 280
[signals_width] 260
@28
tb_uart_icarus.clk
tb_uart_icarus.rst_ni
@200
-
@28
tb_uart_icarus.awvalid
tb_uart_icarus.awready
tb_uart_icarus.wvalid
tb_uart_icarus.wready
tb_uart_icarus.bvalid
tb_uart_icarus.bready
@200
-
@28
tb_uart_icarus.arvalid
tb_uart_icarus.arready
tb_uart_icarus.rvalid
tb_uart_icarus.rready
@22
tb_uart_icarus.rdata[31:0]
tb_uart_icarus.rd[31:0]
@200
-
@28
tb_uart_icarus.uart_tx
tb_uart_icarus.uart_rx
@22
tb_uart_icarus.dut.baud_div_q[15:0]
tb_uart_icarus.dut.tx_data_q[7:0]
@28
tb_uart_icarus.dut.tx_enable_q
tb_uart_icarus.dut.rx_enable_q
tb_uart_icarus.dut.tx_we_q
tb_uart_icarus.dut.tx_full
tb_uart_icarus.dut.tx_empty
tb_uart_icarus.dut.rx_empty
GEOF

cat > gpio.gtkw <<'GEOF'
[dumpfile] "gpio.vcd"
[timestart] 0
[size] 1400 800
[pos] -1 -1
[sst_width] 280
[signals_width] 260
@28
tb_gpio_icarus.clk
tb_gpio_icarus.rst_ni
@200
-
@22
tb_gpio_icarus.paddr[11:0]
tb_gpio_icarus.pwdata[31:0]
@28
tb_gpio_icarus.pwrite
tb_gpio_icarus.psel
tb_gpio_icarus.penable
tb_gpio_icarus.pready
tb_gpio_icarus.pslverr
@22
tb_gpio_icarus.prdata[31:0]
tb_gpio_icarus.rd[31:0]
@200
-
@22
tb_gpio_icarus.gpio_in[31:0]
tb_gpio_icarus.gpio_in_sync[31:0]
tb_gpio_icarus.gpio_dir[31:0]
tb_gpio_icarus.gpio_out[31:0]
tb_gpio_icarus.gpio_irq[31:0]
GEOF

cat > irq_router.gtkw <<'GEOF'
[dumpfile] "irq_router.vcd"
[timestart] 0
[size] 1400 800
[pos] -1 -1
[sst_width] 280
[signals_width] 260
@22
tb_soc_irq_router.ext_irq[31:0]
tb_soc_irq_router.gpio_irq[31:0]
@28
tb_soc_irq_router.timer_irq_lo
tb_soc_irq_router.timer_irq_hi
tb_soc_irq_router.uart0_irq
tb_soc_irq_router.uart1_irq
tb_soc_irq_router.ai_irq
@200
-
@22
tb_soc_irq_router.local_irq[31:0]
tb_soc_irq_router.core_irq[31:0]
GEOF

  cp ai_csr.gtkw uart.gtkw gpio.gtkw irq_router.gtkw "$WAVES/" 2>/dev/null || true
  ok "GTKWave scriptleri oluşturuldu"
}

run_ai(){
  banner "1) AI CSR AXI-Lite + interrupt testi"
  need_file ./soc/soc_map_pkg.sv || return
  need_file ./soc/soc_ai_csr.sv || return
  need_file ./soc/tb_ai_csr_icarus.sv || return
  local l="$LOG/ai_csr.log"
  if iverilog -g2012 -o sim_ai_csr.vvp ./soc/soc_map_pkg.sv ./soc/soc_ai_csr.sv ./soc/tb_ai_csr_icarus.sv > "$l.compile" 2>&1 && vvp sim_ai_csr.vvp | tee "$l"; then
    grep -q "AI CSR TEST PASS" "$l" && ok "AI CSR: ID/base/length/baud, accel_start, accel_done ve irq doğrulandı" || fail "AI CSR PASS bulunamadı"
  else
    fail "AI CSR derleme veya simülasyon hatası"; cat "$l.compile" 2>/dev/null || true
  fi
}

run_uart(){
  banner "2) UART AXI-Lite TX testi"
  need_file ./soc/third_party/uart/rtl/uart/uart_tx.v || return
  need_file ./soc/third_party/uart/rtl/uart/uart_rx.v || return
  need_file ./soc/soc_axi_lite_uart.sv || return
  need_file ./soc/tb_uart_icarus.sv || return
  local l="$LOG/uart.log"
  if iverilog -g2012 -s tb_uart_icarus -o sim_uart.vvp \
      -I./soc/third_party/uart/rtl -I./soc/third_party/uart/rtl/uart \
      ./soc/third_party/uart/rtl/uart/uart_tx.v ./soc/third_party/uart/rtl/uart/uart_rx.v \
      ./soc/soc_axi_lite_uart.sv ./soc/tb_uart_icarus.sv > "$l.compile" 2>&1 && vvp sim_uart.vvp | tee "$l"; then
    grep -q "UART TEST PASS" "$l" && ok "UART: CTRL yazıldı, TXDATA=0x55 ile start/veri/idle frame doğrulandı" || fail "UART PASS bulunamadı"
  else
    fail "UART derleme veya simülasyon hatası"; cat "$l.compile" 2>/dev/null || true
  fi
}

run_irq(){
  banner "3) IRQ router testi"
  need_file ./soc/soc_map_pkg.sv || return
  need_file ./soc/soc_irq_router.sv || return
  need_file ./soc/tb_soc_irq_router.sv || return
  local l="$LOG/irq_router.log"
  if iverilog -g2012 -s tb_soc_irq_router -o sim_irq_router.vvp ./soc/soc_map_pkg.sv ./soc/soc_irq_router.sv ./soc/tb_soc_irq_router.sv > "$l.compile" 2>&1 && vvp sim_irq_router.vvp | tee "$l"; then
    grep -q "PASS" "$l" && ok "IRQ Router: timer/gpio/uart/ai interrupt bitleri core_irq hattına doğru taşındı" || fail "IRQ PASS bulunamadı"
  else
    fail "IRQ derleme veya simülasyon hatası"; cat "$l.compile" 2>/dev/null || true
  fi
}

run_gpio(){
  banner "4) GPIO APB register testi"
  need_file ./soc/third_party/peripherals/rtl/apb_gpio/rtl/apb_gpio.sv || return
  need_file ./soc/soc_apb_gpio.sv || return
  need_file ./soc/tb_gpio_icarus.sv || return
  local l="$LOG/gpio.log"
  if iverilog -g2012 -s tb_gpio_icarus -o sim_gpio.vvp \
      ./soc/third_party/peripherals/rtl/apb_gpio/rtl/apb_gpio.sv ./soc/soc_apb_gpio.sv ./soc/tb_gpio_icarus.sv > "$l.compile" 2>&1 && vvp sim_gpio.vvp | tee "$l"; then
    grep -q "GPIO TEST PASS" "$l" && ok "GPIO: PIN0, SETDIR, OUT0, SETGPIO, CLRGPIO ve readback doğrulandı" || fail "GPIO PASS bulunamadı"
  else
    fail "GPIO derleme veya simülasyon hatası"; cat "$l.compile" 2>/dev/null || true
  fi
}

ensure_sw_support(){
  if [ ! -s "$SW/startup.S" ]; then
cat > "$SW/startup.S" <<'EOF2'
.section .text.start
.global _start
_start:
    la sp, _stack_top
    la a0, _sidata
    la a1, _sdata
    la a2, _edata
1:
    bgeu a1, a2, 2f
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j 1b
2:
    la a0, _sbss
    la a1, _ebss
3:
    bgeu a0, a1, 4f
    sw zero, 0(a0)
    addi a0, a0, 4
    j 3b
4:
    call main
5:
    j 5b
EOF2
  fi

  if [ ! -s "$SW/linker.ld" ]; then
cat > "$SW/linker.ld" <<'EOF2'
ENTRY(_start)
MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00010000, LENGTH = 8K
  DMEM (rwx) : ORIGIN = 0x00020000, LENGTH = 8K
}
SECTIONS
{
  .text : {
    KEEP(*(.text.start))
    *(.text*)
    *(.rodata*)
    *(.srodata*)
  } > IMEM
  .data : AT (LOADADDR(.text) + SIZEOF(.text)) {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    *(.sdata*)
    . = ALIGN(4);
    _edata = .;
  } > DMEM
  _sidata = LOADADDR(.data);
  .bss : {
    . = ALIGN(4);
    _sbss = .;
    *(.bss*)
    *(.sbss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > DMEM
  . = ORIGIN(DMEM) + LENGTH(DMEM);
  _stack_top = .;
}
EOF2
  fi
}

build_sw(){
  banner "5) RISC-V FPU'suz fixed-point benchmark kanıtı"
  ensure_sw_support
  need_tool riscv64-unknown-elf-gcc || return
  need_tool riscv64-unknown-elf-objcopy || return
  need_tool riscv64-unknown-elf-objdump || return
  need_tool riscv64-unknown-elf-size || return
  need_tool python3 || return
  need_file "$SW/benchmark_main.c" || return

  if [ ! -s "$SW/benchmark_main.c" ]; then fail "benchmark_main.c boş"; return; fi
  if grep -n "float\|double" "$SW/benchmark_main.c" > "$LOG/float_double_check.txt"; then
    fail "benchmark_main.c içinde float/double bulundu"; cat "$LOG/float_double_check.txt"; return
  else
    ok "C benchmark içinde float/double yok"
  fi

  local l="$LOG/benchmark_build.log"
  if riscv64-unknown-elf-gcc -march=rv32imc_zicsr -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Os \
      -T "$SW/linker.ld" "$SW/startup.S" "$SW/benchmark_main.c" -lgcc -o "$SW/benchmark.elf" > "$l" 2>&1; then
    ok "benchmark.elf üretildi"
  else
    fail "RISC-V benchmark derlenemedi"; cat "$l"; return
  fi

  riscv64-unknown-elf-size "$SW/benchmark.elf" | tee "$LOG/benchmark_size.txt"
  riscv64-unknown-elf-objcopy -O binary "$SW/benchmark.elf" "$SW/benchmark.bin"
  local size; size=$(wc -c < "$SW/benchmark.bin")
  if [ "$size" -le 8192 ]; then ok "Benchmark IMEM'e sığıyor: ${size} byte / 8192 byte"; else fail "Benchmark IMEM'e sığmıyor: ${size} byte"; return; fi

  python3 - <<'PY'
from pathlib import Path
p=Path('./soc/sw/benchmark.bin')
o=Path('./soc/sw/benchmark_imem.hex')
data=p.read_bytes()
if len(data)>8192: raise SystemExit('IMEM overflow')
if len(data)%4: data += bytes(4-len(data)%4)
with o.open('w', encoding='utf-8') as f:
    for i in range(0,len(data),4):
        f.write(f"{int.from_bytes(data[i:i+4], 'little'):08x}\n")
print(f"[OK] {o} üretildi, word_count={len(data)//4}")
PY
  [ -s "$SW/benchmark_imem.hex" ] && ok "IMEM 32-bit word HEX hazır: soc/sw/benchmark_imem.hex" || { fail "benchmark_imem.hex üretilemedi"; return; }

  riscv64-unknown-elf-objdump -d "$SW/benchmark.elf" > "$SW/benchmark_disasm.txt"
  if grep -E "\b(flw|fsw|fadd|fsub|fmul|fdiv|fsqrt|fmadd|fmsub|fnmadd|fnmsub|fcvt|feq|flt|fle|fsgnj)\b" "$SW/benchmark_disasm.txt" > "$LOG/fpu_instruction_check.txt"; then
    fail "Objdump içinde FPU instruction bulundu"; cat "$LOG/fpu_instruction_check.txt"
  else
    ok "Objdump kontrolü: FPU instruction yok"
  fi

  echo "İlk 12 IMEM word:" | tee "$LOG/benchmark_imem_head.txt"
  head -12 "$SW/benchmark_imem.hex" | tee -a "$LOG/benchmark_imem_head.txt"
}

summary(){
  local bs="N/A" wc="N/A"
  [ -f "$SW/benchmark.bin" ] && bs=$(wc -c < "$SW/benchmark.bin")
  [ -f "$SW/benchmark_imem.hex" ] && wc=$(wc -l < "$SW/benchmark_imem.hex")
  cat > "$SUMMARY" <<EOF2
# AnkaRISC Jüri Canlı Demo Özeti

## Canlı demoda gösterilenler

| Test | Gösterilen kanıt | Sonuç |
|---|---|---|
| AI CSR | AXI-Lite register okuma/yazma, accel_start, irq set/clear | PASS beklenir |
| UART | CTRL ayarı ve TXDATA=0x55 ile uart_tx frame | PASS beklenir |
| IRQ Router | Timer/GPIO/UART/AI kaynaklarının core_irq bitlerine taşınması | PASS beklenir |
| GPIO | PIN0, SETDIR, OUT0, SETGPIO, CLRGPIO ve readback | PASS beklenir |
| RISC-V Benchmark | FPU'suz fixed-point/integer C kodu, ELF/BIN/IMEM HEX | PASS beklenir |

## Benchmark içeriği

- Taylor Q15 sin(x) seri açılımı
- 4x4 integer matris çarpımı
- 512 byte memory copy
- UART çıktı altyapısı
- GPIO LED durum göstergesi
- mcycle ile çevrim ölçümü altyapısı

## Yazılım çıktıları

- ELF: \`soc/sw/benchmark.elf\`
- BIN: \`soc/sw/benchmark.bin\`
- IMEM HEX: \`soc/sw/benchmark_imem.hex\`
- Binary boyutu: ${bs} byte
- IMEM word sayısı: ${wc}

## Sunum cümlesi

Bu demo ile yalnızca RTL dosyası değil; register seviyesi çevre birimi doğrulaması, interrupt yönlendirme, UART/GPIO haberleşmesi ve FPU bulunmayan RISC-V mikrodenetleyici üzerinde çalışacak fixed-point bare-metal benchmark akışı gösterilmektedir.
EOF2
  ok "Sunum özeti oluşturuldu: $SUMMARY"
}

copy_artifacts(){
  cp ai_csr.vcd uart.vcd irq_router.vcd gpio.vcd "$WAVES/" 2>/dev/null || true
  cp ai_csr.gtkw uart.gtkw irq_router.gtkw gpio.gtkw "$WAVES/" 2>/dev/null || true
}

waves(){
  unset GTK_PATH GIO_MODULE_DIR LD_LIBRARY_PATH
  make_gtkw >/dev/null
  command -v gtkwave >/dev/null 2>&1 || { fail "GTKWave yok. sudo apt install gtkwave"; exit 1; }
  [ -f ai_csr.vcd ] && gtkwave ai_csr.vcd ai_csr.gtkw &
  [ -f uart.vcd ] && gtkwave uart.vcd uart.gtkw &
  [ -f gpio.vcd ] && gtkwave gpio.vcd gpio.gtkw &
  [ -f irq_router.vcd ] && gtkwave irq_router.vcd irq_router.gtkw &
  echo "Waveformlar açılıyor."
}

report(){
  echo
  echo -e "${CC}==================== JÜRİ DEMO SONUCU ====================${C0}"
  echo -e "PASS: ${CG}${PASS}${C0}"
  echo -e "FAIL: ${CR}${FAIL}${C0}"
  echo "Loglar     : $LOG"
  echo "Waveformlar: $WAVES"
  echo "Özet       : $SUMMARY"
  echo
  if [ "$FAIL" -eq 0 ]; then
    echo -e "${CG}${CC}TÜM ANA DEMO ADIMLARI BAŞARILI.${C0}"
    echo "Waveform açmak için: ./juri_demo.sh waves"
  else
    echo -e "${CR}${CC}Bazı adımlar başarısız. Log klasörünü kontrol et.${C0}"
  fi
}

run_all(){
  prep
  banner "CD-ROM Mikrodenetleyici Jüri Canlı Demo Başlıyor"
  need_tool iverilog >/dev/null || true
  need_tool vvp >/dev/null || true
  run_ai
  run_uart
  run_irq
  run_gpio
  build_sw
  make_gtkw
  copy_artifacts
  summary
  report
}

case "${1:-all}" in
  all) run_all ;;
  waves) prep; waves ;;
  clean) clean ;;
  *) echo "Kullanım: ./juri_demo.sh | ./juri_demo.sh waves | ./juri_demo.sh clean"; exit 1 ;;
esac
