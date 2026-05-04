import sys

def patch_saif(in_file, out_file):
    with open(in_file, 'r') as f:
        content = f.read()
    
    # Replace the top instance
    content = content.replace('(INSTANCE  tb_cv32e40p_axi_soc_real', '(INSTANCE  fpga_top_arty_a7', 1)
    # Replace dut with fpga_top_i and soc_i
    content = content.replace('(INSTANCE  dut', '(INSTANCE  fpga_top_i\n         (INSTANCE  soc_i', 1)
    
    # We added one level of hierarchy, so we need to add one closing parenthesis at the end
    # Find the last closing parenthesis
    content = content.rstrip() + '\n   )\n'
    
    with open(out_file, 'w') as f:
        f.write(content)

patch_saif('soc/build/vivado_power/activity.saif', 'soc/build/vivado_power/activity_patched_v2.saif')
print("Patched SAIF successfully.")
