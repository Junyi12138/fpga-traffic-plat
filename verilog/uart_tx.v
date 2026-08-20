module uart_tx #(
    parameter integer CLK_FREQ = 12_000_000,
    parameter integer BAUD     = 9600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,     
    input  wire       tx_start,    // start signal
    output reg        tx,          // data output
    output reg        busy         // busy signal
);

localparam integer DIVISOR = CLK_FREQ / BAUD;   // 12_000_000/9600 = 1250

localparam [1:0]  IDLE  = 2'd0,
                  START = 2'd1,
                  DATA  = 2'd2,
                  STOP  = 2'd3;

reg [1:0]  state;
reg [15:0] baud_cnt;  
reg [2:0]  bit_idx;    // bit index
reg [7:0]  data_reg;   

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state    <= IDLE;
        tx       <= 1'b1;
        busy     <= 1'b0;
        baud_cnt <= 0;
        bit_idx  <= 0;
        data_reg <= 8'h00;
    end else begin
        case (state)
            IDLE: begin
                tx       <= 1'b1;
                busy     <= 1'b0;
                baud_cnt <= 0;
                if (tx_start) begin
                    data_reg <= data_in;
                    tx       <= 1'b0;   //output first bit
                    busy     <= 1'b1;
                    state    <= START;
                end
            end

            START: begin
                if (baud_cnt == DIVISOR-1) begin
                    baud_cnt <= 0;
                    tx       <= data_reg[0];  // first data bit
                    bit_idx  <= 0;
                    state    <= DATA;
                end
                else
                    baud_cnt <= baud_cnt + 1;
            end

            DATA: begin
                if (baud_cnt == DIVISOR-1) begin
                    baud_cnt <= 0;
                    if (bit_idx == 7) begin
                        tx    <= 1'b1;         // stop bit
                        state <= STOP;
                    end
                    else begin
                        data_reg <= data_reg >> 1;
                        tx       <= data_reg[1];  // next
                        bit_idx  <= bit_idx + 1;
                    end
                end
                else
                    baud_cnt <= baud_cnt + 1;
            end

            STOP: begin
                if (baud_cnt == DIVISOR-1) begin
                    baud_cnt <= 0;
                    busy     <= 1'b0;
                    state    <= IDLE;
                end
                else
                    baud_cnt <= baud_cnt + 1;
            end
        endcase
    end
end

endmodule