/**
 * @file bitreverse_pingpong.sv
 * @brief Bitreverse permutation
 */

module bitreverse_permute #(
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

    // Размер блока = 2^(block_length_log2_i + 1)
    localparam int MAX_BLOCK_SIZE_LOG2 = MAX_BLOCK_LENGTH_LOG2 + 1;
    localparam int BANK_DEPTH = 1 << MAX_BLOCK_SIZE_LOG2;
    localparam int TOTAL_DEPTH = 2 * BANK_DEPTH;
    localparam int ADDR_WIDTH = MAX_BLOCK_SIZE_LOG2 + 1;

    logic [MAX_BLOCK_SIZE_LOG2:0] block_size;
    assign block_size = 1 << (block_length_log2_i + 1);

    logic write_bank;
    logic read_bank;
    logic [1:0] bank_full;

    logic [MAX_BLOCK_SIZE_LOG2-1:0] write_cnt;
    logic [MAX_BLOCK_SIZE_LOG2-1:0] read_cnt;

    logic [ADDR_WIDTH-1:0] addra, addrb;
    logic wea;
    logic [DATA_WIDTH-1:0] dina;
    logic [DATA_WIDTH-1:0] doutb;

    logic [DATA_WIDTH-1:0] doutb_reg;
    logic doutb_valid_reg;
    logic read_en;

    function automatic logic [MAX_BLOCK_SIZE_LOG2-1:0] bitrev(input logic [MAX_BLOCK_SIZE_LOG2-1:0] value, input int width);

        logic [MAX_BLOCK_SIZE_LOG2-1:0] result;

        result = '0;

        for (int i = 0; i < MAX_BLOCK_SIZE_LOG2; i++) begin
            if (i < width) result[i] = value[width-1-i];
        end

        return result;

    endfunction

    always_ff @(posedge clk_i) begin
        if (srst_i) begin
            write_cnt  <= '0;
            write_bank <= 1'b0;
            read_cnt   <= '0;
            read_bank  <= 1'b0;
            bank_full  <= 2'b00;
            read_en    <= 1'b0;
        end else begin
            logic [MAX_BLOCK_SIZE_LOG2-1:0] write_cnt_next = write_cnt;
            logic [MAX_BLOCK_SIZE_LOG2-1:0] read_cnt_next = read_cnt;
            logic write_bank_next = write_bank;
            logic read_bank_next = read_bank;
            logic [1:0] bank_full_next = bank_full;

            if (tvalid_i && !bank_full[write_bank]) begin
                if (write_cnt == block_size - 1) begin
                    write_cnt_next = '0;
                    bank_full_next[write_bank] = 1'b1;
                    write_bank_next = ~write_bank;
                end else begin
                    write_cnt_next = write_cnt + 1'b1;
                end
            end

            if (bank_full[read_bank]) begin
                read_en <= 1'b1;
                if (read_cnt == block_size - 1) begin
                    read_cnt_next = '0;
                    bank_full_next[read_bank] = 1'b0;
                    read_bank_next = ~read_bank;
                end else begin
                    read_cnt_next = read_cnt + 1'b1;
                end
            end else begin
                read_en <= 1'b0;
            end

            write_cnt  <= write_cnt_next;
            write_bank <= write_bank_next;
            read_cnt   <= read_cnt_next;
            read_bank  <= read_bank_next;
            bank_full  <= bank_full_next;
        end
    end

    assign tready_o = !bank_full[write_bank];

    assign addra = {write_bank, write_cnt};
    assign wea = tvalid_i && tready_o;
    assign dina = tdata_i;

    wire [MAX_BLOCK_SIZE_LOG2-1:0] rev_addr = bitrev(read_cnt, block_length_log2_i + 1);
    assign addrb = {read_bank, rev_addr};

    always_ff @(posedge clk_i) begin
        doutb_reg       <= doutb;
        doutb_valid_reg <= read_en;
    end

    assign tdata_o  = doutb_reg;
    assign tvalid_o = doutb_valid_reg;

    xpm_memory_tdpram #(
        .MEMORY_SIZE      (TOTAL_DEPTH * DATA_WIDTH),
        .MEMORY_PRIMITIVE ("block"),
        .CLOCKING_MODE    ("common_clock"),
        .ECC_MODE         ("no_ecc"),
        .MEMORY_INIT_FILE ("none"),
        .MEMORY_INIT_PARAM("0"),
        .USE_MEM_INIT     (0),
        .WAKEUP_TIME      ("disable_sleep"),
        .MESSAGE_CONTROL  (0),

        .WRITE_DATA_WIDTH_A(DATA_WIDTH),
        .READ_DATA_WIDTH_A (DATA_WIDTH),
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH),
        .ADDR_WIDTH_A      (ADDR_WIDTH),
        .READ_RESET_VALUE_A("0"),
        .READ_LATENCY_A    (1),

        .WRITE_DATA_WIDTH_B(DATA_WIDTH),
        .READ_DATA_WIDTH_B (DATA_WIDTH),
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH),
        .ADDR_WIDTH_B      (ADDR_WIDTH),
        .READ_RESET_VALUE_B("0"),
        .READ_LATENCY_B    (1)
    ) xpm_inst (
        .douta(),
        .doutb(doutb),

        .clka          (clk_i),
        .clkb          (clk_i),
        .ena           (1'b1),
        .enb           (1'b1),
        .wea           (wea),
        .web           (1'b0),
        .addra         (addra),
        .addrb         (addrb),
        .dina          (dina),
        .dinb          ('0),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .injectsbiterrb(1'b0),
        .injectdbiterrb(1'b0),
        .regcea        (1'b1),
        .regceb        (1'b1),
        .rsta          (srst_i),
        .rstb          (srst_i),
        .sleep         (1'b0)
    );

endmodule
