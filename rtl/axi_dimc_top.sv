`timescale 1ns / 1ps

module axi_dimc_top #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter ACCUM_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Slave Интерфейс (Сюда стучится процессор)
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready
);

    logic                   dimc_req_valid;
    logic [ADDR_WIDTH-1:0]  dimc_req_addr;
    logic                   dimc_req_accum;
    logic                   dimc_req_sub;
    logic [3:0]             dimc_req_shift;
    logic                   dimc_req_ready;
    logic [ACCUM_WIDTH-1:0] dimc_result_out;

    logic                   dimc_req_act_valid;
    logic [DATA_WIDTH-1:0]  dimc_req_act_data;
    logic [ADDR_WIDTH-1:0]  dimc_req_act_addr;

    rvv_axi_interface #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) axi_if (
        .clk(clk),
        .rst_n(rst_n),
        .awaddr(s_axi_awaddr),
        .awvalid(s_axi_awvalid),
        .awready(s_axi_awready),
        .wdata(s_axi_wdata),
        .wvalid(s_axi_wvalid),
        .wready(s_axi_wready),
        .bresp(s_axi_bresp),
        .bvalid(s_axi_bvalid),
        .bready(s_axi_bready),
        .araddr(s_axi_araddr),
        .arvalid(s_axi_arvalid),
        .arready(s_axi_arready),
        .rdata(s_axi_rdata),
        .rresp(s_axi_rresp),
        .rvalid(s_axi_rvalid),
        .rready(s_axi_rready),
        
        // Выходы интерфейса управления DIMC
        .dimc_req_valid(dimc_req_valid),
        .dimc_req_addr(dimc_req_addr),
        .dimc_req_accum(dimc_req_accum),
        .dimc_req_sub(dimc_req_sub),
        .dimc_req_shift(dimc_req_shift),
        .dimc_req_ready(dimc_req_ready),
        
        .dimc_req_act_valid(dimc_req_act_valid),
        .dimc_req_act_data(dimc_req_act_data),
        .dimc_req_act_addr(dimc_req_act_addr),

        .dimc_result_out(dimc_result_out)
    );

    // Экземпляр нашего старого проверенного топ-левела с памятью
    dimc_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) dimc_core (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(dimc_req_valid),
        .req_addr(dimc_req_addr),
        .req_accum(dimc_req_accum),
        .req_sub(dimc_req_sub),
        .req_shift(dimc_req_shift),

        .req_act_valid(dimc_req_act_valid),
        .req_act_data(dimc_req_act_data),
        .req_act_addr(dimc_req_act_addr),

        .req_ready(dimc_req_ready),
        .result_out(dimc_result_out)
    );

endmodule
