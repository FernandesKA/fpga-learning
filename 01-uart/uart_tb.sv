module uart_tb;
    localparam CLK_PERIOD = 10;  // 100 MHz
    localparam BIT_PERIOD = 868; // Для 115200 бод при 100 MHz
    
    logic clk;
    logic rst_n;
    logic tx_start;
    logic [7:0] tx_data;
    logic tx_busy;
    logic tx_done;
    logic tx;
    logic rx;
    logic [7:0] rx_data;
    logic rx_valid;
    logic rx_error;
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        tx_start = 0;
        tx_data = 0;
        rx = 1;
        #100;
        rst_n = 1;
        #100;
        
        tx_data = 8'h55;
        tx_start = 1;
        #10;
        tx_start = 0;
        
        wait(tx_done);
        #100;
        
        send_byte(8'hAA);
        
        #1000;
        $display("Test completed");
        $finish;
    end
    
    task send_byte(input logic [7:0] data);
        integer i;
        begin
            rx = 0;
            #BIT_PERIOD;
            
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #BIT_PERIOD;
            end
            
            rx = 1;
            #BIT_PERIOD;
        end
    endtask
    
    // DUT
    uart_top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done),
        .tx         (tx),
        .rx         (rx),
        .rx_data    (rx_data),
        .rx_valid   (rx_valid),
        .rx_error   (rx_error)
    );
    
    always @(posedge rx_valid) begin
        $display("[%0t] Received data: 0x%h", $time, rx_data);
    end
    
    always @(posedge rx_error) begin
        $display("[%0t] RX Error detected!", $time);
    end
    
    always @(posedge tx_done) begin
        $display("[%0t] TX completed", $time);
    end
    
endmodule