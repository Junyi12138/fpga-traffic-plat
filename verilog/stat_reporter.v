module stat_reporter (
    input  wire        clk,
    input  wire        rst,
    input  wire        read_stats,

    input  wire [15:0]  car_count_a,
    input  wire [15:0]  total_journey_a,
    input  wire [15:0]  max_journey_a,
    input  wire [15:0]  total_wait_a,
    input  wire [15:0]  max_wait_a,

    input  wire [15:0]  car_count_b,
    input  wire [15:0]  total_journey_b,
    input  wire [15:0]  max_journey_b,
    input  wire [15:0]  total_wait_b,
    input  wire [15:0]  max_wait_b,

    output wire         tx
);

localparam [2:0]
    S_IDLE      = 3'd0,
    S_TX_START  = 3'd1,
    S_TX_ARM    = 3'd2,
    S_TX_WAIT   = 3'd3,
    S_NEXT_BYTE = 3'd4,
    S_NEXT_DIR  = 3'd5;

reg [2:0] state;
reg [2:0] return_state;

reg [1:0] dir_idx;
reg [3:0] byte_idx;
reg [7:0] dir_char;

reg [15:0] snap0, snap1, snap2, snap3, snap4;

// double-flop sync + debounce for read_stats: kept, this addressed a real
// GPIO-level concern unrelated to the getty/ttyAMA0 conflict
reg read_stats_sync1, read_stats_sync2, read_stats_d;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        read_stats_sync1 <= 0;
        read_stats_sync2 <= 0;
        read_stats_d     <= 0;
    end else begin
        read_stats_sync1 <= read_stats;
        read_stats_sync2 <= read_stats_sync1;
        read_stats_d     <= read_stats_sync2;
    end
end

localparam [15:0] DEBOUNCE_THRESHOLD = 16'd6000;
reg [15:0] low_time_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) low_time_cnt <= 0;
    else if (!read_stats_sync2)
        low_time_cnt <= (low_time_cnt == 16'hFFFF) ? low_time_cnt : low_time_cnt + 16'd1;
    else
        low_time_cnt <= 0;
end

wire read_stats_pulse = read_stats_sync2 && !read_stats_d && (low_time_cnt >= DEBOUNCE_THRESHOLD);

reg  [7:0] uart_data;
reg        uart_start;
wire       uart_busy;

uart_tx #(.CLK_FREQ(12_000_000), .BAUD(9600)) u_uart (
    .clk(clk), .rst(rst),
    .data_in(uart_data),
    .tx_start(uart_start),
    .tx(tx),
    .busy(uart_busy)
);

function [7:0] byte_for_idx;
    input [3:0] idx;
    begin
        case (idx)
            4'd1:  byte_for_idx = snap0[15:8];
            4'd2:  byte_for_idx = snap0[7:0];
            4'd3:  byte_for_idx = snap1[15:8];
            4'd4:  byte_for_idx = snap1[7:0];
            4'd5:  byte_for_idx = snap2[15:8];
            4'd6:  byte_for_idx = snap2[7:0];
            4'd7:  byte_for_idx = snap3[15:8];
            4'd8:  byte_for_idx = snap3[7:0];
            4'd9:  byte_for_idx = snap4[15:8];
            4'd10: byte_for_idx = snap4[7:0];
            default: byte_for_idx = 8'h0A;   // idx==11
        endcase
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state      <= S_IDLE;
        dir_idx    <= 0;
        byte_idx   <= 0;
        uart_start <= 0;
    end
    else begin
        uart_start <= 0;

        case (state)

            S_IDLE: begin
                if (read_stats_pulse) begin
                    dir_idx <= 0;
                    snap0 <= car_count_a;
                    snap1 <= total_journey_a;
                    snap2 <= max_journey_a;
                    snap3 <= total_wait_a;
                    snap4 <= max_wait_a;
                    dir_char <= "A";

                    uart_data    <= "A";
                    byte_idx     <= 0;
                    return_state <= S_NEXT_BYTE;
                    state        <= S_TX_START;
                end
            end

            S_TX_START: begin
                uart_start <= 1;
                state      <= S_TX_ARM;
            end
            S_TX_ARM: begin
                if (uart_busy)
                    state <= S_TX_WAIT;
            end
            S_TX_WAIT: begin
                if (!uart_busy)
                    state <= return_state;
            end

            S_NEXT_BYTE: begin
                if (byte_idx == 11) begin
                    state <= S_NEXT_DIR;
                end else begin
                    byte_idx     <= byte_idx + 4'd1;
                    uart_data    <= byte_for_idx(byte_idx + 4'd1);
                    return_state <= S_NEXT_BYTE;
                    state        <= S_TX_START;
                end
            end

            S_NEXT_DIR: begin
                if (dir_idx == 2'd1) begin
                    state <= S_IDLE;
                end else begin
                    dir_idx      <= dir_idx + 2'd1;
                    byte_idx     <= 0;
                    return_state <= S_NEXT_BYTE;
                    state        <= S_TX_START;

                    snap0 <= car_count_b;
                    snap1 <= total_journey_b;
                    snap2 <= max_journey_b;
                    snap3 <= total_wait_b;
                    snap4 <= max_wait_b;
                    dir_char  <= "B";
                    uart_data <= "B";
                end
            end

        endcase
    end
end

endmodule