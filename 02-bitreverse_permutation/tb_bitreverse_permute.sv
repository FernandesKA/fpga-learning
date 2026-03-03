`timescale 1ns / 1ps

module bitreverse_permute_tb;

    parameter DATA_WIDTH = 16;
    parameter MAX_BLOCK_LENGTH_LOG2 = 8;
    localparam int MAX_DEPTH = 1 << MAX_BLOCK_LENGTH_LOG2;

    logic clk;
    logic srst;

    logic [DATA_WIDTH-1:0] tdata_i;
    logic                  tvalid_i;
    logic [$clog2(MAX_BLOCK_LENGTH_LOG2+1)-1:0] block_length_log2_i;

    logic [DATA_WIDTH-1:0] tdata_o;
    logic                  tvalid_o;

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT instantiation
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

    logic [DATA_WIDTH-1:0] input_block   [0:MAX_DEPTH-1];
    logic [DATA_WIDTH-1:0] expected_block[0:MAX_DEPTH-1];

    function int bitrev_block(input int value, input int width);
        int rev;
        int i;
        begin
            rev = 0;
            for (i = 0; i < width; i = i + 1)
                rev = rev | (((value >> i) & 1) << (width-1-i));
            return rev & ((1 << width)-1);
        end
    endfunction

    initial begin
        int N = 1 << (7+1); // 256
        int sent = 0;
        int received = 0;
        int timeout = 0;

        srst = 1; tvalid_i = 0; tdata_i = 0; block_length_log2_i = 7;
        repeat (5) @(posedge clk);
        srst = 0;

        for (int i = 0; i < N; i++) begin
            input_block[i] = i;
            expected_block[bitrev_block(i, block_length_log2_i+1)] = i;
        end

        sent = 0;
        while (sent < N) begin
            @(posedge clk);
            if ($urandom_range(0,1)) begin
                tvalid_i <= 1;
                tdata_i  <= input_block[sent];
                sent = sent + 1;
            end else tvalid_i <= 0;
        end
        @(posedge clk); tvalid_i <= 0;

        received = 0;
        timeout  = 0;
        while (received < N) begin
            @(posedge clk);
            if (tvalid_o) begin
                if (tdata_o !== expected_block[received]) begin
                    $display("ERROR at %0d: got %0d expected %0d", received, tdata_o, expected_block[received]);
                    $fatal;
                end
                received = received + 1;
            end
            timeout = timeout + 1;
            if (timeout > 10000) begin
                $display("TIMEOUT");
                $fatal;
            end
        end

        $display("TEST PASSED");
        $finish;
    end

endmodule