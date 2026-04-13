тему проектирования аппаратного In-Memory Computing модуля для процессора RISC-V для ускорения тензорных операций
# RISC-V + IMC для тензорных операций: где новизна даст максимальный импакт

## Executive Summary

Исследования в области интеграции модулей In-Memory Computing (IMC) с процессорами RISC-V для ускорения тензорных операций активно развиваются, предлагая решения для преодоления «узкого места» фон Неймана [executive_summary[0]][1]. Основные достижения сосредоточены на двух парадигмах: аналоговых вычислениях в памяти (AIMC) и цифровых (DIMC) на базе SRAM [executive_summary[14]][2]. Интеграция с RISC-V реализуется через тесно связанное сопряжение, использование векторного расширения (RVV) и слабо связанное сопряжение через память (MMIO/DMA) [executive_summary[19]][3]. Академические прототипы демонстрируют впечатляющую энергоэффективность и значительное ускорение (до 200 раз) по сравнению с базовыми ядрами RISC-V [executive_summary[0]][1]. Ключевыми проблемами остаются надежность AIMC, отсутствие стандартизированных расширений ISA, незрелость компиляторов и системные узкие места [executive_summary[15]][4].

## Цель и рамки работы

Цель данного отчета — проанализировать текущий ландшафт аппаратных модулей In-Memory Computing для RISC-V и выделить наиболее перспективные направления для научной статьи. Основной фокус сделан на выборе ниши с максимальным импактом и низким риском, опираясь на зрелость RVV, предсказуемость SRAM-DIMC и дефицит стандартов в области компиляторов [recommended_research_topics.0[0]][5].

## Ландшафт RISC-V+IMC: от академии к продуктам

Рынок и академическая среда предлагают множество решений, от тесно связанных макросов до коммерческих PIM-модулей.

| Проект | Категория | Технология | Интеграция с RISC-V | Производительность | Зрелость |
| :--- | :--- | :--- | :--- | :--- | :--- |
| In-Pipeline DIMC | SRAM-DIMC | 8T SRAM, INT1/2/4 | Тесная (RVV) | 137 GOPS (INT4) | Прототип |
| PipeCIM | AIMC (SRAM) | 55 нм | Тесная | 134 TOPS/W | Кремний |
| AI-PiM | SRAM-DIMC | Цифровые PIM | Тесная | 17.6x ускорение | Прототип |
| RDCIM | SRAM-DIMC | 55 нм, 8T SRAM | Тесная | 66.3 TOPS/W (4-bit) | Кремний |
| CIMR-V | SRAM-DIMC | 28 нм, 10T SRAM | Слабая | 26.2 TOPS | SoC |
| VPU-CIM | AIMC (RRAM) | 130 нм | Слабая | 33.98 TOPS/W | Кремний |
| Mythic M1108 | AIMC (Flash) | 40 нм | Слабая (PCIe) | 35 TOPS | Коммерч. |
| Samsung HBM-PIM | PIM-память | HBM2/LPDDR5 | Внешняя | 2-3.5x ускорение | Коммерч. |
| UPMEM PIM-DRAM | PIM-память | DDR4 RDIMM | Внешняя (MMIO) | 14-41x ускорение | Коммерч. |
| IBM NorthPole | SRAM-DIMC | 12 нм | N/A | >13 ТБ/с | Прототип |
| d-Matrix Corsair | SRAM-DIMC | Чиплеты | Слабая (PCIe) | 150 ТБ/с | Коммерч. |

*Таблица показывает, что DIMC на базе SRAM и PIM-решения уже демонстрируют высокую зрелость и коммерческую применимость, в то время как AIMC остается в основном на стадии академических прототипов.*

## Аналог vs Цифра в IMC: где что оправдано

Выбор между аналоговыми и цифровыми вычислениями в памяти определяет баланс между энергоэффективностью и точностью.

| Характеристика | AIMC (Analog IMC) | DIMC (Digital IMC) |
| :--- | :--- | :--- |
| Точность | ≤8 бит (ограничена шумом и дрейфом) | 8+ бит (ошибка <1%) |
| Энергоэффективность | Пиковая (100+ TOPS/W на макро) | Средняя (десятки TOPS/W системно) |
| Накладные расходы | Высокие (АЦП/ЦАП до 58% энергии) | Низкие (нет АЦП/ЦАП) |
| Обучение | Требует Hardware-Aware Training (HWA) | Поддерживает PTQ/QAT |

*DIMC обеспечивает более предсказуемые результаты и легче интегрируется в существующие цифровые конвейеры, что делает его предпочтительным для статей по архитектуре RISC-V [analog_vs_digital_imc_comparison.dimc_summary[0]][2].*

## Стратегии интеграции с RISC-V

Способ подключения IMC к ядру RISC-V критически влияет на производительность и сложность ПО.

| Стратегия | Задержка вызова | Сложность ПО | Когерентность | Примеры |
| :--- | :--- | :--- | :--- | :--- |
| Tightly-coupled scalar | Низкая | Средняя | Через L1/VRF | AI-PiM, RDCIM |
| RVV-coupled | Очень низкая | Низкая (RVV toolchain) | VRF | In-Pipeline DIMC |
| Loosely-coupled (MMIO) | Высокая | Низкая (драйвер) | CMO + fence | HBM-PIM, UPMEM |

*Интеграция через RVV обеспечивает лучший баланс между производительностью и простотой программирования для тензорных операций [integration_strategies_analysis.strategy_name[0]][1].*

## Проект ISA для IMC (Zimc/Vimc)

Отсутствие стандартизации тормозит развитие экосистемы. Предлагается минималистичный набор инструкций (Zimc/Vimc), совместимый с RVV, включающий 3-6 векторных команд (load, launch, store) и CSR для настройки форматов и тайлов [recommended_research_topics.0.hypothesis[0]][3].

## Компилятор и рантайм на MLIR

Автоматизация разбиения графов и планирования задач критична для получения выгоды от IMC. Использование MLIR-диалектов и моделей стоимости позволяет снизить энергопотребление в 1.5-2.5 раза [recommended_research_topics.2.hypothesis[0]][6].

## Отображение тензор-ядер на IMC

Эффективное выполнение GEMM, Conv и Attention требует правильного dataflow (например, Weight-Stationary) и минимизации перемещения данных, особенно для операций QK^T в трансформерах [software_and_compiler_approaches[167]][7].

## Числовые форматы и калибровка

DIMC стабильно поддерживает INT8/INT4 и FP8, в то время как AIMC требует сложных процедур калибровки (например, GDC+AdaBS) для компенсации дрейфа и шума [analog_vs_digital_imc_comparison.aimc_summary[2]][8].

## Системная интеграция

Узкие места часто кроются в SPM, DMA и NoC. Рекомендуется использовать 2D-mesh NoC с поддержкой QoS и двойную буферизацию для скрытия задержек памяти [software_and_compiler_approaches[184]][9].

## Безопасность и приватность

Без PMP и IOMMU IMC-модули уязвимы к атакам по побочным каналам и проблемам с реманентностью данных. Необходим минимальный профиль безопасности, включающий crypto-erase [software_and_compiler_approaches[358]][10].

## Приложения Edge (MLPerf Tiny)

Эталонные сценарии на базе MLPerf Tiny показывают, что SoC с SRAM-DIMC могут достигать задержек в 2-10 мс при потреблении 10-50 мВт [software_and_compiler_approaches[428]][11].

## Конкурентность на memory-bound задачах

Для задач с интенсивностью <50-100 FLOP/байт (KV-кэш, графы) PIM-решения стабильно превосходят GPU по TCO [software_and_compiler_approaches[354]][12].

## Методология оценки и воспроизводимость

Использование MLPerf LoadGen и честных метрик энергопотребления «от розетки» критично для объективного сравнения [software_and_compiler_approaches[286]][13].

## Производство и стоимость

На зрелых узлах eNVM экономит площадь, но на передовых (7/5 нм) выигрывает SRAM-DIMC из-за проблем с масштабированием аналоговых компонентов [memory_technology_evaluation.availability_and_nodes[0]][14].

## DFT и тестирование

Двурежимный MBIST и механизмы BISR/BIRA обязательны для обеспечения выхода годных и надежности IMC-массивов [memory_technology_evaluation.cost_and_yield_risks[1]][15].

## Путь к стандартизации в RISC-V

Открытые X-расширения и эталонные артефакты (RTL, Spike, LLVM) увеличивают шансы на принятие Z-расширений для IMC [software_and_compiler_approaches[468]][16].

## Рекомендованные направления статьи

1. **Стандартизируемый RVV-совместимый интерфейс для DIMC:** Ожидается 70-85% утилизации и 2-5x снижение EDP [recommended_research_topics.0.hypothesis[0]][3].
2. **ISA/рантайм с контролем ошибок для AIMC:** Повышение точности при минимальных накладных расходах.
3. **Единый компилятор на MLIR:** Автоматизация кодогенерации для гетерогенных систем [recommended_research_topics.2.hypothesis[0]][6].

## План валидации и таймлайн

Использование софтовых прототипов (MLIR, LLVM) и RTL-моделей (Ara/CVA6) позволит проверить гипотезы за 6 месяцев без необходимости дорогостоящего производства кремния [recommended_research_topics.0.feasibility_and_risks[1]][1].

## References

1. *In-Pipeline Integration of Digital In-Memory-Computing into RISC-V Vector Architecture to Accelerate Deep Learning*. https://arxiv.org/html/2602.01827v1
2. *Analog or Digital In-memory Computing? Benchmarking through Quantitative Modeling*. https://arxiv.org/html/2405.14978v1
3. *In-Pipeline Integration of Digital In-Memory-Computing into ...*. https://arxiv.org/pdf/2602.01827
4. *Achieving high precision in analog in-memory computing systems | npj Unconventional Computing*. https://www.nature.com/articles/s44335-025-00044-2
5. *Efficient Processing-in-Memory System Based on RISC-V Instruction Set Architecture*. https://www.mdpi.com/2079-9292/13/15/2971
6. *Samsung Brings In-Memory Processing Power to Wider Range of Applications – Samsung Global Newsroom*. https://news.samsung.com/global/samsung-brings-in-memory-processing-power-to-wider-range-of-applications
7. *Eyeriss | Proceedings of the 43rd International Symposium on Computer Architecture*. https://dl.acm.org/doi/10.1109/ISCA.2016.40
8. *Accurate deep neural network inference using computational phase-change memory | Nature Communications*. https://www.nature.com/articles/s41467-020-16108-9
9. *High-performance and energy efficient data movement*. https://pulp-platform.org/docs/lugano2023/data_movers_Thomas_Tim.pdf
10. *Silent Shredder: Zero-Cost Shredding for Secure Non-Volatile Main Memory Controllers: ACM SIGPLAN Notices: Vol 51, No 4*. https://dl.acm.org/doi/10.1145/2954679.2872377
11. *
            Low-Power Embedded Sensor Node for Real-Time Environmental Monitoring with On-Board Machine-Learning Inference - PMC
        *. https://pmc.ncbi.nlm.nih.gov/articles/PMC12845735/
12. *DRIM-ANN: An Approximate Nearest Neighbor Search Engine based on Commercial DRAM-PIMs | Proceedings of the International Conference for High Performance Computing, Networking, Storage and Analysis*. https://dl.acm.org/doi/10.1145/3712285.3759801
13. *Power Measurement - MLPerf Inference Documentation*. https://docs.mlcommons.org/inference/power/
14. *A review of SRAM-based compute-in-memory circuits - IOPscience*. https://iopscience.iop.org/article/10.35848/1347-4065/ad93e0
15. *
            Optimal Method for Test and Repair Memories Using Redundancy Mechanism for SoC - PMC
        *. https://pmc.ncbi.nlm.nih.gov/articles/PMC8306510/
16. *riscv-unprivileged.pdf*. https://lists.riscv.org/g/sig-documentation/attachment/266/0/riscv-unprivileged.pdf