module road_control_lite(
    input  wire clk_12mhz,
    input  wire rst,
    input  wire start,
    input  wire green,
    input  wire step_tick,
    output reg  [9:0] occupied,
    output wire sensor
);

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

always @(posedge clk_12mhz or posedge rst) begin
    if (rst) begin
        occupied <= 10'b0;
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
    end
end

assign sensor = occupied[6];

endmodule