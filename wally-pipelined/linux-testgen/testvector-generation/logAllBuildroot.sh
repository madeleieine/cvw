# Oftentimes this script runs so long you'll go to sleep.
# But you don't want the script to die when your computer goes to sleep.
# So consider invoking this with nohup (i.e. "nohup ./logAllBuildroot.sh")
# You can run "tail -f nohup.out" to see what would've
# outputted to the terminal if you didn't use nohup

customQemu="/courses/e190ax/qemu_sim/rv64_initrd/qemu_experimental/qemu/build/qemu-system-riscv64"
#customQemu="qemu-system-riscv64"
imageDir="../buildroot-image-output"
intermedDir="../linux-testvectors/intermediate-outputs"
outDir="../linux-testvectors"

# =========== Debug the Process ========== 
# Uncomment this version for GDB/QEMU debugging
# - Opens up GDB interactively
# - Logs raw QEMU output to qemu_output.txt
$customQemu -M virt -nographic -bios $imageDir/fw_jump.elf -kernel $imageDir/Image -append "root=/dev/vda ro" -initrd $imageDir/rootfs.cpio -s -S & riscv64-unknown-elf-gdb -x gdbinit_debug
#($customQemu -M virt -nographic -bios $imageDir/fw_jump.elf -kernel $imageDir/Image -append "root=/dev/vda ro" -initrd $imageDir/rootfs.cpio -d nochain,cpu,in_asm -serial /dev/null -singlestep -s -S 2> $intermedDir/qemu_output.txt) & riscv64-unknown-elf-gdb

# Uncomment this version to generate qemu_output.txt
# - Uses GDB script
# - Logs raw QEMU output to qemu_output.txt
#($customQemu -M virt -nographic -bios $imageDir/fw_jump.elf -kernel $imageDir/Image -append "root=/dev/vda ro" -initrd $imageDir/rootfs.cpio -d nochain,cpu,in_asm -serial /dev/null -singlestep -s -S 2> $intermedDir/qemu_output.txt) & riscv64-unknown-elf-gdb -x gdbinit_qemulog_debug

# Uncomment this version for parse_qemu.py debugging
# - Uses qemu_output.txt
# - Makes qemu_in_gdb_format.txt
# - Splits qemu_in_gdb_format.txt into chunks of 100,000 instrs
#cat $intermedDir/qemu_output.txt | ./parse_qemu.py >$intermedDir/qemu_in_gdb_format.txt
#cd $intermedDir
#split -d -l 5600000 ./qemu_in_gdb_format.txt --verbose
#cd ../../testvector-generation

# Uncomment this version for parse_gdb_output.py debugging
# - Uses qemu_in_gdb_format.txt
# - Makes testvectors
#cat $intermedDir/qemu_in_gdb_format.txt | ./parse_gdb_output.py "$outdir"

# =========== Just Do the Thing ========== 
# Uncomment this version for the whole thing 
# - Logs info needed by buildroot testbench
#($customQemu -M virt -nographic -bios $imageDir/fw_jump.elf -kernel $imageDir/Image -append "root=/dev/vda ro" -initrd $imageDir/rootfs.cpio -d nochain,cpu,in_asm -serial /dev/null -singlestep -s -S 2>&1 >/dev/null | ./parse_qemu.py | ./parse_gdb_output.py "$outdir") & riscv64-unknown-elf-gdb -x gdbinit_qemulog
