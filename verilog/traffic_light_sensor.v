module traffic_light_extend (
    input clk,
    input rst,
    input Sa,           // kept for port compatibility, not used (main road A has no minimum to protect)
    input Sb,           // B street sensor -- this is what actually drives the FSM
    input Pb,
    output reg Ga,
    output reg Ya,
    output reg Ra,
    output reg Gb,
    output reg Yb,
    output reg Rb,
    output reg Gp,
    output reg Rp
);

    parameter tb_CLK = 24_000_000 - 1;

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

    reg [4:0] state, next_state;

    localparam
    S_A         = 5'd0,   // A green, no minimum -- waits indefinitely, watching Sb every tick
    S_A_CONFIRM = 5'd1,   // 1-tick debounce after Sb first seen, before actually switching
    S_Y1        = 5'd2,   // yellow, A->B transition
    S_B0        = 5'd3,   // B green, fixed 5-tick (10s) duration, no extension
    S_B1        = 5'd4,
    S_B2        = 5'd5,
    S_B3        = 5'd6,
    S_B4        = 5'd7,
    S_Y2        = 5'd8,   // yellow, B->A transition
    // pedestrian path branched off S_A
    S14         = 5'd9,
    S15         = 5'd10,
    S16         = 5'd11,
    S17         = 5'd12,
    // pedestrian path branched off S_B4
    S18         = 5'd13,
    S19         = 5'd14,
    S20         = 5'd15,
    S21         = 5'd16;

    reg pb_pending;
    always @(posedge clk or posedge rst) begin
        if (rst)
            pb_pending <= 1'b0;
        else if (Pb)
            pb_pending <= 1'b1;
        else if (tick_10s && (state == S_A || state == S_B4))
            pb_pending <= 1'b0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_A;
        else if (tick_10s)
            state <= next_state;
    end

    always @(*) begin
        Ga = 1'b0; Ya = 1'b0; Ra = 1'b0;
        Gb = 1'b0; Yb = 1'b0; Rb = 1'b0;
        Gp = 1'b0; Rp = 1'b1;
        next_state = state;

        case (state)
            S_A: begin
                Ga = 1'b1;
                Rb = 1'b1;
                if (pb_pending)
                    next_state = S14;
                else if (Sb)
                    next_state = S_A_CONFIRM;   // Sb just seen -- start the short debounce
                else
                    next_state = S_A;            // still no request, keep waiting indefinitely
            end

            S_A_CONFIRM: begin
                Ga = 1'b1;
                Rb = 1'b1;
                next_state = S_Y1;   // debounce elapsed, switch regardless -- no re-check of Sb
            end

            S_Y1: begin
                Ya = 1'b1;
                Yb = 1'b1;
                next_state = S_B0;
            end

            S_B0, S_B1, S_B2, S_B3: begin
                Ra = 1'b1;
                Gb = 1'b1;
                next_state = state + 1'b1;
            end
            S_B4: begin
                Ra = 1'b1;
                Gb = 1'b1;
                if (pb_pending)
                    next_state = S18;
                else
                    next_state = S_Y2;   // fixed duration used up, always switch back -- no extension
            end

            S_Y2: begin
                Ya = 1'b1;
                Yb = 1'b1;
                next_state = S_A;
            end

            // ---- pedestrian path, branched from S_A ----
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
                next_state = S_B0;
            end

            // ---- pedestrian path, branched from S_B4 ----
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
                next_state = S_A;
            end

            default: next_state = S_A;
        endcase
    end

endmodule