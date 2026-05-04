with open('soc/build/vivado_power/activity_patched.saif', 'r') as f:
    lines = f.readlines()
    count = 0
    for line in lines:
        if '(INSTANCE' in line or '(NET' in line:
            print(line.rstrip())
            count += 1
            if count > 20:
                break
