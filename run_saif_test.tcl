open_checkpoint soc/build/vivado_power/post_route.dcp
set saif_file soc/build/vivado_power/activity.saif

puts "TEST 1: strip_path tb_cv32e40p_axi_soc_real/dut"
catch { read_saif $saif_file -strip_path tb_cv32e40p_axi_soc_real/dut }

puts "TEST 2: strip_path tb_cv32e40p_axi_soc_real"
catch { read_saif $saif_file -strip_path tb_cv32e40p_axi_soc_real }

puts "TEST 3: no strip path"
catch { read_saif $saif_file }

exit 0
