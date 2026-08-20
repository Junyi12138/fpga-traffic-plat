module road_control(
    input  wire clk_12mhz,
    input  wire rst,
    input  wire start,           // pulse: request a new car onto the road
    input  wire green,           // only checked at the approach/junction boundary
    input  wire step_tick,       // from frame div. move velocity
    input  wire [15:0] time_counter,   // shared between A and B, driven from calculator.v
    input  wire advance_head,          // pulse from calculator.v: "I've read this entry, move on"
    output reg  [9:0] occupied,
    output wire sensor,          // high while a car waits at P6 (last approach slot) for green
    output wire [15:0] entry_rdata     // raw timestamp read from this direction's own BRAM at [head]
);

reg [3:0] head, tail;

wire m0, m1, m2, m3, m4, m5, m6, m7, m8, m9;

assign m0 = step_tick && occupied[0];
assign m1 = step_tick && occupied[1] && (!occupied[0] || m0);
assign m2 = step_tick && occupied[2] && (!occupied[1] || m1);
assign m3 = step_tick && occupied[3] && (!occupied[2] || m2);
assign m4 = step_tick && occupied[4] && (!occupied[3] || m3);
assign m5 = step_tick && occupied[5] && (!occupied[4] || m4);
assign m6 = step_tick && occupied[6] && green && (!occupied[5] || m5);
assign m7 = step_tick && occupied[7] && (!occupied[6] || m6);
assign m8 = step_tick && occupied[8] && (!occupied[7] || m7);
assign m9 = step_tick && occupied[9] && (!occupied[8] || m8);

wire new_car_ok = start && (!occupied[9] || m9);

SB_RAM40_4K #(
    .WRITE_MODE(0),
    .READ_MODE(0)
) u_entry_ram (
    .RDATA (entry_rdata),
    .RCLK  (clk_12mhz),
    .RCLKE (1'b1),
    .RE    (1'b1),
    .RADDR ({7'b0, head}),
    .WCLK  (clk_12mhz),
    .WCLKE (1'b1),
    .WE    (new_car_ok),
    .WADDR ({7'b0, tail}),
    .MASK  (16'h0000),
    .WDATA (time_counter)
);

always @(posedge clk_12mhz or posedge rst) begin
    if (rst) begin
        occupied <= 10'b0;
        head <= 0;
        tail <= 0;
    end
    else begin
        occupied[0] <= (occupied[0] && !m0) || (occupied[1] && m1);
        occupied[1] <= (occupied[1] && !m1) || (occupied[2] && m2);
        occupied[2] <= (occupied[2] && !m2) || (occupied[3] && m3);
        occupied[3] <= (occupied[3] && !m3) || (occupied[4] && m4);
        occupied[4] <= (occupied[4] && !m4) || (occupied[5] && m5);
        occupied[5] <= (occupied[5] && !m5) || (occupied[6] && m6);
        occupied[6] <= (occupied[6] && !m6) || (occupied[7] && m7);
        occupied[7] <= (occupied[7] && !m7) || (occupied[8] && m8);
        occupied[8] <= (occupied[8] && !m8) || (occupied[9] && m9);
        occupied[9] <= (occupied[9] && !m9) || new_car_ok;
        if (new_car_ok) begin
            tail <= (tail == 4'd9) ? 4'd0 : tail + 4'd1;
        end
        if (advance_head) begin
            head <= (head == 4'd9) ? 4'd0 : head + 4'd1;
        end
    end
end

assign sensor = occupied[6];

endmodule