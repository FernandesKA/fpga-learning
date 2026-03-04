/**
 * @file bitreverse_permute
 * @brief Ping-pong bitreverse
 */

`timescale 1ns / 1ps

module bitreverse_permute #(
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned MAX_BLOCK_LENGTH_LOG2 = 8
) (
    input  logic clk_i,
    input  logic srst_i,

    input  logic [DATA_WIDTH-1:0] tdata_i,
    input  logic                  tvalid_i,

    input  logic [$clog2(MAX_BLOCK_LENGTH_LOG2)-1:0] block_length_log2_i,

    output logic [DATA_WIDTH-1:0] tdata_o,
    output logic                  tvalid_o
);

    localparam int unsigned MAX_DEPTH = 1 << MAX_BLOCK_LENGTH_LOG2;

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem0 [0:MAX_DEPTH-1];
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem1 [0:MAX_DEPTH-1];

    logic [MAX_BLOCK_LENGTH_LOG2-1:0] write_cnt, read_cnt;
    logic [MAX_BLOCK_LENGTH_LOG2-1:0] block_size;

    logic write_bank;
    logic [1:0] block_ready;

    wire read_bank = ~write_bank;

    always_ff @(posedge clk_i) begin
        block_size <= 1 << block_length_log2_i;
    end

    function automatic logic [MAX_BLOCK_LENGTH_LOG2-1:0] bitrev(
        input logic [MAX_BLOCK_LENGTH_LOG2-1:0] value,
        input logic [$clog2(MAX_BLOCK_LENGTH_LOG2):0] width
    );
        logic [MAX_BLOCK_LENGTH_LOG2-1:0] result;
        int i;
        begin
            result = '0;

            for (i = 0; i < MAX_BLOCK_LENGTH_LOG2; i++) begin
                if (i < width)
                    result[i] = value[width-1-i];
                else
                    result[i] = 1'b0;
            end

            return result;
        end
    endfunction

    /*write side */
    always_ff @(posedge clk_i) begin
        if (srst_i) begin
            write_cnt   <= 0;
            write_bank  <= 0;
            block_ready <= 2'b00;
        end
        else begin
            if (tvalid_i) begin

                if (write_bank == 0)
                    mem0[write_cnt] <= tdata_i;
                else
                    mem1[write_cnt] <= tdata_i;

                if (write_cnt == block_size-1) begin
                    write_cnt <= 0;

                    block_ready[write_bank] <= 1'b1;

                    write_bank <= ~write_bank;
                end
                else begin
                    write_cnt <= write_cnt + 1;
                end
            end
        end
    end

    logic [MAX_BLOCK_LENGTH_LOG2-1:0] rev_addr;

    /* read side */
    always_ff @(posedge clk_i) begin
        if (srst_i) begin
            read_cnt  <= 0;
            tvalid_o  <= 0;
        end
        else begin
            tvalid_o <= 0;

            if (block_ready[read_bank]) begin
                tvalid_o <= 1;

                rev_addr = bitrev(read_cnt, block_length_log2_i);

                if (read_bank == 0)
                    tdata_o <= mem0[rev_addr];
                else
                    tdata_o <= mem1[rev_addr];

                if (read_cnt == block_size-1) begin
                    read_cnt <= 0;
                    block_ready[read_bank] <= 1'b0;
                end
                else begin
                    read_cnt <= read_cnt + 1;
                end
            end
        end
    end

endmodule