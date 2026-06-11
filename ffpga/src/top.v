(* top *) module top (
(* iopad_external_pin, clkbuf_inhibit *) input  clk,
(* iopad_external_pin *) output clk_en,
(* iopad_external_pin *) input spi_ss_n,
(* iopad_external_pin *) input spi_sck,
(* iopad_external_pin *) input spi_mosi,
(* iopad_external_pin *) output spi_miso,
(* iopad_external_pin *) output spi_miso_en,
(* iopad_external_pin *) output m_ss_n,
(* iopad_external_pin *) output m_ss_n_en,
(* iopad_external_pin *) output m_sck,
(* iopad_external_pin *) output m_sck_en,
(* iopad_external_pin *) output m_mosi,
(* iopad_external_pin *) output m_mosi_en,
(* iopad_external_pin *) input m_miso,
(* iopad_external_pin *) output reg led,
(* iopad_external_pin *) output led_en);
assign clk_en = 1'b1;
assign led_en = 1'b1;
assign m_ss_n_en = 1'b1;
assign m_sck_en = 1'b1;
assign m_mosi_en = 1'b1;
reg [3:0] por_cnt = 4'd0;
reg rst_n = 1'b0;
always @(posedge clk) begin
        if (por_cnt != 4'hF) por_cnt <= por_cnt + 1'b1;
        rst_n <= (por_cnt == 4'hF);
    end

    wire [7:0] rx_data;
    wire rx_valid;

    wire [7:0] m_rx_data;
    wire m_busy;
    wire m_done;

    reg [7:0] m_tx_data;      
    reg m_start;      
    reg [7:0] return_data;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_tx_data <= 8'h00;
            m_start <= 1'b0;
        end else begin
            m_start <= 1'b0;
            if (rx_valid && !m_busy && !m_start) begin
                m_tx_data <= rx_data;
                m_start <= 1'b1;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) return_data <= 8'h00;
        else if (m_done) return_data <= m_rx_data;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) led <= 1'b0;
        else if (rx_valid) led <= rx_data[0];
    end
    spi_target #(
        .CPOL (1'b0), .CPHA (1'b0), .WIDTH (8), .LSB (1'b0)
    ) u_spi_slave (
        .i_clk(clk),.i_rst_n(rst_n),.i_enable(1'b1),.i_ss_n  (spi_ss_n),
        .i_sck(spi_sck),.i_mosi(spi_mosi),
        .o_miso(spi_miso),
        .o_miso_oe(spi_miso_en),
        .o_rx_data(rx_data),
        .o_rx_data_valid(rx_valid),
        .i_tx_data(return_data),
        .o_tx_data_hold());
    spi_master #(
        .WIDTH (8), .CLK_DIV (64)
    ) u_spi_master (.i_clk(clk),.i_rst_n(rst_n),.i_start(m_start),
        .i_tx_data(m_tx_data),.o_rx_data(m_rx_data),
        .o_busy(m_busy),.o_done(m_done),
        .o_ss_n(m_ss_n),.o_sck(m_sck),.o_mosi(m_mosi),.i_miso(m_miso));
endmodule

module spi_master #(
    parameter WIDTH = 8,
    parameter CLK_DIV = 16 
) (
    input i_clk,
    input i_rst_n,
    input i_start,
    input [WIDTH-1:0]  i_tx_data,
    output reg [WIDTH-1:0]  o_rx_data,
    output reg o_busy,
    output reg o_done,
    output reg o_ss_n,
    output reg o_sck,
    output reg o_mosi,
    input i_miso);
    localparam ST_IDLE = 2'd0, ST_XFER = 2'd1, ST_TAIL = 2'd2;

    reg [1:0] state;
    reg [15:0] div_cnt;
    reg [WIDTH-1:0] tx_shift;
    reg [WIDTH-1:0] rx_shift;
    reg [$clog2(WIDTH+1)-1:0] bit_cnt;

    wire tick = (div_cnt == CLK_DIV-1);
    reg [1:0] miso_sync;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) miso_sync <= 2'b00;
        else miso_sync <= {miso_sync[0], i_miso};
    end
    wire miso_s = miso_sync[1];
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= ST_IDLE; div_cnt <= 0; tx_shift <= 0; rx_shift <= 0;
            bit_cnt <= 0; o_rx_data <= 0; o_busy <= 0; o_done <= 0;
            o_ss_n <= 1'b1; o_sck <= 1'b0; o_mosi <= 1'b0;
        end else begin
            o_done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    o_sck <= 1'b0;
                    o_ss_n <= 1'b1;
                    if (i_start) begin
                        tx_shift <= i_tx_data;
                        o_mosi <= i_tx_data[WIDTH-1];
                        rx_shift <= 0; bit_cnt <= 0; div_cnt <= 0;
                        o_ss_n <= 1'b0; o_busy <= 1'b1;
                        state <= ST_XFER;
                    end
                end
                ST_XFER: begin
                    if (tick) begin
                        div_cnt <= 0;
                        o_sck <= ~o_sck;
                        if (!o_sck) begin 
                            rx_shift <= {rx_shift[WIDTH-2:0], miso_s};
                            bit_cnt <= bit_cnt + 1'b1;
                            if (bit_cnt == WIDTH-1) state <= ST_TAIL;
                        end else begin       
                            tx_shift <= {tx_shift[WIDTH-2:0], 1'b0};
                            o_mosi <= tx_shift[WIDTH-2];
                        end
                    end else div_cnt <= div_cnt + 1'b1;
                end
                ST_TAIL: begin
                    if (tick) begin
                        div_cnt <= 0; o_sck <= 1'b0; o_ss_n <= 1'b1;
                        o_busy <= 1'b0; o_done <= 1'b1; o_rx_data <= rx_shift;
                        state <= ST_IDLE;
                    end else div_cnt <= div_cnt + 1'b1;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule