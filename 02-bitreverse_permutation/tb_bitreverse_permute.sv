`timescale 1ns / 1ps

module bitreverse_permute_bram_tb;

    parameter DATA_WIDTH = 16;
    parameter MAX_BLOCK_LENGTH_LOG2 = 7;

    logic                                         clk;
    logic                                         srst;

    logic [                       DATA_WIDTH-1:0] tdata_i;
    logic                                         tvalid_i;

    logic [$clog2(MAX_BLOCK_LENGTH_LOG2 + 1)-1:0] block_length_log2_i;

    logic [                       DATA_WIDTH-1:0] tdata_o;
    logic                                         tvalid_o;

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

    localparam FRAME_LOG2 = 7;  // 1 << Frame_log2 elements
    localparam FRAMES = 5;

    localparam BLOCK = 1 << (FRAME_LOG2 + 1);
    localparam TOTAL = BLOCK * FRAMES;

    logic [DATA_WIDTH-1:0] input_stream   [0:TOTAL-1];
    logic [DATA_WIDTH-1:0] expected_stream[0:TOTAL-1];

    function automatic int bitrev(input int value, input int width);
        int result;
        int i;
        begin
            result = 0;
            for (i = 0; i < width; i++) result |= ((value >> i) & 1) << (width - 1 - i);
            return result;
        end
    endfunction

    initial begin
        int f, i, global_index, rev;

        srst = 1;
        tvalid_i = 0;
        tdata_i = 0;
        block_length_log2_i = FRAME_LOG2;
        #20;
        srst = 0;

        for (f = 0; f < FRAMES; f = f + 1) begin
            int block_start = f * BLOCK;
            for (i = 0; i < BLOCK; i = i + 1) begin
                global_index = block_start + i;
                input_stream[global_index] = global_index;

                rev = bitrev(i, FRAME_LOG2 + 1);
                expected_stream[block_start+rev] = global_index;
            end
        end

        fork
            drive_stream();
            check_stream();
        join

        $display("=====================================");
        $display("STREAMING MULTI-FRAME TEST PASSED");
        $display("=====================================");
        $stop;
    end

    task automatic drive_stream;
        int i;
        begin
            for (i = 0; i < TOTAL; i = i + 1) begin
                @(posedge clk);
                tvalid_i <= 1;
                tdata_i  <= input_stream[i];
            end
            @(posedge clk);
            tvalid_i <= 0;
        end
    endtask

    task automatic check_stream;
        int count;
        reg started;
        begin
            count   = 0;
            started = 0;

            // wait for ready = 1
            #(BLOCK * 10);

            while (count < TOTAL) begin
                @(posedge clk);

                if (tvalid_o) begin
                    if (!started) started = 1;

                    if (tdata_o !== expected_stream[count]) begin
                        $display("ERROR at %0d: got %0d expected %0d", count, tdata_o, expected_stream[count]);
                        $stop;
                    end

                    count = count + 1;
                end else if (started) begin
                    $display("ERROR: tvalid_o dropped during streaming at %0d", count);
                    $stop;
                end
            end
        end
    endtask

endmodule
