set out_dir soc/build/vivado_power
set report_dir soc/build/vivado_power/reports
set saif_file soc/build/vivado_power/activity.saif

open_checkpoint [file join $out_dir post_route.dcp]
read_saif $saif_file -strip_path tb_cv32e40p_axi_soc_real/dut -verbose

proc set_activity_safe {sp tr objects} {
  if {[llength $objects] > 0} {
    set_switching_activity -static_probability $sp -toggle_rate $tr $objects
  }
}

set_activity_safe 0.0 0.0 [get_ports -quiet {btn[0]}]
set_activity_safe 0.0 0.0 [get_ports -quiet {btn[1] btn[2] btn[3]}]
set_activity_safe 0.5 0.0 [get_ports -quiet {sw[0] sw[1] sw[2] sw[3]}]
set_activity_safe 0.9 0.46 [get_ports -quiet {uart_rxd_out}]
set_activity_safe 0.9 0.46 [get_ports -quiet {ja0_i}]
set_activity_safe 0.99 0.1 [get_ports -quiet {ck_sda}]
set_activity_safe 0.5 10.0 [get_ports -quiet {qspi_dq[0] qspi_dq[1] qspi_dq[2] qspi_dq[3]}]

set qspi_boot_hold [get_nets -hierarchical -quiet -filter {NAME =~ *qspi_init_i/init_done_o_reg*}]
if {[llength $qspi_boot_hold] > 0} {
  set_activity_safe 0.0 0.0 $qspi_boot_hold
}

report_power -file [file join $report_dir power_with_saif.rpt]
report_power -advisory -file [file join $report_dir power_advisory.rpt]
report_power -hierarchical_depth 5 -file [file join $report_dir power_hierarchy.rpt]

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
exit 0
