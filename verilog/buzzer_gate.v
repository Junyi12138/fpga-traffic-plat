module buzzer_gate (
    input  wire pedestrian_green,   // Gp
    input  wire buzz_clk,           // frame_clk_div output
    output wire buzzer_out          
);
    assign buzzer_out = pedestrian_green & buzz_clk;
endmodule