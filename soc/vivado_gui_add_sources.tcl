if {[catch {current_project} project_name] || $project_name eq ""} {
  puts "ERROR: Open or create a Vivado project first, then run this script."
  return -code error
}

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]
set soc_dir    [file normalize $script_dir]
set core_dir   [file normalize [file join $repo_root cv32e40p]]
set core_rtl   [file normalize [file join $core_dir rtl]]
set manifest   [file normalize [file join $core_dir cv32e40p_manifest.flist]]
set ai_model_pkg [file normalize [file join $soc_dir build ai_model_tflm_micro_speech soc_ai_model_pkg.sv]]
set timing_xdc [file normalize [file join $soc_dir fpga_top_timing.xdc]]

# Default GUI top for FPGA-oriented Vivado checks.
# Change this back to "cv32e40p_axi_soc" only if you explicitly want the raw
# SoC top instead of the board-style wrapper.
set target_top fpga_top

# Optional official Micro Speech package mode.
# Usage in Tcl Console before sourcing this script:
#   set use_ai_model_pkg 1
#   source /path/to/soc/vivado_gui_add_sources.tcl
if {![info exists use_ai_model_pkg]} {
  set use_ai_model_pkg 0
}

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
  [file join $soc_dir soc_ai_mem.sv] \
  [file join $soc_dir soc_ai_uart_loader.sv] \
  [file join $soc_dir soc_ai_csr.sv] \
  [file join $soc_dir soc_ai_tinyconv_accel.sv] \
  [file join $soc_dir soc_axi_lite_1x2.sv] \
  [file join $soc_dir soc_axi_lite_uart.sv] \
  [file join $soc_dir soc_axi_lite_apb_island.sv] \
  [file join $soc_dir soc_apb_qspi_cfg.sv] \
  [file join $soc_dir soc_apb_gpio.sv] \
  [file join $soc_dir soc_apb_i2c_master.sv] \
  [file join $soc_dir soc_apb_timer.sv] \
  [file join $soc_dir axi_lite_ram.sv] \
  [file join $soc_dir fpga_top.sv] \
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

if {$use_ai_model_pkg} {
  if {![file exists $ai_model_pkg]} {
    puts "ERROR: AI model package not found: $ai_model_pkg"
    puts "Generate it first from repo root with:"
    puts "  make -C soc AI_PYTHON=../.venv/bin/python ai-model-tflm-export"
    return -code error
  }
  lappend soc_files $ai_model_pkg
}

set all_files [concat $cv32_files $soc_files]
set all_files [lsort -unique [lmap f $all_files {file normalize $f}]]
set include_dirs [lsort -unique [lmap d $include_dirs {file normalize $d}]]

set existing_files [list]
foreach f [get_files -of_objects [get_filesets sources_1]] {
  if {$f ne ""} {
    lappend existing_files [file normalize $f]
  }
}
set existing_files [lsort -unique $existing_files]

set files_to_add [list]
foreach f $all_files {
  if {[lsearch -exact $existing_files $f] < 0} {
    lappend files_to_add $f
  }
}

if {[llength $files_to_add] > 0} {
  add_files -fileset sources_1 -norecurse $files_to_add
}

if {[file exists $timing_xdc]} {
  set existing_xdc [list]
  foreach f [get_files -of_objects [get_filesets constrs_1]] {
    if {$f ne ""} {
      lappend existing_xdc [file normalize $f]
    }
  }
  if {[lsearch -exact [lsort -unique $existing_xdc] $timing_xdc] < 0} {
    add_files -fileset constrs_1 -norecurse $timing_xdc
  }
}

set_property include_dirs $include_dirs [get_filesets sources_1]
if {$use_ai_model_pkg} {
  set_property verilog_define {SOC_AI_USE_MODEL_PKG} [get_filesets sources_1]
}
set_property top $target_top [get_filesets sources_1]
set_property target_language Verilog [current_project]
update_compile_order -fileset sources_1

puts "Vivado GUI source import completed."
puts "Top module      : $target_top"
puts "AI model package: $use_ai_model_pkg"
puts "RTL file count  : [llength $all_files]"
puts "New files added : [llength $files_to_add]"
puts "Include dirs    : [llength $include_dirs]"
puts "Timing XDC      : $timing_xdc"
