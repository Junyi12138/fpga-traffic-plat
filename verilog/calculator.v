// calculator.v
// Shared arithmetic block that turns each direction's vehicle entry
// timestamps into journey/wait-time statistics. One instance serves
// both A and B (Section 4.1) rather than each direction having its own copy of this logic.
module calculator (
    input  wire        clk,
    input  wire        rst,
    input  wire        step_tick,

    input  wire         car_done_a,
    input  wire [15:0]  entry_rdata_a,
    output reg           advance_head_a,

    input  wire         car_done_b,
    input  wire [15:0]  entry_rdata_b,
    output reg           advance_head_b,

    output wire [15:0]  time_counter_out,

    output wire [15:0]  car_count_a, total_journey_a, max_journey_a, total_wait_a, max_wait_a,
    output wire [15:0]  car_count_b, total_journey_b, max_journey_b, total_wait_b, max_wait_b
);

// Time a car takes to cross with zero delay: the road is 10 positions
localparam [15:0] FREE_FLOW_TIME = 16'd10;

// Shared time reference, incremented once per step_tick. Both
// road_control instances (A and B) use this same counter as the
// timestamp source when a car enters, so journey_time below is always measured against a common clock.
reg [15:0] time_counter;
always @(posedge clk or posedge rst) begin
    if (rst) time_counter <= 0;
    else if (step_tick) time_counter <= time_counter + 16'd1;
end
assign time_counter_out = time_counter;

//A is served first 
//B is served the following cycle.
reg req_a, req_b;
wire dir_to_serve = req_a ? 1'b0 : 1'b1;
wire serving = req_a | req_b;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        req_a <= 0; req_b <= 0;
    end else begin
        if (car_done_a) req_a <= 1;
        else if (serving && !dir_to_serve) req_a <= 0;

        if (car_done_b) req_b <= 1;
        else if (serving && dir_to_serve) req_b <= 0;
    end
end

// journey_time/wait_time for whichever direction is being served this
// cycle. NOTE: entry_rdata comes from a BRAM with a 1-cycle synchronous
// read lag (Section 3.3). Under back-to-back completions on the same
// direction, this can still be showing the previous vehicle's
// timestamp when the next one is served, misattributing journey time
// between them — a known limitation in dense traffic 
wire [15:0] selected_rdata = dir_to_serve ? entry_rdata_b : entry_rdata_a;
wire [15:0] journey_time = time_counter - selected_rdata;
wire [15:0] wait_time = (journey_time > FREE_FLOW_TIME) ? (journey_time - FREE_FLOW_TIME) : 16'd0;

// Per-direction running totals. advance_head pulses for one cycle
// whenever that direction is served, telling road_control's BRAM FIFO to move on to the next entry.
reg [15:0] total_time_a, max_time_a, total_wait_a_r, max_wait_a_r, car_count_a_r;
reg [15:0] total_time_b, max_time_b, total_wait_b_r, max_wait_b_r, car_count_b_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        total_time_a<=0; car_count_a_r<=0; max_time_a<=0; total_wait_a_r<=0; max_wait_a_r<=0;
        total_time_b<=0; car_count_b_r<=0; max_time_b<=0; total_wait_b_r<=0; max_wait_b_r<=0;
        advance_head_a<=0; advance_head_b<=0;
    end
    else begin
        advance_head_a<=0; advance_head_b<=0;

        if (serving) begin
            if (!dir_to_serve) begin
                // Serving A this cycle
                total_time_a   <= total_time_a + journey_time;
                car_count_a_r  <= car_count_a_r + 16'd1;
                if (journey_time > max_time_a) max_time_a <= journey_time;
                total_wait_a_r <= total_wait_a_r + wait_time;
                if (wait_time > max_wait_a_r) max_wait_a_r <= wait_time;
                advance_head_a <= 1;
            end else begin
                // Serving B this cycle
                total_time_b   <= total_time_b + journey_time;
                car_count_b_r  <= car_count_b_r + 16'd1;
                if (journey_time > max_time_b) max_time_b <= journey_time;
                total_wait_b_r <= total_wait_b_r + wait_time;
                if (wait_time > max_wait_b_r) max_wait_b_r <= wait_time;
                advance_head_b <= 1;
            end
        end
    end
end

assign car_count_a=car_count_a_r; assign total_journey_a=total_time_a; assign max_journey_a=max_time_a; assign total_wait_a=total_wait_a_r; assign max_wait_a=max_wait_a_r;

assign car_count_b=car_count_b_r; assign total_journey_b=total_time_b; assign max_journey_b=max_time_b; assign total_wait_b=total_wait_b_r; assign max_wait_b=max_wait_b_r;

endmodule