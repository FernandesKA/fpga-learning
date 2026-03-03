`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 10:51:48 PM
// Design Name: 
// Module Name: tb_bitreverse_permute
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
 * @file bitreverse_permute_bram_tb
 * @brief Testbench for bitreverse_permute
 */

`timescale 1ns / 1ps

module bitreverse_permute_bram_tb;

    parameter DATA_WIDTH = 16;
    parameter MAX_BLOCK_LENGTH_LOG2 = 8;

    logic                                     clk;
    logic                                     srst;

    logic [                   DATA_WIDTH-1:0] tdata_i;
    logic                                     tvalid_i;

    logic [$clog2(MAX_BLOCK_LENGTH_LOG2)-1:0] block_length_log2_i;

    logic [                   DATA_WIDTH-1:0] tdata_o;
    logic                                     tvalid_o;

    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz


    bitreverse_permute #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_BLOCK_LENGTH_LOG2(MAX_BLOCK_LENGTH_LOG2)
    ) dut (
        .clk_i(clk),
        .srst_i(srst),
        .tdata_i(tdata_i),
        .tvalid_i(tvalid_i),
        .block_length_log2_i(block_length_log2_i),
        .tdata_o(tdata_o),
        .tvalid_o(tvalid_o)
    );

    localparam MAX_BLOCK = 1 << (MAX_BLOCK_LENGTH_LOG2 + 1);
    logic [DATA_WIDTH-1:0] input_block[0:MAX_BLOCK-1];
    logic [DATA_WIDTH-1:0] expected_block[0:MAX_BLOCK-1];

    function automatic [MAX_BLOCK_LENGTH_LOG2:0] bitrev(input [MAX_BLOCK_LENGTH_LOG2-1:0] value, input int width);
        logic [MAX_BLOCK_LENGTH_LOG2-1:0] tmp;
        int i;
        begin
            tmp = '0;
            for (i = 0; i < width; i++) tmp[i] = value[width-1-i];
            return tmp;
        end
    endfunction

    initial begin
        srst = 1;
        tvalid_i = 0;
        tdata_i = '0;
        block_length_log2_i = 7;

        #20 srst = 0;

        for (int i = 0; i < (1 << (block_length_log2_i + 1)); i++) begin
            input_block[i] = i;
            expected_block[bitrev(i, block_length_log2_i+1)] = i;
        end

        for (int i = 0; i <= (1 << (block_length_log2_i + 1));) begin
            @(posedge clk);
            if ($urandom_range(0, 1)) begin
                tvalid_i <= 1;
                tdata_i  <= input_block[i];
                i = i + 1;
            end else begin
                tvalid_i <= 0;
            end
        end
        tvalid_i <= 0;

        wait_output();

        $display("TEST PASSED");
        $stop;
    end

    task automatic wait_output();
        int count;
        begin
            count = 0;
            while (count < (1 << (block_length_log2_i + 1))) begin
                @(posedge clk);
                if (tvalid_o) begin
                    if (tdata_o !== expected_block[count + 1]) begin
                        $display("ERROR: output mismatch at count %0d: got %0d, expected %0d", count, tdata_o, expected_block[count]);
                        $stop;
                    end
                    count = count + 1;
                end
            end
        end
    endtask

endmodule
