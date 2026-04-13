`timescale 1ns / 1ps

module dimc_controller #(
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32,
    parameter NUM_COLUMNS = 16
)(
    input  logic                                  clk,
    input  logic                                  rst_n,
    
    // Интерфейс команд (поступает от диспетчера/шины процессора)
    input  logic                                  cmd_valid,
    input  logic [DATA_WIDTH-1:0]                 cmd_act_data, // Броадкаст активация (от CPU)
    input  logic [(DATA_WIDTH*NUM_COLUMNS)-1:0]   mem_rdata,    // Данные строки весов из SRAM
    
    // Итоговый результат вычислений (MAC параллельный по 16 столбцам)
    // В полной версии мы отправляем 16 аккумуляторов в память, но 
    // для интерфейса к CPU мы можем отдать сумму или первый элемент.
    // Сделаем Tree-Adder, так как CPU (rd) ждет одно 32-битное число.
    output logic [ACCUM_WIDTH-1:0]                accum_out
);

    // 16 параллельных аккумуляторов (внутренняя память ускорителя)
    logic signed [ACCUM_WIDTH-1:0] accums [NUM_COLUMNS-1:0];

    // Комбинаторное перемножение (16 параллельных аппаратных умножителей)
    logic signed [ACCUM_WIDTH-1:0] mult_results [NUM_COLUMNS-1:0];

    genvar i;
    generate
        for (i = 0; i < NUM_COLUMNS; i = i + 1) begin : mac_array
            // Извлекаем нужный вес
            wire signed [DATA_WIDTH-1:0] signed_weight = mem_rdata[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH];
            wire signed [DATA_WIDTH-1:0] signed_act = cmd_act_data;
            
            // Умножитель (1 такт, комбинаторный)
            assign mult_results[i] = signed_weight * signed_act;
            
            // Аккумуляторы
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    accums[i] <= '0;
                end else if (cmd_valid) begin
                    accums[i] <= accums[i] + mult_results[i];
                end
            end
        end
    endgenerate

    // Вывод "свертки" (суммы) для ответа процессору (чтобы наблюдать результат)
    // В реальном MVM этот выход не всегда нужен, но для проверки сложим все:
    logic signed [ACCUM_WIDTH-1:0] sum_all;
    always_comb begin
        sum_all = '0;
        for (int j = 0; j < NUM_COLUMNS; j = j + 1) begin
            sum_all = sum_all + accums[j];
        end
    end
    
    assign accum_out = sum_all;

endmodule
