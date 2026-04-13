#include <stdint.h>

#define DIMC_CMD_ADDR 0x50000000
#define DIMC_RES_ADDR 0x50000004
#define DEBUG_PORT    0x80000000

volatile uint32_t* const DIMC_CMD = (uint32_t*) DIMC_CMD_ADDR;
volatile uint32_t* const DIMC_RES = (uint32_t*) DIMC_RES_ADDR;
volatile uint32_t* const DEBUG    = (uint32_t*) DEBUG_PORT;

// Формирует AXI команду: [15:6] ADDR, [5:2] SHIFT, [1] SUB, [0] ACCUM
uint32_t build_cmd(uint32_t addr, uint32_t accum, uint32_t sub, uint32_t shift) {
    return (addr << 6) | (shift << 2) | (sub << 1) | (accum);
}

// Очистка аккумулятора перед началом тензорной операции
void dimc_clear_accumulator() {
    *DIMC_CMD = build_cmd(0, 0, 0, 0); // Load W[0]
    *DIMC_CMD = build_cmd(0, 1, 1, 0); // Subtract W[0] => Accumulator = 0
}

// Bare-metal точка входа (BootROM CVA6 передаст управление сюда после инициализации)
void __attribute__((section(".text._start"))) _start() {
    __asm__ volatile (
        "li sp, 0x80100000\n"  // Инициализируем стек (Stack Pointer) в DRAM
        "call main\n"          // Переход в основную логику
        "ebreak\n"             // Остановка симулятора
    );
}

// Аппаратный тензорный Dot-Product используя архитектуру Bit-Serial DIMC
int32_t execute_tensor_mac(const int8_t* activations, int length) {
    // 0x50000000 - Прямые микро-команды
    volatile uint32_t* const DIMC_CMD = (uint32_t*) 0x50000000;
    // 0x50000004 - Доступ к регистру результата
    volatile int32_t* const  DIMC_RES = (int32_t*)  0x50000004;
    // 0x50000008 - Hardware Unrolling FSM (Активации)
    volatile uint32_t* const DIMC_ACT = (uint32_t*) 0x50000008;

    // 1. Очистка внутреннего аккумулятора памяти 
    //    (посылаем микро-команду к ячейке 3, где лежит 0)
    *DIMC_CMD = build_cmd(3, 0, 0, 0);

    // 2. Итерация по вектору: на каждый элемент делаем ровно 1 запись. 
    //    Остальную распаковку на 8 тактов памяти делает FSM!
    for (int addr = 0; addr < length; addr++) {
        int8_t act = activations[addr];
        if (act != 0) {
            // Пишем Адрес и Активацию за 1 такт CPU
            // Формат записи DIMC_ACT: [23:8] = addr, [7:0] = act
            *DIMC_ACT = (addr << 8) | (uint8_t)act;
        }
    }

    // В настоящем железе, если FSM еще не готов, AXI-контроллер 
    // благодаря backpressure задержит шину до конца вычислений.

    // 3. Возврат готового MAC-аккумулятора
    return *DIMC_RES;
} // Сбор результата с регистров ускоренной SRAM

int main() {
    // В памяти весов (weights.mem) по скрипту лежат краевые случаи:
    // W[0] = -128, W[1] = 127, W[2] = -1, W[3] = 0
    
    // Входной вектор активаций (моделируем приход данных от сенсора/предыдущего слоя)
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

    // Тест 2: Большой вектор из 10 элементов с переполнением внутри суммы
    // Weights (из скрипта K-Means кластеризации): случайные величины
    // Для C-testbench это не гарантирует статичного результата, поэтому в цикле останавливаемся.
    
    while(1) {
        __asm__ volatile ("wfi"); // Режим глубокого сна на CVA6
    }
    
    return 0;
}
