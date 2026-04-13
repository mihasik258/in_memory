#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>

#define N 10000000 // 10 Миллионов весов

int8_t* weights;
int8_t* activations;

int main() {
    weights = (int8_t*)malloc(N * sizeof(int8_t));
    activations = (int8_t*)malloc(N * sizeof(int8_t));
    
    // Инициализация
    for(int i = 0; i < N; i++) {
        weights[i] = 1;
        activations[i] = 2;
    }

    int32_t accum = 0;
    
    printf("🚀 Старт базового теста на RISC-V (10 Миллионов MAC операций)...\n");
    clock_t start = clock();
    
    // Центральный вычислительный цикл для нейросети (MAC)
    for (int i = 0; i < N; i++) {
        accum += (int32_t)activations[i] * (int32_t)weights[i];
    }
    
    clock_t end = clock();
    double cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
    
    printf("✅ Вычисление завершено.\n");
    printf("Итоговый результат: %d\n", accum);
    printf("⏱️ Затраченное CPU время RISC-V: %f секунд\n", cpu_time_used);
    
    free(weights);
    free(activations);
    return 0;
}
