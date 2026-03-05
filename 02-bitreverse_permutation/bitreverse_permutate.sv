/**
 * @file bitreverse_permute_bram
 * @brief Ping-pong bitreverse с BRAM
 */

`timescale 1ns / 1ps

module bitreverse_permute_bram #(
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned MAX_BLOCK_LENGTH_LOG2 = 7
) (
    input logic clk_i,
    input logic srst_i,

    input  logic [DATA_WIDTH-1:0] tdata_i,
    input  logic                  tvalid_i,
    output logic                  tready_o,

    input logic [$clog2(MAX_BLOCK_LENGTH_LOG2+1)-1:0] block_length_log2_i,

    output logic [DATA_WIDTH-1:0] tdata_o,
    output logic                  tvalid_o
);

    localparam int MAX_DEPTH = 1 << (MAX_BLOCK_LENGTH_LOG2 + 1);

    // BRAM ping-pong
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem0[0:MAX_DEPTH-1];
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem1[0:MAX_DEPTH-1];

    // счетчики
    logic [MAX_BLOCK_LENGTH_LOG2:0] write_cnt;
    logic [MAX_BLOCK_LENGTH_LOG2:0] read_cnt;
    logic [MAX_BLOCK_LENGTH_LOG2+1:0] block_size;

    logic write_bank;
    logic [1:0] block_ready;
    logic read_bank;

    assign tready_o = !block_ready[write_bank];

    always_ff @(posedge clk_i) begin
        if (srst_i) block_size <= 0;
        else block_size <= 1 << (block_length_log2_i + 1);
    end

    // write logic
    always_ff @(posedge clk_i) begin
        if (srst_i) begin
            write_cnt   <= 0;
            write_bank  <= 0;
            block_ready <= 2'b00;
        end else if (tvalid_i && tready_o) begin
            if (write_bank == 0) mem0[write_cnt] <= tdata_i;
            else mem1[write_cnt] <= tdata_i;

            if (write_cnt == block_size - 1) begin
                write_cnt <= 0;
                block_ready[write_bank] <= 1'b1;
                write_bank <= ~write_bank;
            end else begin
                write_cnt <= write_cnt + 1;
            end
        end
    end

    function automatic logic [MAX_BLOCK_LENGTH_LOG2:0] bitrev;
        input logic [MAX_BLOCK_LENGTH_LOG2:0] value;
        input int width;
        int i;
        begin
            bitrev = '0;
            for (i = 0; i < width; i = i + 1) bitrev[i] = value[width-1-i];
        end
    endfunction

    // read logic
    logic [MAX_BLOCK_LENGTH_LOG2:0] read_addr;
    logic tvalid_d;

    always_ff @(posedge clk_i) begin
        if (srst_i) begin
            read_cnt  <= 0;
            read_bank <= 0;
            tdata_o   <= 0;
            tvalid_o  <= 0;
        end else if (block_ready[read_bank]) begin
            read_addr <= bitrev(read_cnt, block_length_log2_i + 1);
            tvalid_d  <= 1;

            if (read_bank == 0) tdata_o <= mem0[read_addr];
            else tdata_o <= mem1[read_addr];

            tvalid_o <= tvalid_d;

            if (read_cnt == block_size - 1) begin
                read_cnt <= 0;
                block_ready[read_bank] <= 0;
                read_bank <= ~read_bank;
            end else begin
                read_cnt <= read_cnt + 1;
            end
        end else begin
            tvalid_o <= 0;
        end
    end

endmodule
