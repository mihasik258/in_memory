`timescale 1ns / 1ps

module sram_dimc_array #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10
)(
    input  logic                   clk,
    input  logic                   we,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [DATA_WIDTH-1:0]  wdata,
    output logic [DATA_WIDTH-1:0]  rdata
);
    // Массив статической памяти
    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // Инициализация памяти "прошивкой", сгенерированной Python-скриптом
    initial begin
        $readmemh("rtl/weights_init.mem", mem);
    end

    // Синхронная память: чтение и запись по такту
    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
        end
        rdata <= mem[addr];
    end

endmodule
