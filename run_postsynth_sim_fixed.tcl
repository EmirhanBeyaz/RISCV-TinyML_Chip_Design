set out_dir soc/build/vivado_power
set report_dir soc/build/vivado_power/reports

puts "Setting up simulation..."
create_project -force sim_proj soc/build/vivado_power/sim_proj -part xc7a100tcsg324-1

# Add testbench and its package dependencies
add_files -fileset sim_1 -norecurse soc/rtl/soc_map_pkg.sv
add_files -fileset sim_1 -norecurse soc/tb_cv32e40p_axi_soc_real.sv

# Add the post-synthesis netlist
add_files -fileset sim_1 -norecurse [file join $out_dir post_synth_netlist.v]

set_property top tb_cv32e40p_axi_soc_real [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Need to tell Vivado where the SV include directories are for the testbench
set_property include_dirs {soc/rtl} [get_filesets sim_1]

set_property target_simulator XSim [current_project]
set_property -name {xsim.simulate.runtime} -value {20us} -objects [get_filesets sim_1]
set_property delay_based_simulation 1 [get_filesets sim_1]

update_compile_order -fileset sim_1

puts "Launching post-synth simulation..."
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
# Use -strip_path to map the testbench DUT to the fpga_top_i/soc_i hierarchy?
# WAIT! In the post-synthesis netlist, the top module is fpga_top_arty_a7.
# The testbench instantiates cv32e40p_axi_soc as 'dut'.
# BUT cv32e40p_axi_soc does not exist in the netlist as a top module! The top module in the netlist is fpga_top_arty_a7.
# SO tb_cv32e40p_axi_soc_real WILL FAIL TO ELABORATE because it instantiates 'cv32e40p_axi_soc', which is a submodule, not the root of the netlist!
