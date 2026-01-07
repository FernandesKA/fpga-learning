module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200,
    parameter DATA_WIDTH = 8,
    parameter STOP_BITS = 1,
    parameter PARITY_EN = 0,
    parameter PARITY_TYPE = 0
)(
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic        tx_start,
    input  logic [7:0]  tx_data,
    output logic        tx_busy,
    output logic        tx_done,
    
    output logic        tx
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    localparam BIT_COUNTER_WIDTH = $clog2(BIT_PERIOD);
    localparam DATA_COUNTER_WIDTH = $clog2(DATA_WIDTH + 4);
    
    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_START_BIT,
        STATE_DATA_BITS,
        STATE_PARITY_BIT,
        STATE_STOP_BIT,
        STATE_DONE
    } state_t;
    
    state_t state, next_state;
    
    logic [BIT_COUNTER_WIDTH-1:0] bit_timer;
    logic bit_timer_done;
    logic [DATA_COUNTER_WIDTH-1:0] data_counter;
    logic parity_bit;
    
    generate
        if (PARITY_EN) begin
            always_comb begin
                if (PARITY_TYPE == 0) begin
                    parity_bit = ~^tx_data;
                end else begin
                    parity_bit = ^tx_data;
                end
            end
        end else begin
            assign parity_bit = 1'b0;
        end
    endgenerate
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_timer <= 0;
        end else if (state != next_state) begin
            bit_timer <= 0;
        end else if (!bit_timer_done) begin
            bit_timer <= bit_timer + 1;
        end
    end
    
    assign bit_timer_done = (bit_timer == BIT_PERIOD - 1);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_counter <= 0;
        end else if (state != next_state) begin
            data_counter <= 0;
        end else if (bit_timer_done && state == STATE_DATA_BITS) begin
            data_counter <= data_counter + 1;
        end
    end
    
    logic [DATA_WIDTH-1:0] shift_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 0;
        end else if (tx_start && state == STATE_IDLE) begin
            shift_reg <= tx_data;
        end else if (bit_timer_done && state == STATE_DATA_BITS) begin
            shift_reg <= {1'b0, shift_reg[DATA_WIDTH-1:1]};
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always_comb begin
        next_state = state;
        tx_done = 1'b0;
        tx_busy = 1'b1;
        tx = 1'b1;
        
        case (state)
            STATE_IDLE: begin
                tx_busy = 1'b0;
                tx = 1'b1;
                if (tx_start) begin
                    next_state = STATE_START_BIT;
                end
            end
            
            STATE_START_BIT: begin
                tx = 1'b0;
                if (bit_timer_done) begin
                    next_state = STATE_DATA_BITS;
                end
            end
            
            STATE_DATA_BITS: begin
                tx = shift_reg[0];
                if (bit_timer_done && (data_counter == DATA_WIDTH - 1)) begin
                    if (PARITY_EN) begin
                        next_state = STATE_PARITY_BIT;
                    end else begin
                        next_state = STATE_STOP_BIT;
                    end
                end
            end
            
            STATE_PARITY_BIT: begin
                tx = parity_bit;
                if (bit_timer_done) begin
                    next_state = STATE_STOP_BIT;
                end
            end
            
            STATE_STOP_BIT: begin
                tx = 1'b1;
                if (bit_timer_done) begin
                    if (STOP_BITS == 2 && data_counter == 0) begin
                        data_counter = 1'b1;
                    end else begin
                        next_state = STATE_DONE;
                    end
                end
            end
            
            STATE_DONE: begin
                tx = 1'b1;
                tx_done = 1'b1;
                next_state = STATE_IDLE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end
    
endmodule