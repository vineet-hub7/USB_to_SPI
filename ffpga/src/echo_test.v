// Slave-only echo test -- isolates the spi_target RX + MISO path from the
// SPI master.  The FPGA captures each byte from the RP2040 and returns it
// on the MISO of the NEXT transfer (one-transfer-delayed echo).
//
// Map exactly like the bridge's input side:
//   spi_sck=GPIO3(in), spi_ss_n=GPIO4(in), spi_mosi=GPIO5(in),
//   spi_miso=GPIO6(out, +spi_miso_en), clk/clk_en=oscillator, led=GPIO16
//
// Test from the RP2040 (no jumper needed):
//   send a byte, read reply -> reply[i] should equal byte[i-1].
// Build: top file = this + spi_target.v
(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input  clk,
    (* iopad_external_pin *)                 output clk_en,
    (* iopad_external_pin *)                 input  spi_ss_n,
    (* iopad_external_pin *)                 input  spi_sck,
    (* iopad_external_pin *)                 input  spi_mosi,
    (* iopad_external_pin *)                 output spi_miso,
    (* iopad_external_pin *)                 output spi_miso_en,
    (* iopad_external_pin *)                 output reg led,
    (* iopad_external_pin *)                 output led_en
);
    assign clk_en = 1'b1;
    assign led_en = 1'b1;

    // internal power-on reset
    reg [3:0] por_cnt = 4'd0;
    reg       rst_n   = 1'b0;
    always @(posedge clk) begin
        if (por_cnt != 4'hF) por_cnt <= por_cnt + 1'b1;
        rst_n <= (por_cnt == 4'hF);
    end

    wire [7:0] rx_data;
    wire       rx_valid;
    reg  [7:0] echo_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        echo_data <= 8'h00;
        else if (rx_valid) echo_data <= rx_data;   // echo received byte
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        led <= 1'b0;
        else if (rx_valid) led <= rx_data[0];
    end

    spi_target #(.CPOL(1'b0), .CPHA(1'b0), .WIDTH(8), .LSB(1'b0)) u_slave (
        .i_clk(clk), .i_rst_n(rst_n), .i_enable(1'b1),
        .i_ss_n(spi_ss_n), .i_sck(spi_sck), .i_mosi(spi_mosi),
        .o_miso(spi_miso), .o_miso_oe(spi_miso_en),
        .o_rx_data(rx_data), .o_rx_data_valid(rx_valid),
        .i_tx_data(echo_data), .o_tx_data_hold()
    );
endmodule
