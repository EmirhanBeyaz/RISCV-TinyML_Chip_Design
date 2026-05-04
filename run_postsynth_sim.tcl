set out_dir soc/build/vivado_power
set report_dir soc/build/vivado_power/reports

open_checkpoint [file join $out_dir post_synth.dcp]
puts "Writing post-synthesis functional netlist..."
write_verilog -force -mode funcsim [file join $out_dir post_synth_netlist.v]

puts "Setting up simulation..."
# Create a new project just for sim to avoid cluttering the current state
create_project -force sim_proj soc/build/vivado_power/sim_proj -part xc7a100tcsg324-1
add_files -fileset sim_1 -norecurse [file join $out_dir post_synth_netlist.v]
add_files -fileset sim_1 -norecurse soc/tb_cv32e40p_axi_soc_real.sv

set_property top tb_cv32e40p_axi_soc_real [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Set sim properties to post-synthesis
set_property target_simulator XSim [current_project]
set_property -name {xsim.simulate.runtime} -value {20us} -objects [get_filesets sim_1]

update_compile_order -fileset sim_1

puts "Launching post-synth simulation..."
# We must include the glbl module for post-synth sim
set_property delay_based_simulation 1 [get_filesets sim_1]

launch_simulation -mode post-synthesis -type functional

set saif_file [file join $out_dir activity_postsynth.saif]
open_saif $saif_file
log_saif [get_objects -r /tb_cv32e40p_axi_soc_real/dut/*]
run 20us
close_saif
close_sim

close_project

puts "Re-opening routed design for power annotation..."
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

report_power -file [file join $report_dir power_postsynth_saif.rpt]

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
exit 0
