module uart_top (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic        tx_start,
    input  logic [7:0]  tx_data,
    output logic        tx_busy,
    output logic        tx_done,
    output logic        tx,
    
    input  logic        rx,
    output logic [7:0]  rx_data,
    output logic        rx_valid,
    output logic        rx_error
);

    logic rx_busy;
    
    uart_tx #(
        .CLK_FREQ   (100_000_000),
        .BAUD_RATE  (115_200),
        .DATA_WIDTH (8),
        .STOP_BITS  (1),
        .PARITY_EN  (0),
        .PARITY_TYPE(0)
    ) uart_tx_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done),
        .tx         (tx)
    );
    
    uart_rx #(
        .CLK_FREQ   (100_000_000),
        .BAUD_RATE  (115_200),
        .DATA_WIDTH (8),
        .STOP_BITS  (1),
        .PARITY_EN  (0),
        .PARITY_TYPE(0)
    ) uart_rx_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (rx),
        .rx_data    (rx_data),
        .rx_valid   (rx_valid),
        .rx_error   (rx_error),
        .rx_busy    (rx_busy)
    );
    
endmodule