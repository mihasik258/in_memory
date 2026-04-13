#include <stdint.h>

#define DEBUG_PORT 0x80000000
volatile uint32_t* const DEBUG = (uint32_t*) DEBUG_PORT;

// Векторная инструкция MAC.DIMC (Считает сразу 16 столбцов-аккумуляторов!)
#define vmac_dimc(rd, act, addr) \
    __asm__ volatile (".insn r CUSTOM_0, 0, 0, %0, %1, %2" : "=r"(rd) : "r"(act), "r"(addr))

// Чтение аппаратного счетчика тактов процессора
static inline uint32_t read_cycle() {
    uint32_t cycle;
    // Используем счетчик rdcycle (доступен в user-mode)
    __asm__ volatile ("rdcycle %0" : "=r"(cycle));
    return cycle;
}

void __attribute__((section(".text._start"))) _start() {
    __asm__ volatile (
        "li sp, 0x80100000\n"
        "call main\n"
        "ebreak\n"             
    );
}

// 1. Классическая программная MVM реализация (Плохой параллелизм)
__attribute__((noinline)) void cpu_classic_mvm(const int8_t* X, const int8_t W[][16], int32_t* Y, int N) {
    for (int i = 0; i < N; i++) {
        int8_t act = X[i];
        for (int j = 0; j < 16; j++) {
            Y[j] += act * W[i][j];
        }
    }
}

// 2. Аппаратный Векторный DIMC Ускоритель (SIMD подход)
__attribute__((noinline)) int32_t dimc_coprocessor_mvm(const int8_t* X, int N) {
    int32_t dummy = 0;
    for (int i = 0; i < N; i++) {
        vmac_dimc(dummy, X[i], i);
    }
    return dummy; // Фейковый результат, чтобы компилятор не удалял цикл
}

int main() {
    // Входной слой (128 нейронов) вычисляется на следующий слой (16 выходных нейронов)
    int N = 128; 
    
    // Выделение памяти
    int8_t arr_act[128];
    int8_t arr_w[128][16];
    int32_t Y_classic[16];
    
    for(int i = 0; i < 128; i++) {
        arr_act[i] = 1;
        for(int j=0; j<16; j++) {
            arr_w[i][j] = 1;
        }
    }
    for(int j=0; j<16; j++) {
        Y_classic[j] = 0;
    }

    // Запуск классического CPU
    uint32_t start_cpu = read_cycle();
    cpu_classic_mvm(arr_act, arr_w, Y_classic, N);
    uint32_t end_cpu = read_cycle();
    volatile uint32_t cpu_diff = end_cpu - start_cpu;

    // Запуск DIMC-SIMD
    // Внимание: Чтобы rdcycle не склеился в Unicorn, добавим микрообманку
    uint32_t start_dimc = read_cycle();
    int32_t res2 = dimc_coprocessor_mvm(arr_act, N);
    uint32_t end_dimc = read_cycle();
    volatile uint32_t dimc_diff = end_dimc - start_dimc;

    // Сбрасываем полученные разницы в порт дебага для эмулятора Python!
    *DEBUG = 0xAAAAAAAA;
    *DEBUG = cpu_diff;
    *DEBUG = 0xBBBBBBBB;
    *DEBUG = dimc_diff;
    *DEBUG = res2; // prevent optimize
    *DEBUG = 0x33333333; // Конец

    return 0;
}
