#include <stdint.h>

#define DEBUG_PORT 0x80000000
volatile uint32_t* const DEBUG = (uint32_t*) DEBUG_PORT;

// Заставляем GCC сгенерировать 32-битный аппаратный байт-код кастомной инструкции MAC_DIMC (R-Type)
// opcode = CUSTOM_0 (0x0B), funct3 = 0, funct7 = 0
#define vmac_dimc(rd, rs1, rs2) \
    __asm__ volatile (".insn r CUSTOM_0, 0, 0, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

// Bare-metal точка входа
void __attribute__((section(".text._start"))) _start() {
    __asm__ volatile (
        "li sp, 0x80100000\n"  // Инициализируем стек в DRAM
        "call main\n"
        "ebreak\n"             // Остановка симулятора
    );
}

// Аппаратный тензорный Dot-Product используя архитектуру Bit-Serial DIMC через CV-X-IF
int32_t execute_tensor_mac(const int8_t* activations, int length) {
    int32_t result = 0;
    for (int addr = 0; addr < length; addr++) {
        int8_t act = activations[addr];
        if (act != 0) {
            // КОМПИЛЯТОР ВСТАВИТ ОДНУ АППАРАТНУЮ ИНСТРУКЦИЮ (Задержка шины: 0 тактов)
            vmac_dimc(result, act, addr);
        }
    }
    return result;
}

int main() {
    // В памяти весов (weights.mem):
    // W[0] = -128, W[1] = 127, W[2] = -1, W[3] = 0
    
    // Входной вектор активаций (rs1)
    int8_t local_activations[4] = {2, -3, 127, -128};

    // Ожидаемый результат (Золотая модель):
    // (-128 * 2) + (127 * -3) + (-1 * 127) + (0 * -128) 
    // = -256 - 381 - 127 + 0 = -764
    
    int32_t hw_result = execute_tensor_mac(local_activations, 4);

    if (hw_result == -764) {
        *DEBUG = 0xAA0000AA; // Код успеха
    } else {
        *DEBUG = hw_result;  // Вывод ошибочного значения
    }

    while(1) {
        __asm__ volatile ("wfi"); // Режим глубокого сна на CVA6
    }
    
    return 0;
}
