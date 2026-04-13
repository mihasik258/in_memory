#include <stdint.h>

#define N 1024

// Имитация весов в памяти и входных активаций
int8_t weights[N];
int8_t activations[N];

int main() {
    int32_t accum = 0;
    
    // Центральный вычислительный цикл для нейросети (MAC: Multiply-Accumulate)
    // В чисто программном варианте процессору приходится перебирать каждый элемент по очереди
    for (int i = 0; i < N; i++) {
        // Процессор должен подгрузить 2 числа из памяти, перемножить их и добавить к сумме
        accum += (int32_t)activations[i] * (int32_t)weights[i];
    }
    
    // Предотвращение агрессивной оптимизации компилятора, чтобы он не удалил цикл
    volatile int32_t* const OUT = (int32_t*)0x80000000;
    *OUT = accum;
    
    return 0;
}
