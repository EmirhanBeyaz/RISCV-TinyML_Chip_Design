# vivado_power_saif.tcl — Full implementation + XSim SAIF + annotated power report
#
# Usage:
#   vivado -mode batch -source soc/vivado_power_saif.tcl -tclargs <part>
#
# Example:
#   vivado -mode batch -source soc/vivado_power_saif.tcl -tclargs xc7a100tcsg324-1
#
# Output:
#   soc/build/vivado_power/reports/power_no_saif.rpt      (baseline)
#   soc/build/vivado_power/reports/power_with_saif.rpt     (annotated)
#   soc/build/vivado_power/reports/power_advisory.rpt
#   soc/build/vivado_power/reports/utilization.rpt
#   soc/build/vivado_power/reports/timing_summary.rpt
#   soc/build/vivado_power/reports/methodology.rpt
#   soc/build/vivado_power/reports/io.rpt
#   soc/build/vivado_power/reports/drc.rpt

if {$argc < 1} {
  puts "Usage: vivado -mode batch -source soc/vivado_power_saif.tcl -tclargs <part>"
  exit 1
}

set part [lindex $argv 0]
set script_dir [file normalize [file dirname [info script]]]
set out_dir    [file normalize [file join $script_dir build vivado_power]]
set report_dir [file join $out_dir reports]
set saif_file  [file join $out_dir activity.saif]

file mkdir $out_dir
file mkdir $report_dir

puts "=============================================="
puts " Vivado Power Analysis with SAIF Annotation"
puts "=============================================="
puts "Part           : $part"
puts "Output dir     : $out_dir"
puts ""

# =====================================================================
# PHASE 1: Implementation
# =====================================================================
puts "\n=== PHASE 1: Implementation ==="

create_project vivado_power_proj $out_dir -part $part -force
set target_top fpga_top_arty_a7
source [file join $script_dir vivado_gui_add_sources.tcl]

puts "Running synthesis..."
synth_design -top fpga_top_arty_a7 -part $part
write_checkpoint -force [file join $out_dir post_synth.dcp]
report_utilization -hierarchical -file [file join $report_dir utilization_synth.rpt]

puts "Running optimization..."
opt_design
puts "Running placement..."
place_design
puts "Running physical optimization..."
phys_opt_design
puts "Running routing..."
route_design

write_checkpoint -force [file join $out_dir post_route.dcp]

