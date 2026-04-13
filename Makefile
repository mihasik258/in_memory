# Базовый Makefile для запуска симуляций и скриптов

PYTHON = venv/bin/python
SCRIPT_DIR = scripts
RTL_DIR = rtl
TB_DIR = tb

# Флаги симулятора
VERILATOR = /usr/local/bin/verilator
VERILATOR_FLAGS = -Wall --cc --trace --exe --build

.PHONY: all setup cluster clean sim

all: setup cluster

setup:
	@if [ ! -d "venv" ]; then \
		echo "Создание виртуального окружения..."; \
		python3 -m venv venv; \
		venv/bin/pip install numpy scikit-learn; \
	fi

# Запуск алгоритма кластеризации весов на Питоне
cluster: setup
	@echo "====================================="
	@echo " Запуск Python скрипта кластеризации"
	@echo "====================================="
	$(PYTHON) $(SCRIPT_DIR)/weight_clustering.py

# Сборка и запуск железа в Verilator
sim: setup
	@echo "====================================="
	@echo " Сборка Verilator проекта            "
	@echo "====================================="
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_DIR)/dimc_top.sv $(RTL_DIR)/dimc_controller.sv $(RTL_DIR)/sram_dimc_array.sv $(TB_DIR)/tb_dimc_top.cpp
	make -j -C obj_dir -f Vdimc_top.mk Vdimc_top
	@echo "====================================="
	@echo " Запуск симуляции                    "
	@echo "====================================="
	./obj_dir/Vdimc_top

# Сборка AXI-обертки для проверки процессорного интерфейса
axi_sim: setup
	@echo "====================================="
	@echo " Сборка AXI Verilator проекта        "
	@echo "====================================="
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_DIR)/axi_dimc_top.sv $(RTL_DIR)/rvv_axi_interface.sv $(RTL_DIR)/dimc_top.sv $(RTL_DIR)/dimc_controller.sv $(RTL_DIR)/sram_dimc_array.sv $(TB_DIR)/tb_axi_top.cpp
	make -j -C obj_dir -f Vaxi_dimc_top.mk Vaxi_dimc_top
	@echo "====================================="
	@echo " Запуск симуляции AXI шины           "
	@echo "====================================="
	./obj_dir/Vaxi_dimc_top

# Сборка AXI-обертки для проверки случайными стресс-тестами
axi_rand: setup cluster
	@echo "====================================="
	@echo " Сборка Stress-Test проекта Verilator"
	@echo "====================================="
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_DIR)/axi_dimc_top.sv $(RTL_DIR)/rvv_axi_interface.sv $(RTL_DIR)/dimc_top.sv $(RTL_DIR)/dimc_controller.sv $(RTL_DIR)/sram_dimc_array.sv $(TB_DIR)/tb_axi_random.cpp
	make -j -C obj_dir -f Vaxi_dimc_top.mk Vaxi_dimc_top
	@echo "====================================="
	@echo " Запуск 10000 AXI-транзакций         "
	@echo "====================================="
	./obj_dir/Vaxi_dimc_top

clean:
	@echo "Очистка проекта..."
	rm -rf obj_dir
	rm -f $(RTL_DIR)/weights_init.mem
