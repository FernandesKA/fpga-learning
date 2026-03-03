`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 10:47:20 PM
// Design Name: 
// Module Name: bitreverse_permutate
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


/**
 * @file bitreverse_permute
 * @brief Ping-pong bitreverse module
 */

`timescale 1ns / 1ps

module bitreverse_permute #(
    parameter int unsigned DATA_WIDTH = 16,
    parameter int unsigned MAX_BLOCK_LENGTH_LOG2 = 8
) (
    input logic clk_i,
    input logic srst_i,

    input logic [DATA_WIDTH-1:0] tdata_i,
    input logic                  tvalid_i,

    input logic [$clog2(MAX_BLOCK_LENGTH_LOG2)-1:0] block_length_log2_i,

    output logic [DATA_WIDTH-1:0] tdata_o,
    output logic                  tvalid_o
);

    localparam int unsigned MAX_DEPTH = 1 << MAX_BLOCK_LENGTH_LOG2;

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem0[0:MAX_DEPTH-1];
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem1[0:MAX_DEPTH-1];

    logic wr_bank;
    logic rd_bank;
    logic block_ready[1:0];

    logic [MAX_BLOCK_LENGTH_LOG2:0] write_cnt;
    logic [MAX_BLOCK_LENGTH_LOG2:0] read_cnt;

    logic [MAX_BLOCK_LENGTH_LOG2:0] block_size;

    always_comb begin
        block_size = 1 << (block_length_log2_i + 1);
    end

    logic [MAX_BLOCK_LENGTH_LOG2-1:0] reversed_cnt;
    logic [MAX_BLOCK_LENGTH_LOG2-1:0] read_addr;
    logic [MAX_BLOCK_LENGTH_LOG2-1:0] read_addr_reg;

    always_comb begin
        for (int i = 0; i < MAX_BLOCK_LENGTH_LOG2; i++) reversed_cnt[i] = read_cnt[MAX_BLOCK_LENGTH_LOG2-1-i];

        read_addr = reversed_cnt >> (MAX_BLOCK_LENGTH_LOG2 - (block_length_log2_i + 1));
    end

    always_ff @(posedge clk_i) begin
        if (srst_i) begin
            wr_bank <= 1'b0;
            rd_bank <= 1'b0;
            write_cnt <= '0;
            read_cnt <= '0;
            block_ready[0] <= 1'b0;
            block_ready[1] <= 1'b0;
            read_addr_reg <= '0;
            tdata_o <= '0;
            tvalid_o <= 1'b0;
        end else begin
            tvalid_o <= 1'b0;

            /* write */
            if (tvalid_i) begin
                if (wr_bank == 1'b0) mem0[write_cnt] <= tdata_i;
                else mem1[write_cnt] <= tdata_i;

                write_cnt <= write_cnt + 1;

                if (write_cnt + 1 == block_size) begin
                    block_ready[wr_bank] <= 1'b1;
                    write_cnt <= '0;
                    wr_bank <= ~wr_bank;
                end
            end

            /* read */
            if (block_ready[rd_bank]) begin
                read_addr_reg <= read_addr;
                tvalid_o <= 1'b1;

                if (rd_bank == 1'b0) tdata_o <= mem0[read_addr_reg];
                else tdata_o <= mem1[read_addr_reg];

                read_cnt <= read_cnt + 1;

                if (read_cnt + 1 == block_size) begin
                    block_ready[rd_bank] <= 1'b0;
                    read_cnt <= '0;
                    rd_bank <= ~rd_bank;
                end
            end
        end
    end

endmodule
