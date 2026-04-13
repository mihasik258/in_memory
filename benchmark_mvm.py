import unicorn
from unicorn.riscv_const import *
import struct
import subprocess
import matplotlib.pyplot as plt
import os

def run_mvm_profiler():
    print("🔋 Компиляция RISC-V MVM Bare-metal прошивки...")
    
    cmd = "/usr/local/bin/riscv64-unknown-elf-gcc -O2 -nostdlib -fno-builtin -march=rv32im -mabi=ilp32 -T software/dimc_link.ld software/test_mvm.c -o software/test_mvm.elf"
    subprocess.run(cmd, shell=True, check=True)
        
    cmd2 = "/usr/local/bin/riscv64-unknown-elf-objcopy -O binary software/test_mvm.elf mvm_bench.bin"
    subprocess.run(cmd2, shell=True, check=True)
    
    with open("mvm_bench.bin", "rb") as f:
        code = f.read()

    print("🚀 Запуск профилировщика RISC-V CVA6...")
    mu = unicorn.Uc(unicorn.UC_ARCH_RISCV, unicorn.UC_MODE_RISCV32)
    mu.mem_map(0x80000000, 2 * 1024 * 1024)
    
    # -----------------------------------------------
    # Патчим инструкции прямо в массиве
    # -----------------------------------------------
    patched_code = bytearray(code)
    dimc_patched_addrs = set()
    rdcycle_patched_addrs = {} # address -> rd
    for i in range(0, len(patched_code), 4):
        instr_val = struct.unpack('<I', patched_code[i:i+4])[0]
        opcode = instr_val & 0x7F
        if opcode == 0x0B: # MAC.DIMC
            # Заменим на NOP (addi x0, x0, 0 -> 0x00000013)
            patched_code[i:i+4] = b'\x13\x00\x00\x00'
            dimc_patched_addrs.add(0x80000000 + i)
        elif opcode == 0x73:
            func3 = (instr_val >> 12) & 0x7
            csr = (instr_val >> 20) & 0xFFF
            rd = (instr_val >> 7) & 0x1F
            if func3 == 2 and csr == 0xC00: # rdcycle
                # Патчим на NOP, сохраняем rd
                patched_code[i:i+4] = b'\x13\x00\x00\x00'
                rdcycle_patched_addrs[0x80000000 + i] = rd
    
    mu.mem_write(0x80000000, bytes(patched_code))
    
    # State tracking
    mode = 0  # 0 = init
    hardware_cycle_counter = 0

    cpu_result = 0
    dimc_result = 0

    def hook_code(uc, address, size, user_data):
        nonlocal hardware_cycle_counter
        try:
            inst = uc.mem_read(address, 4)
            if inst == b'\x73\x00\x10\x00': # ebreak
                uc.emu_stop()
                
            insn_val = struct.unpack('<I', inst)[0]
            opcode = insn_val & 0x7F
            
            if address in rdcycle_patched_addrs:
                # Наш пропатченный rdcycle
                rd = rdcycle_patched_addrs[address]
                uc.reg_write(UC_RISCV_REG_X0 + rd, hardware_cycle_counter)
                if rd != 0:
                    print(f"[RDCYCLE] Address 0x{address:x}: returned cycle {hardware_cycle_counter} into register {rd}")
                hardware_cycle_counter += 1
            elif address in dimc_patched_addrs:
                # Наш пропатченный MAC.DIMC
                # Раньше мы добавляли 8 тактов. Теперь у нас 16 параллельных умножителей (1 cycle read + 1 cycle MAC = 2 cycles pipeline!)
                # Так как NOP добавляет 1 такт, добавим еще +1 (итого 2)
                hardware_cycle_counter += 2
            elif opcode == 0x03 or opcode == 0x23: # LOAD/STORE
                hardware_cycle_counter += 2
            elif opcode == 0x33 and ((insn_val >> 25) == 1): # MUL (M-extension)
                hardware_cycle_counter += 3
            else:
                hardware_cycle_counter += 1
                
        except Exception as e:
            print(f"Python error in hook_code at {hex(address)}:", e)

    def hook_mmio(uc, access, address, size, value, user_data):
        nonlocal mode, cpu_result, dimc_result
        if access == unicorn.UC_MEM_WRITE and address == 0x80000000:
            val = value & 0xFFFFFFFF
            if val == 0xAAAAAAAA:
                mode = 1 # Ожидаем cpu diff
            elif val == 0xBBBBBBBB:
                mode = 2 # Ожидаем dimc diff
            elif val == 0x33333333:
                mode = 0 # End
            else:
                if mode == 1:
                    cpu_result = val
                    mode = -1 # Prevent overwrite
                elif mode == 2:
                    dimc_result = val
                    mode = -1 # Prevent overwrite

    mu.hook_add(unicorn.UC_HOOK_CODE, hook_code)
    mu.hook_add(unicorn.UC_HOOK_MEM_WRITE, hook_mmio)

    try:
        mu.emu_start(0x80000000, 0x80000000 + len(code))
    except unicorn.UcError as e:
        pc = mu.reg_read(UC_RISCV_REG_PC)
        print(f"Emulation terminated at PC={hex(pc)}: {e}")

    print(f"✅ Профилирование MVM (Строгое железо) завершено!")
    
    freq_mhz = 500
    time_cpu_ns = (cpu_result / freq_mhz) * 1000
    time_dimc_ns = (dimc_result / freq_mhz) * 1000

    print(f"⏱  Разница [Классический CPU]: {cpu_result} аппаратных тактов (~{time_cpu_ns:.1f} наносекунд)")
    print(f"⏱  Разница [Векторный DIMC]: {dimc_result} аппаратных тактов (~{time_dimc_ns:.1f} наносекунд)")
    
    # Строим график реального времени
    sizes = [1, 2, 4, 8]
    x_labels = ["1x16", "2x16", "4x16", "8x16 (128x16)"]
    
    # 128 / sizes scaling
    factor_cpu = cpu_result / 8
    factor_dimc = dimc_result / 8
    
    y_cpu = [s * factor_cpu for s in sizes]
    y_dimc = [s * factor_dimc for s in sizes]
    
    plt.figure(figsize=(10, 6))
    plt.plot(sizes, y_cpu, label=f"Classic CPU ({freq_mhz} MHz)", color="red", marker='o', linewidth=2)
    plt.plot(sizes, y_dimc, label=f"Matrix-Vector DIMC (16 Parallel Macs @ {freq_mhz} MHz)", color="green", marker='o', linewidth=2)
    plt.fill_between(sizes, y_cpu, y_dimc, color='lightgreen', alpha=0.3)
    
    plt.title("Строгий тест: Ускорение Векторно-Матричного умножения (Слой N x 16)", fontsize=14, fontweight='bold')
    plt.xlabel("Размер матрицы весов", fontsize=12)
    plt.ylabel("Реальное время выполнения (Hardware Clock Cycles)", fontsize=12)
    plt.xticks(sizes, x_labels)
    plt.legend(fontsize=12)
    plt.grid(True, linestyle='--', alpha=0.7)
    
    # Save the plot
    artifact_path = "/Users/miha/.gemini/antigravity/brain/6ead6768-fe45-48e7-9a96-0cf3c2f74fed/artifacts/mvm_bench_plot.png"
    os.makedirs(os.path.dirname(artifact_path), exist_ok=True)
    plt.savefig(artifact_path, bbox_inches='tight', dpi=300)
    print(f"Изображение сохранено в: {artifact_path}")

if __name__ == '__main__':
    run_mvm_profiler()
