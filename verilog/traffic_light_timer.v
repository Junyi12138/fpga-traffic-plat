module traffic_light_extend (
    input clk,          // 10s /cycle(12MHz)
    input rst,          // reset
    input Sa,           // A street sensor -- kept for port compatibility, NOT used in this model
    input Sb,           // B street sensor -- kept for port compatibility, NOT used in this model
    input Pb,           // Pedestrian crossing push-button（1 = pressed）
    output reg Ga,      // A street green
    output reg Ya,      // A street yellow
    output reg Ra,      // A street red
    output reg Gb,      // B street green
    output reg Yb,      // B street yellow
    output reg Rb,      // B street red
    output reg Gp,      // Pedestrian signal green (Walk)
    output reg Rp       // Pedestrian signal red (Don't Walk)
);

    parameter tb_CLK = 24_000_000 - 1;

    //10s cycle
    reg [26:0] ten_sec_cnt = 0;
    reg tick_10s = 0;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ten_sec_cnt <= 0;
            tick_10s <= 0;
        end else begin
            if (ten_sec_cnt == tb_CLK) begin 
                ten_sec_cnt <= 0;
                tick_10s <= 1;
            end else begin
                ten_sec_cnt <= ten_sec_cnt + 1;
                tick_10s <= 0;
            end
        end
    end

    // state definition -- S12 (the sensor-triggered extension state) is
    // removed: with no sensor input driving the FSM, there's nothing left
    // to decide whether to extend, so the state is unreachable
    reg [4:0] state, next_state;

    localparam 
    S0  = 5'd0, 
    S1  = 5'd1, 
    S2  = 5'd2, 
    S3  = 5'd3,
    S4  = 5'd4,
    S5  = 5'd5, 
    S6  = 5'd6, 
    S7  = 5'd7,
    S8  = 5'd8, 
    S9  = 5'd9, 
    S10 = 5'd10, 
    S11 = 5'd11,
    S13 = 5'd13,
    S14 = 5'd14,   // Pre-Crossing Yellow, Street A side  (Ya, Rb)
    S15 = 5'd15,   // Pedestrian Crossing, A's cycle, tick 1/2 (Ra, Rb, Gp)
    S16 = 5'd16,   // Pedestrian Crossing, A's cycle, tick 2/2 (Ra, Rb, Gp)
    S17 = 5'd17,   // Post-Crossing Yellow, Street B side (Yb, Ra)
    S18 = 5'd18,   // Pre-Crossing Yellow, Street B side  (Yb, Ra)
    S19 = 5'd19,   // Pedestrian Crossing, B's cycle, tick 1/2 (Ra, Rb, Gp)
    S20 = 5'd20,   // Pedestrian Crossing, B's cycle, tick 2/2 (Ra, Rb, Gp)
    S21 = 5'd21;   // Post-Crossing Yellow, Street A side (Ya, Rb)

    reg pb_pending;
    always @(posedge clk or posedge rst) begin
        if (rst)
            pb_pending <= 1'b0;
        else if (Pb)
            pb_pending <= 1'b1;
        else if (tick_10s && (state == S5 || state == S11))   // S12 dropped: unreachable now
            pb_pending <= 1'b0;                          
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S0;
        else if(tick_10s)
            state <= next_state;
    end

    always @(*) begin
        Ga = 1'b0; Ya = 1'b0; Ra = 1'b0;
        Gb = 1'b0; Yb = 1'b0; Rb = 1'b0;
        Gp = 1'b0; Rp = 1'b1;
        next_state = state;

        case (state)
            // Ga Rb 60s = 6 cycles
            S0, S1, S2, S3, S4: begin
                Ga = 1'b1;
                Rb = 1'b1;
                next_state = state + 1'b1; 
            end
            S5: begin
                Ga = 1'b1;
                Rb = 1'b1;
                if (pb_pending)
                    next_state = S14;
                else
                    next_state = S6;   // fixed timing: always switch after the minimum, Sb ignored
            end

            // Excessive yellow light 10s= 1 cycle
            S6: begin
                Ya = 1'b1;
                Yb = 1'b1;
                next_state = S7;
            end

            // Ra Gb 50s = 5 cycles
            S7, S8, S9, S10: begin
                Ra = 1'b1;
                Gb = 1'b1;
                next_state = state + 1'b1; 
            end
            S11: begin
                Ra = 1'b1;
                Gb = 1'b1;
                if (pb_pending)
                    next_state = S18;
                else
                    next_state = S13;   // fixed timing: always switch after the minimum, Sa/Sb ignored, no extension
            end

            // Excessive yellow light 10s= 1 cycles
            S13: begin
                Ya = 1'b1;
                Yb = 1'b1;
                next_state = S0;
            end

            // ---- pedestrian crossing paths: unchanged from the sensor-based model ----
            S14: begin
                Ya = 1'b1;
                Rb = 1'b1;
                next_state = S15;
            end
            S15, S16: begin
                Ra = 1'b1;
                Rb = 1'b1;
                Gp = 1'b1;
                Rp = 1'b0;
                next_state = state + 1'b1;
            end
            S17: begin
                Yb = 1'b1;
                Ra = 1'b1;
                next_state = S7;
            end

            S18: begin
                Yb = 1'b1;
                Ra = 1'b1;
                next_state = S19;
            end
            S19, S20: begin
                Ra = 1'b1;
                Rb = 1'b1;
                Gp = 1'b1;
                Rp = 1'b0;
                next_state = state + 1'b1;
            end
            S21: begin
                Ya = 1'b1;
                Rb = 1'b1;
                next_state = S0;
            end

            default: next_state = S0;
        endcase
    end

endmodule