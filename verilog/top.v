module top (
    input  wire clk_12mhz,
    input  wire rst,
    input  wire start_a,
    input  wire start_b,
    input  wire start_c,
    input  wire start_d,
    input  wire Pb,
    input  wire read_stats,
    output wire ds,
    output wire shcp,
    output wire stcp,
    output wire buzzer_out,
    output wire uart_tx_pin
);
    //clock divider
   wire frame_buzzer;
   frame_clk_div #(.DIV_COUNT(3000)) u_frame_buzzer(
    .clk_12mhz(clk_12mhz),
    .rst(rst),
    .frame_clk(frame_buzzer)
   );

   wire frame_road;
   frame_clk_div #(.DIV_COUNT(6_000_000)) u_frame_road(
    .clk_12mhz(clk_12mhz),
    .rst(rst),
    .frame_clk(frame_road)
   );



    //traffic_light
    wire Ga, Ya, Ra, Gb, Yb, Rb, Gp, Rp;
    wire sensor_a, sensor_b, sensor_c, sensor_d;
    wire sensor_ac = sensor_a | sensor_c;   // A or C has a car waiting -> AC group needs green
    wire sensor_bd = sensor_b | sensor_d;   // B or D has a car waiting -> BD group needs green

    traffic_light_extend u_traffic(
        .clk(clk_12mhz),
        .rst(rst),
        .Sa(sensor_ac),
        .Sb(sensor_bd),
        .Pb(Pb),
        .Ga(Ga),.Ya(Ya),.Ra(Ra),
        .Gb(Gb),.Yb(Yb),.Rb(Rb),
        .Gp(Gp),.Rp(Rp)
    );

    wire Gc, Yc, Rc, Gd, Yd, Rd;
    assign Gc = Ga;  assign Yc = Ya;  assign Rc = Ra;
    assign Gd = Gb;  assign Yd = Yb;  assign Rd = Rb;

    //buzzer
    buzzer_gate u_buzzer(
        .pedestrian_green(Gp),
        .buzz_clk(frame_buzzer),
        .buzzer_out(buzzer_out)
    );

    //road_control
    // A and B share one calculator.v (time_counter + journey/wait arithmetic shared;
    // BRAM entry stays per-direction). C and D use road_control_lite (no stats).
    wire [9:0] occupied_a, occupied_b, occupied_c, occupied_d;

    reg frame_road_d;
    always @(posedge clk_12mhz or posedge rst) begin
        if (rst) frame_road_d <= 0;
        else     frame_road_d <= frame_road;
    end

    wire step_tick = frame_road && !frame_road_d;   // one-cycle pulse on frame_road's rising edge

    wire car_done_a = step_tick && occupied_a[0];
    wire car_done_b = step_tick && occupied_b[0];

    wire [15:0] shared_time_counter;
    wire [15:0] entry_rdata_a, entry_rdata_b;
    wire advance_head_a, advance_head_b;

    road_control u_road_a(
        .clk_12mhz    (clk_12mhz),
        .rst          (rst),
        .start        (start_a),
        .green        (Ga),
        .step_tick    (step_tick),
        .time_counter (shared_time_counter),
        .advance_head (advance_head_a),
        .occupied     (occupied_a),
        .sensor       (sensor_a),
        .entry_rdata  (entry_rdata_a)
    );

    road_control u_road_b(
        .clk_12mhz    (clk_12mhz),
        .rst          (rst),
        .start        (start_b),
        .green        (Gb),
        .step_tick    (step_tick),
        .time_counter (shared_time_counter),
        .advance_head (advance_head_b),
        .occupied     (occupied_b),
        .sensor       (sensor_b),
        .entry_rdata  (entry_rdata_b)
    );

    road_control_lite u_road_c(
        .clk_12mhz (clk_12mhz),
        .rst       (rst),
        .start     (start_c),
        .green     (Gc),
        .step_tick (step_tick),
        .occupied  (occupied_c),
        .sensor    (sensor_c)
    );

    road_control_lite u_road_d(
        .clk_12mhz (clk_12mhz),
        .rst       (rst),
        .start     (start_d),
        .green     (Gd),
        .step_tick (step_tick),
        .occupied  (occupied_d),
        .sensor    (sensor_d)
    );

    wire [15:0] total_time_a, max_time_a, car_count_a, total_wait_a, max_wait_a;
    wire [15:0] total_time_b, max_time_b, car_count_b, total_wait_b, max_wait_b;

    calculator u_calculator (
        .clk(clk_12mhz),
        .rst(rst),
        .step_tick(step_tick),

        .car_done_a(car_done_a),
        .entry_rdata_a(entry_rdata_a),
        .advance_head_a(advance_head_a),

        .car_done_b(car_done_b),
        .entry_rdata_b(entry_rdata_b),
        .advance_head_b(advance_head_b),

        .time_counter_out(shared_time_counter),

        .car_count_a(car_count_a), .total_journey_a(total_time_a), .max_journey_a(max_time_a),
        .total_wait_a(total_wait_a), .max_wait_a(max_wait_a),

        .car_count_b(car_count_b), .total_journey_b(total_time_b), .max_journey_b(max_time_b),
        .total_wait_b(total_wait_b), .max_wait_b(max_wait_b)
    );

    //stat_reporter -- only A and B report real stats
    wire uart_line_tx;

    stat_reporter u_stat_reporter (
        .clk(clk_12mhz),
        .rst(rst),
        .read_stats(read_stats),

        .car_count_a(car_count_a),
        .total_journey_a(total_time_a),
        .max_journey_a(max_time_a),
        .total_wait_a(total_wait_a),
        .max_wait_a(max_wait_a),

        .car_count_b(car_count_b),
        .total_journey_b(total_time_b),
        .max_journey_b(max_time_b),
        .total_wait_b(total_wait_b),
        .max_wait_b(max_wait_b),

        .tx(uart_line_tx)
    );

    wire merged_ul = occupied_a[5] | occupied_b[4];   // upper-left  = A5 | B4
    wire merged_ur = occupied_a[4] | occupied_d[5];   // upper-right = A4 | D5
    wire merged_ll = occupied_c[4] | occupied_b[5];   // lower-left  = C4 | B5
    wire merged_lr = occupied_c[5] | occupied_d[4];   // lower-right = C5 | D4

    //hc595_serializer
    // U1..U7, QH..QA order (MSB first), per the confirmed chip table
    wire [55:0] led_data = {
        // U7: QA=1, QB=RP, QC=GP, ...QH=-
        1'b0, 1'b0, 1'b0, 1'b0, 1'b0, Gp, Rp, 1'b0,
        // U6: QA=B0,QB=B1,QC=B2,QD=B3,QE=D9,QF=D8,QG=D7,QH=D6
        occupied_d[6], occupied_d[7], occupied_d[8], occupied_d[9],
        occupied_b[3], occupied_b[2], occupied_b[1], occupied_b[0],
        // U5: QA=GD,QB=YD,QC=RD,QD=A4,QE=A3,QF=A2,QG=A1,QH=A0
        occupied_a[0], occupied_a[1], occupied_a[2], occupied_a[3],
        merged_ur, Rd, Yd, Gd,
        // U4: QA=C9,QB=C8,QC=C7,QD=C6,QE=C5,QF=GC,QG=YC,QH=RC
        Rc, Yc, Gc, merged_lr,
        occupied_c[6], occupied_c[7], occupied_c[8], occupied_c[9],
        // U3: QA=D3,QB=D2,QC=D1,QD=D0,QE=B6,QF=B7,QG=B8,QH=B9
        occupied_b[9], occupied_b[8], occupied_b[7], occupied_b[6],
        occupied_d[0], occupied_d[1], occupied_d[2], occupied_d[3],
        // U2: QA=GB,QB=YB,QC=RB,QD=C4,QE=C3,QF=C2,QG=C1,QH=C0
        occupied_c[0], occupied_c[1], occupied_c[2], occupied_c[3],
        merged_ll, Rb, Yb, Gb,
        // U1: QA=RA,QB=A9,QC=A8,QD=A7,QE=A6,QF=A5,QG=GA,QH=YA
        Ya, Ga, merged_ul, occupied_a[6],
        occupied_a[7], occupied_a[8], occupied_a[9], Ra
    };

    reg [31:0] hc595_cnt;
    reg hc595_trigger;
    always @(posedge clk_12mhz or posedge rst) begin
        if (rst) begin
            hc595_cnt     <= 0;
            hc595_trigger <= 0;
        end 
        else if (hc595_cnt == 6_000_000 - 1) begin
            hc595_cnt     <= 0;
            hc595_trigger <= 1;
        end
        else begin
            hc595_cnt     <= hc595_cnt + 1;
            hc595_trigger <= 0;
        end
    end                

    hc595_serializer u_hc595(
        .clk(clk_12mhz),
        .rst(rst),
        .trigger(hc595_trigger),
        .data(led_data),
        .ds(ds),
        .shcp(shcp),
        .stcp(stcp)
    );

    assign uart_tx_pin = uart_line_tx;

endmodule