`timescale 1ns / 1ps

module rvv_axi_interface #(
    parameter ADDR_WIDTH = 10,
    parameter ACCUM_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Write (Запись команд от процессора)
    input  logic [31:0] awaddr,
    input  logic        awvalid,
    output logic        awready,
    input  logic [31:0] wdata,
    input  logic        wvalid,
    output logic        wready,
    output logic [1:0]  bresp,
    output logic        bvalid,
    input  logic        bready,

    // AXI4-Lite Read (Чтение результатов процессором)
    input  logic [31:0] araddr,
    input  logic        arvalid,
    output logic        arready,
    output logic [31:0] rdata,
    output logic [1:0]  rresp,
    output logic        rvalid,
    input  logic        rready,

    // Кастомный интерфейс к логике DIMC
    output logic                    dimc_req_valid,
    output logic [ADDR_WIDTH-1:0]   dimc_req_addr,
    output logic                    dimc_req_accum,
    output logic                    dimc_req_sub,
    output logic [3:0]              dimc_req_shift,
    input  logic                    dimc_req_ready,

    output logic                    dimc_req_act_valid,
    output logic [7:0]              dimc_req_act_data, // DATA_WIDTH is 8
    output logic [ADDR_WIDTH-1:0]   dimc_req_act_addr,

    input  logic [ACCUM_WIDTH-1:0]  dimc_result_out
);

    logic aw_en, w_en;
    
    // Рукопожатие (Handshake) записи AXI
    assign awready = ~aw_en && awvalid && wvalid;
    assign wready  = ~w_en && awvalid && wvalid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_en <= 1'b0;
            w_en  <= 1'b0;
        end else begin
            if (awready && awvalid) aw_en <= 1'b1;
            if (wready && wvalid)   w_en  <= 1'b1;
            if (bvalid && bready) begin // Сброс после ответа
                aw_en <= 1'b0;
                w_en  <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid <= 1'b0;
            bresp  <= 2'b00; // OKAY
        end else begin
            if (aw_en && w_en && !bvalid) begin
                bvalid <= 1'b1;
            end else if (bready && bvalid) begin
                bvalid <= 1'b0;
            end
        end
    end

    // --- МАППИНГ ПАМЯТИ (MMIO) ---
    // Формат физических адресов (младшие 12 бит 4K региона):
    // 0x000: Запись микро-команды напрямую (DIMC_CMD)
    // 0x004: Чтение готового MAC-результата (DIMC_RES)
    // 0x008: Запись Активации для авто-сдвига (DIMC_ACT)
    
    wire is_cmd_write = (awaddr[11:0] == 12'h000);
    wire is_act_write = (awaddr[11:0] == 12'h008);
    
    wire axi_write_valid = (awready && awvalid && wready && wvalid);
    
    assign dimc_req_valid = axi_write_valid && is_cmd_write;
    assign dimc_req_act_valid = axi_write_valid && is_act_write;
    
    // Декодируем команду процессора 
    // Напрямую микро-команда: [15:6]=ADDR, [5:2]=SHIFT, [1]=SUB, [0]=ACCUM
    assign dimc_req_addr  = wdata[15:6];
    assign dimc_req_shift = wdata[5:2];
    assign dimc_req_sub   = wdata[1];
    assign dimc_req_accum = wdata[0];

    // Hardware Unrolling команда
    // Формат WDATA: [23:8]=ADDR, [7:0]=ACTIVATION
    assign dimc_req_act_addr = wdata[23:8];
    assign dimc_req_act_data = wdata[7:0];

    // Вводим Back-pressure: AXI шина не примет запись, пока FSM занят!
    // Чтобы не перегрузить автомат, awready блокируется, если dimc_req_ready = 0
    assign awready = ~aw_en && awvalid && wvalid && dimc_req_ready;
    assign wready  = ~w_en && awvalid && wvalid && dimc_req_ready;

    // Поглощение неиспользуемых бит (чтобы Verilator не ругался на UNUSEDSIGNAL)
    logic _unused;
    assign _unused = &{1'b0, wdata[31:24]};

    // Рукопожатие чтения AXI
    assign arready = ~rvalid && arvalid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 1'b0;
            rresp  <= 2'b00;
            rdata  <= 32'd0;
        end else begin
            if (arready && arvalid) begin
                rvalid <= 1'b1;
                if (araddr[11:0] == 12'h004) begin
                    rdata <= dimc_result_out; // Возвращаем результат из DIMC
                end else begin
                    rdata <= 32'hDEADBEEF; // Адрес не найден
                end
            end else if (rvalid && rready) begin
                rvalid <= 1'b0;
            end
        end
    end

endmodule
