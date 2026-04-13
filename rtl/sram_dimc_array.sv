`timescale 1ns / 1ps

module sram_dimc_array #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter NUM_COLUMNS = 16
)(
    input  logic                                  clk,
    input  logic                                  we,
    input  logic [ADDR_WIDTH-1:0]                 addr,
    input  logic [(DATA_WIDTH*NUM_COLUMNS)-1:0]   wdata,
    output logic [(DATA_WIDTH*NUM_COLUMNS)-1:0]   rdata
);
    // Массив статической памяти (строки по 16 весов)
    logic [(DATA_WIDTH*NUM_COLUMNS)-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // Инициализация памяти (в нашем случае эмулируем начальными не-нулевыми данными)
    integer i;
    initial begin
        // Заполняем память дамми-данными: каждый байт равен 1 (0x0101...01)
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            mem[i] = {16{8'h01}}; 
        end
    end

    // Синхронная память
    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
        end
        rdata <= mem[addr];
    end

endmodule
