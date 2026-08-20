module frame_clk_div #(
    parameter integer DIV_COUNT = 6_000_000   // 12MHz / (2*6_000_000) ≈ 1Hz = 1s  half cycle
)
(
    input  wire clk_12mhz,     // CLK 12MHz
    input  wire rst,
    output reg  frame_clk      
);
    integer counter;

    always @(posedge clk_12mhz or posedge rst) begin
        if (rst) begin
            counter   <= 0;
            frame_clk <= 0;
        end 
        else if (counter == DIV_COUNT - 1) begin
            counter   <= 0;
            frame_clk <= ~frame_clk;   
        end 
        else begin
            counter <= counter + 1;
        end
    end
endmodule