# Standard reports
report_utilization -hierarchical -file [file join $report_dir utilization.rpt]
report_timing_summary -file [file join $report_dir timing_summary.rpt]
report_timing -delay_type max -sort_by group -max_paths 20 -file [file join $report_dir setup_paths.rpt]
report_timing -delay_type min -sort_by group -max_paths 20 -file [file join $report_dir hold_paths.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_io -file [file join $report_dir io.rpt]

# Baseline power (no SAIF)
report_power -file [file join $report_dir power_no_saif.rpt]
puts "Phase 1 complete — baseline power report written."

# =====================================================================
# PHASE 2: XSim SAIF Generation
# =====================================================================
puts "\n=== PHASE 2: XSim SAIF Generation ==="

# Add testbench to sim fileset
set sim_tb [file join $script_dir tb_cv32e40p_axi_soc_real.sv]
add_files -fileset sim_1 -norecurse $sim_tb
set_property top tb_cv32e40p_axi_soc_real [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# XSim simulation properties
set_property -name {xsim.simulate.runtime} -value {20us} -objects [get_filesets sim_1]

update_compile_order -fileset sim_1

puts "Launching XSim simulation..."
launch_simulation

# Open SAIF and log all signals under DUT hierarchy
# The testbench instantiates the SoC as 'dut' (cv32e40p_axi_soc)
open_saif $saif_file
log_saif [get_objects -r /tb_cv32e40p_axi_soc_real/dut/*]

puts "Running simulation for 20us..."
run 20us
close_saif
puts "SAIF written to: $saif_file"

close_sim

# =====================================================================
# PHASE 3: SAIF Annotation + Annotated Power Report
# =====================================================================
puts "\n=== PHASE 3: SAIF Read-back + Power Report ==="

# Re-open the routed checkpoint
open_checkpoint [file join $out_dir post_route.dcp]

# Read SAIF — map testbench DUT path to implementation hierarchy
# TB: /tb_cv32e40p_axi_soc_real/dut  (cv32e40p_axi_soc)
# Impl: fpga_top_arty_a7/fpga_top_i/soc_i  (cv32e40p_axi_soc instance)
puts "Reading SAIF with strip_path mapping..."
if {[catch {
  read_saif $saif_file -strip_path tb_cv32e40p_axi_soc_real/dut -verbose
} msg]} {
  puts "WARNING: read_saif with strip_path mapping failed: $msg"
  puts "Trying without strip_path..."
  catch { read_saif $saif_file -verbose }
}

# Set realistic I/O switching activity for ports not covered by SAIF
# This raises I/O confidence from Low to Medium/High
proc set_activity_safe {sp tr objects} {
  if {[llength $objects] > 0} {
    set_switching_activity -static_probability $sp -toggle_rate $tr $objects
  }
}

# Clock-related: already covered by clock constraints
# Reset: btn[0] is idle-low, no toggle in steady state
set_activity_safe 0.0 0.0 [get_ports -quiet {btn[0]}]

# Buttons: idle, no toggle
set_activity_safe 0.0 0.0 [get_ports -quiet {btn[1] btn[2] btn[3]}]

# Switches: static position, no toggle
set_activity_safe 0.5 0.0 [get_ports -quiet {sw[0] sw[1] sw[2] sw[3]}]

# UART RX: idle-high, realistic baud-rate toggle
# 115200 baud at 50MHz ≈ 0.23% toggle rate ≈ 0.23 transitions/100 clocks
set_activity_safe 0.9 0.46 [get_ports -quiet {uart_rxd_out}]

# UART1 RX (ja0_i): idle-high, similar activity for AI data loading
set_activity_safe 0.9 0.46 [get_ports -quiet {ja0_i}]

# I2C: idle-high (pulled up), occasional toggle for sensor polling
# static_probability must be <= 1 - toggle_rate/200. (1 - 0.1/200 = 0.9995)
set_activity_safe 0.99 0.1 [get_ports -quiet {ck_sda}]

# QSPI data: active during flash reads, moderate toggle
set_activity_safe 0.5 10.0 [get_ports -quiet {qspi_dq[0] qspi_dq[1] qspi_dq[2] qspi_dq[3]}]

# Mark QSPI boot-hold nets as deasserted in steady state
set qspi_boot_hold [get_nets -hierarchical -quiet -filter {NAME =~ *qspi_init_i/init_done_o_reg*}]
if {[llength $qspi_boot_hold] > 0} {
  set_activity_safe 0.0 0.0 $qspi_boot_hold
}

# Annotated power report
report_power -file [file join $report_dir power_with_saif.rpt]
report_power -advisory -file [file join $report_dir power_advisory.rpt]

# Hierarchical power breakdown (deep)
report_power -hierarchical_depth 5 -file [file join $report_dir power_hierarchy.rpt]

# =====================================================================
# PHASE 4: Verification — Check annotation coverage
# =====================================================================
puts "\n=== PHASE 4: Annotation Coverage Check ==="

proc check_block {path} {
  set nets [get_nets -hierarchical -quiet -filter "NAME =~ ${path}/*"]
  set count [llength $nets]
  if {$count == 0} {
    puts [format "  %-45s  NO NETS FOUND" $path]
    return
  }
  set annotated 0
  foreach n $nets {
    set tr [get_property TOGGLE_RATE $n]
    if {$tr > 0.0} { incr annotated }
  }
  set pct [expr {100.0 * $annotated / $count}]
  puts [format "  %-45s  nets=%4d  annotated=%4d  (%5.1f%%)" \
    $path $count $annotated $pct]
}

puts "Block-level switching annotation coverage:"
check_block "fpga_top_i/soc_i/core_i"
check_block "fpga_top_i/soc_i/imem_i"
check_block "fpga_top_i/soc_i/dmem_i"
check_block "fpga_top_i/soc_i/rom_i"
check_block "fpga_top_i/soc_i/uart0_i"
check_block "fpga_top_i/soc_i/uart1_i"
check_block "fpga_top_i/soc_i/ai_csr_i"
check_block "fpga_top_i/soc_i/ai_mem_i"
check_block "fpga_top_i/soc_i/ai_accel_i"
check_block "fpga_top_i/soc_i/qspi_xip_i"
check_block "fpga_top_i/ext_axi_ram_i"

puts "\n=============================================="
puts " DONE — All reports under: $report_dir"
puts "=============================================="
puts "Key reports:"
puts "  power_no_saif.rpt     — Baseline (before SAIF)"
puts "  power_with_saif.rpt   — Annotated (after SAIF)"
puts "  power_hierarchy.rpt   — Hierarchical breakdown"
puts "  power_advisory.rpt    — Vivado recommendations"
puts "=============================================="

exit 0
