module uart_rx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200,
    parameter DATA_WIDTH = 8,
    parameter STOP_BITS = 1,
    parameter PARITY_EN = 0,
    parameter PARITY_TYPE = 0
)(
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic        rx,
    
    output logic [7:0]  rx_data,
    output logic        rx_valid,
    output logic        rx_error,
    output logic        rx_busy
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT_PERIOD = BIT_PERIOD / 2;
    localparam BIT_COUNTER_WIDTH = $clog2(BIT_PERIOD);
    localparam DATA_COUNTER_WIDTH = $clog2(DATA_WIDTH + 3);
    
    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_START_DETECT,
        STATE_DATA_BITS,
        STATE_PARITY_BIT,
        STATE_STOP_BIT,
        STATE_DONE
    } state_t;
    
    state_t state, next_state;
    
    logic [BIT_COUNTER_WIDTH-1:0] bit_timer;
    logic bit_timer_done;
    logic half_bit_timer_done;
    logic [DATA_COUNTER_WIDTH-1:0] data_counter;
    logic [DATA_WIDTH-1:0] shift_reg;
    logic parity_bit;
    logic rx_sync;
    logic rx_sync_prev;
    
    logic received_parity;
    logic calculated_parity;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync <= 1'b1;
            rx_sync_prev <= 1'b1;
        end else begin
            rx_sync_prev <= rx_sync;
            rx_sync <= rx;
        end
    end
    
    logic start_edge;
    assign start_edge = rx_sync_prev & ~rx_sync;
    
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
    assign half_bit_timer_done = (bit_timer == HALF_BIT_PERIOD - 1);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_counter <= 0;
        end else if (state != next_state) begin
            data_counter <= 0;
        end else if (bit_timer_done && state == STATE_DATA_BITS) begin
            data_counter <= data_counter + 1;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 0;
        end else if (bit_timer_done && state == STATE_DATA_BITS) begin
            shift_reg <= {rx_sync, shift_reg[DATA_WIDTH-1:1]};
        end
    end
    
    generate
        if (PARITY_EN) begin
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    received_parity <= 0;
                end else if (bit_timer_done && state == STATE_PARITY_BIT) begin
                    received_parity <= rx_sync;
                end
            end
            
            assign calculated_parity = (PARITY_TYPE == 0) ? 
                                      ~^shift_reg :
                                      ^shift_reg;
                                      
            assign parity_bit = calculated_parity;
        end else begin
            assign parity_bit = 1'b0;
            assign received_parity = 1'b0;
            assign calculated_parity = 1'b0;
        end
    endgenerate
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always_comb begin
        next_state = state;
        rx_valid = 1'b0;
        rx_error = 1'b0;
        rx_busy = 1'b1;
        rx_data = shift_reg;
        
        case (state)
            STATE_IDLE: begin
                rx_busy = 1'b0;
                if (start_edge) begin
                    next_state = STATE_START_DETECT;
                end
            end
            
            STATE_START_DETECT: begin
                if (half_bit_timer_done) begin
                    if (!rx_sync) begin
                        next_state = STATE_DATA_BITS;
                    end else begin
                        next_state = STATE_IDLE;
                    end
                end
            end
            
            STATE_DATA_BITS: begin
                if (bit_timer_done && (data_counter == DATA_WIDTH - 1)) begin
                    if (PARITY_EN) begin
                        next_state = STATE_PARITY_BIT;
                    end else begin
                        next_state = STATE_STOP_BIT;
                    end
                end
            end
            
            STATE_PARITY_BIT: begin
                if (bit_timer_done) begin
                    if (PARITY_EN && (received_parity != parity_bit)) begin
                        rx_error = 1'b1;
                    end
                    next_state = STATE_STOP_BIT;
                end
            end
            
            STATE_STOP_BIT: begin
                if (bit_timer_done) begin
                    if (!rx_sync) begin
                        rx_error = 1'b1;
                    end
                    next_state = STATE_DONE;
                end
            end
            
            STATE_DONE: begin
                rx_valid = 1'b1;
                next_state = STATE_IDLE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end
    
endmodule