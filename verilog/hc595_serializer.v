module hc595_serializer (
    input  wire clk,           // 12MHz
    input  wire rst,
    input  wire trigger,       // next turn(frame_clk or FSM)
    input  wire [55:0] data,   // traffic_light(8+6bits) road(10*4 bits)  7 chips
    output reg  ds,            // 74HC595 DS(pin14)
    output reg  shcp,          // 74HC595 SHCP(pin11)
    output reg  stcp           // 74HC595 STCP(pin12)
);
    reg [55:0] shift_buf;
    reg [5:0] bit_cnt;
    reg [2:0] state;

    localparam IDLE = 0, 
               LOAD = 1, 
               SHIFT_LOW = 2, 
               SHIFT_HIGH = 3, 
               LATCH = 4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            shcp  <= 0;
            stcp  <= 0;
            ds    <= 0;
        end 
        else begin
            case (state)
                IDLE: begin
                    stcp <= 0;
                    if (trigger) begin
                        shift_buf <= data;   // input data
                        bit_cnt   <= 0;
                        state     <= LOAD;
                    end
                end

                LOAD: begin
                    ds    <= shift_buf[55]; //final 
                    shcp  <= 0;
                    state <= SHIFT_LOW;
                end

                SHIFT_LOW: begin        //input ds to hc595
                    shcp  <= 1;              
                    state <= SHIFT_HIGH;
                end

                SHIFT_HIGH: begin
                    shcp <= 0;
                    if (bit_cnt == 55) begin
                        state <= LATCH;
                    end else begin
                        shift_buf <= shift_buf << 1;   //next bit
                        ds        <= shift_buf[54];    //change ds next bit    
                        bit_cnt   <= bit_cnt + 1;
                        state     <= SHIFT_LOW;
                    end
                end

                LATCH: begin
                    stcp  <= 1;     
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule