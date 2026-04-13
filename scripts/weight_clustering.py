import numpy as np
from sklearn.cluster import KMeans
import os

def generate_and_cluster_weights(num_weights=1024, num_clusters=16):
    print(f"🚀 Сборка весов: генерируем {num_weights} случайных весов...")
    np.random.seed(42)
    # Генерируем тестовые веса нейросети (от -1.0 до 1.0)
    original_weights = np.random.uniform(-1.0, 1.0, (num_weights, 1))

    print(f"🧠 Начинаем кластеризацию алгоритмом K-Means до {num_clusters} центроидов...")
    kmeans = KMeans(n_clusters=num_clusters, random_state=42, n_init=10)
    kmeans.fit(original_weights)

    # Получаем новые кластеризованные веса (индексы центроидов)
    labels = kmeans.labels_
    centroids = kmeans.cluster_centers_

    # Преобразуем центроиды в целочисленный 8-битный формат (INT8: от -128 до 127)
    quantized_centroids = np.round(centroids * 127).astype(int).flatten()

    print("\n✅ Вычисленные уникальные веса (в формате INT8):")
    for i, c in enumerate(quantized_centroids):
        print(f"  Центроид {i}: {c}")

    # Создаем файл для инициализации памяти Verilog ($readmemh)
    os.makedirs('rtl', exist_ok=True)
    mem_file = "rtl/weights_init.mem"
    print(f"\n💾 Запись сконвертированных данных в {mem_file}...")
    
    with open(mem_file, "w") as f:
        # Для простоты пишем по одному 8-битному весу на строку (hex)
        edge_cases = [-128, 127, -1, 0]
        for i, label in enumerate(labels):
            if i < 4:
                val = edge_cases[i]
            else:
                val = quantized_centroids[label]
            # Перевод в 8-битный 2's complement
            hex_val = f"{(val & 0xFF):02X}"
            f.write(f"{hex_val}\n")
            
    print("🎉 Успешно! Файл инициализации памяти готов.")

if __name__ == "__main__":
    generate_and_cluster_weights()
