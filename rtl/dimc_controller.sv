`timescale 1ns / 1ps

module dimc_controller #(
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    
    // Интерфейс команд (поступает от диспетчера/шины процессора)
    input  logic                   cmd_valid,
    input  logic                   cmd_accum,   // 0: записать новое значение, 1: прибавить к текущему
    input  logic                   cmd_sub,     // 0: сложение, 1: вычитание
    input  logic [3:0]             cmd_shift,   // На сколько бит выполняем сдвиг влево
    input  logic [DATA_WIDTH-1:0]  mem_rdata,   // Данные, прочитанные напрямую из матрицы SRAM
    
    output logic                   cmd_ready,

    // Итоговый результат вычислений (MAC)
    output logic [ACCUM_WIDTH-1:0] accum_out
);

    logic signed [ACCUM_WIDTH-1:0] shifter_out;
    logic signed [ACCUM_WIDTH-1:0] extended_data;

    // Явное знакорасширение до 32 бит перед сдвигом (чтобы Verilator не ругался на WIDTHEXPAND)
    assign extended_data = signed'({{(ACCUM_WIDTH-DATA_WIDTH){mem_rdata[DATA_WIDTH-1]}}, mem_rdata});
    
    // Выполняем арифметический сдвиг на нужное число бит
    assign shifter_out = extended_data <<< cmd_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accum_out <= '0;
        end else if (cmd_valid) begin
            if (!cmd_accum) begin
                accum_out <= cmd_sub ? -shifter_out : shifter_out;
            end else begin
                accum_out <= cmd_sub ? (accum_out - shifter_out) : (accum_out + shifter_out);
            end
        end
    end
    
    // Готовность контроллера принять новую команду
    assign cmd_ready = 1'b1;

endmodule
