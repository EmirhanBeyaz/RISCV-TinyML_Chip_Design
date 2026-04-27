if {$argc < 1} {
  puts "Usage: vivado -mode batch -source soc/vivado_smoke.tcl -tclargs <part> ?rtl|ooc?"
  puts "Example: vivado -mode batch -source soc/vivado_smoke.tcl -tclargs xc7a35tcpg236-1 rtl"
  exit 1
}

set part [lindex $argv 0]
set mode "rtl"
if {$argc >= 2} {
  set mode [string tolower [lindex $argv 1]]
}

if {$mode ni {"rtl" "ooc"}} {
  puts "Unsupported mode '$mode'. Use 'rtl' or 'ooc'."
  exit 1
}

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]
set soc_dir    [file normalize $script_dir]
set core_dir   [file normalize [file join $repo_root cv32e40p]]
set core_rtl   [file normalize [file join $core_dir rtl]]
set manifest   [file normalize [file join $core_dir cv32e40p_manifest.flist]]

set out_dir    [file normalize [file join $soc_dir build vivado_smoke "${mode}_${part}"]]
file mkdir $out_dir
file mkdir [file join $out_dir reports]

proc norm_subst {text design_rtl_dir} {
  set replaced [string map [list "\${DESIGN_RTL_DIR}" $design_rtl_dir] $text]
  return [file normalize $replaced]
}

set include_dirs [list]
set cv32_files   [list]

set fh [open $manifest r]
while {[gets $fh line] >= 0} {
  set line [string trim $line]
  if {$line eq ""} {
    continue
  }
  if {[string match {//*} $line]} {
    continue
  }

  if {[string match "+incdir+*" $line]} {
    set inc_path [string range $line 8 end]
    lappend include_dirs [norm_subst $inc_path $core_rtl]
    continue
  }

  set file_path [norm_subst $line $core_rtl]
  if {[string match "*cv32e40p_tb_wrapper.sv" $file_path]} {
    continue
  }
  if {[string match "*cv32e40p_tracer_pkg.sv" $file_path]} {
    continue
  }
  if {[string match "*cv32e40p_sim_clock_gate.sv" $file_path]} {
    continue
  }
  lappend cv32_files $file_path
}
close $fh

lappend include_dirs \
  [file normalize [file join $soc_dir third_party uart rtl]] \
  [file normalize [file join $soc_dir third_party peripherals rtl includes]]

set soc_files [list \
  [file join $soc_dir cv32e40p_fpga_clock_gate.sv] \
  [file join $soc_dir soc_map_pkg.sv] \
  [file join $soc_dir soc_irq_router.sv] \
  [file join $soc_dir cv32e40p_obi_to_axi_lite.sv] \
  [file join $soc_dir soc_mem_sp.sv] \
  [file join $soc_dir soc_imem.sv] \
  [file join $soc_dir soc_axi_lite_imem.sv] \
  [file join $soc_dir soc_dmem.sv] \
  [file join $soc_dir soc_rom.sv] \
  [file join $soc_dir soc_boot_copy_xip.sv] \
  [file join $soc_dir soc_qspi_xip.sv] \
  [file join $soc_dir soc_axi_lite_qspi_xip.sv] \
  [file join $soc_dir soc_qspi_init_seq.sv] \
  [file join $soc_dir soc_qspi_cfg_mux.sv] \
  [file join $soc_dir soc_axi_lite_1x2.sv] \
  [file join $soc_dir soc_axi_lite_uart.sv] \
  [file join $soc_dir soc_axi_lite_apb_island.sv] \
  [file join $soc_dir soc_apb_qspi_cfg.sv] \
  [file join $soc_dir soc_apb_gpio.sv] \
  [file join $soc_dir soc_apb_i2c_master.sv] \
  [file join $soc_dir soc_apb_timer.sv] \
  [file join $soc_dir third_party uart rtl uart uart_tx.v] \
  [file join $soc_dir third_party uart rtl uart uart_rx.v] \
  [file join $soc_dir third_party peripherals rtl apb_gpio rtl apb_gpio.sv] \
  [file join $soc_dir third_party peripherals rtl apb_timer_unit rtl apb_timer_unit.sv] \
  [file join $soc_dir third_party peripherals rtl apb_timer_unit rtl timer_unit.sv] \
  [file join $soc_dir third_party peripherals rtl apb_timer_unit rtl timer_unit_counter.sv] \
  [file join $soc_dir third_party peripherals rtl apb_timer_unit rtl timer_unit_counter_presc.sv] \
  [file join $soc_dir third_party qspi_xip rtl qflexpress.v] \
  [file join $soc_dir cv32e40p_axi_soc.sv] \
]

set all_files [concat $cv32_files $soc_files]
set all_files [lmap f $all_files {file normalize $f}]
set include_dirs [lsort -unique [lmap d $include_dirs {file normalize $d}]]

puts "Vivado smoke mode : $mode"
puts "Target part       : $part"
puts "RTL file count    : [llength $all_files]"
puts "Include dir count : [llength $include_dirs]"

create_project vivado_soc_smoke $out_dir -part $part -force
set_property target_language Verilog [current_project]
add_files -norecurse $all_files
set_property include_dirs $include_dirs [get_filesets sources_1]
update_compile_order -fileset sources_1

if {$mode eq "rtl"} {
  synth_design -rtl -top cv32e40p_axi_soc -part $part -name rtl_1
  puts "RTL elaboration completed."
} else {
  synth_design -mode out_of_context -top cv32e40p_axi_soc -part $part -flatten_hierarchy none
  report_utilization -hierarchical -file [file join $out_dir reports utilization_ooc.rpt]
  report_timing_summary -no_header -no_detailed_paths -file [file join $out_dir reports timing_ooc.rpt]
  write_checkpoint -force [file join $out_dir cv32e40p_axi_soc_ooc.dcp]
  puts "Out-of-context synthesis completed."
}

puts "Artifacts written under: $out_dir"
exit 0
