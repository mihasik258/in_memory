`timescale 1ns / 1ps

module dimc_top #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter ACCUM_WIDTH = 32,
    parameter NUM_COLUMNS = 16
)(
    input  logic clk,
    input  logic rst_n,

    // Интерфейс аппаратного ускорения (CV-X-IF MAC.DIMC)
    input  logic                   req_act_valid,
    input  logic [DATA_WIDTH-1:0]  req_act_data, // Транслируется на все 16 MAC
    input  logic [ADDR_WIDTH-1:0]  req_act_addr,
    
    // Результат и статус
    output logic                   req_ready,
    output logic [ACCUM_WIDTH-1:0] result_out
);

    logic [(DATA_WIDTH*NUM_COLUMNS)-1:0] sram_rdata;
    
    // 2-стадийный конвейер (Stage 1: Чтение SRAM, Stage 2: MAC)
    logic stage1_valid;
    logic [DATA_WIDTH-1:0] stage1_act_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid <= 1'b0;
            stage1_act_data <= '0;
        end else begin
            // Пробрасываем данные со входа на стадию 1 (чтение памяти занимает 1 такт)
            stage1_valid <= req_act_valid;
            if (req_act_valid) begin
                stage1_act_data <= req_act_data;
            end
        end
    end

    sram_dimc_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_COLUMNS(NUM_COLUMNS)
    ) sram_inst (
        .clk(clk),
        .we(1'b0),
        .addr(req_act_addr),  // Адрес уходит в SRAM на нулевом такте
        .wdata('0),
        .rdata(sram_rdata)    // Ответ приходит к такту 1
    );

    dimc_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH),
        .NUM_COLUMNS(NUM_COLUMNS)
    ) ctrl_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(stage1_valid),       // MAC умножает на такте 1
        .cmd_act_data(stage1_act_data),
        .mem_rdata(sram_rdata),
        .accum_out(result_out)
    );

    // Устройство готово обрабатывать 1 запрос каждый такт (Fully Pipelined)
    assign req_ready = 1'b1; 

endmodule
