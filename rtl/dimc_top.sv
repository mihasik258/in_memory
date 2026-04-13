`timescale 1ns / 1ps

module dimc_top #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter ACCUM_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // Прямой интерфейс микрокоманд (обратная совместимость)
    input  logic                   req_valid,
    input  logic [ADDR_WIDTH-1:0]  req_addr,
    input  logic                   req_accum,   
    input  logic                   req_sub,     
    input  logic [3:0]             req_shift,   
    
    // Интерфейс аппаратного FSM (Активация)
    input  logic                   req_act_valid,
    input  logic [DATA_WIDTH-1:0]  req_act_data,
    input  logic [ADDR_WIDTH-1:0]  req_act_addr,
    
    // Результат и статус
    output logic                   req_ready,
    output logic [ACCUM_WIDTH-1:0] result_out
);

    logic [DATA_WIDTH-1:0] sram_rdata;
    
    // Состояние автомата разбора Активаций
    typedef enum logic [1:0] { IDLE, RUNNING } fsm_state_t;
    fsm_state_t state, next_state;

    logic [2:0] act_bit_idx, next_act_bit_idx;
    logic [DATA_WIDTH-1:0] act_reg, next_act_reg;
    logic [ADDR_WIDTH-1:0] addr_reg, next_addr_reg;

    // Внутренние MUX для микрокоманд
    logic       cmd_valid_internal;
    logic       cmd_accum_internal;
    logic       cmd_sub_internal;
    logic [3:0] cmd_shift_internal;
    logic [ADDR_WIDTH-1:0] target_addr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            act_bit_idx <= '0;
            act_reg <= '0;
            addr_reg <= '0;
        end else begin
            state <= next_state;
            act_bit_idx <= next_act_bit_idx;
            act_reg <= next_act_reg;
            addr_reg <= next_addr_reg;
        end
    end

    always_comb begin
        next_state = state;
        next_act_bit_idx = act_bit_idx;
        next_act_reg = act_reg;
        next_addr_reg = addr_reg;
        req_ready = 1'b0;
        
        cmd_valid_internal = 1'b0;
        cmd_accum_internal = 1'b0;
        cmd_sub_internal = 1'b0;
        cmd_shift_internal = 4'd0;
        target_addr = req_addr;

        case (state)
            IDLE: begin
                req_ready = 1'b1;
                if (req_act_valid) begin
                    // Захватываем параметры активации
                    next_act_reg = (req_act_data[7]) ? (~req_act_data + 1'b1) : req_act_data; // Модуль (magnitude)
                    next_addr_reg = req_act_addr;
                    next_act_bit_idx = 0;
                    next_state = RUNNING;
                end else if (req_valid) begin
                    // Прямой проброс
                    cmd_valid_internal = 1'b1;
                    cmd_accum_internal = req_accum;
                    cmd_sub_internal = req_sub;
                    cmd_shift_internal = req_shift;
                    target_addr = req_addr;
                end
            end
            
            RUNNING: begin
                target_addr = addr_reg;
                
                if (act_reg[act_bit_idx] == 1'b1) begin
                    cmd_valid_internal = 1'b1;
                    cmd_accum_internal = 1'b1; // Всегда накапливаем
                    cmd_sub_internal = req_act_data[7]; // Знак взяли из сохраненного старшего бита
                    cmd_shift_internal = {1'b0, act_bit_idx};
                end
                
                if (act_bit_idx == 3'd7) begin
                    next_state = IDLE;
                end else begin
                    next_act_bit_idx = act_bit_idx + 1;
                end
            end
        endcase
    end

    // Задержка на 1 такт для SRAM
    logic       cmd_valid_delayed;
    logic       cmd_accum_delayed;
    logic       cmd_sub_delayed;
    logic [3:0] cmd_shift_delayed;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_valid_delayed <= 1'b0;
            cmd_accum_delayed <= 1'b0;
            cmd_sub_delayed   <= 1'b0;
            cmd_shift_delayed <= '0;
        end else begin
            cmd_valid_delayed <= cmd_valid_internal;
            cmd_accum_delayed <= cmd_accum_internal;
            cmd_sub_delayed   <= cmd_sub_internal;
            cmd_shift_delayed <= cmd_shift_internal;
        end
    end

    sram_dimc_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) sram_inst (
        .clk(clk),
        .we(1'b0),
        .addr(target_addr),
        .wdata('0),
        .rdata(sram_rdata)
    );

    dimc_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) ctrl_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(cmd_valid_delayed),
        .cmd_accum(cmd_accum_delayed),
        .cmd_sub(cmd_sub_delayed),
        .cmd_shift(cmd_shift_delayed),
        .mem_rdata(sram_rdata),
        .cmd_ready(), // Ignored, handled by FSM req_ready
        .accum_out(result_out)
    );

endmodule
