module cic (
    i_clk,
    i_reset,
    i_data,
    i_ready,
    o_data,
    o_ready
    );

    //OW = IW+ceil(M*log_2(R)) https://www.dsprelated.com/showarticle/1337.php
    parameter IW=2, OW=128, R=100, M=10;

    input wire i_clk, i_reset;
    input wire signed [(IW-1):0] i_data;
    input wire i_ready;
    output wire signed [(OW-1):0] o_data;
    output wire o_ready;

    /*
    CIC filter -> downsample high frequency data down to lower frequency 
    3.072 Mhz to 48Khz ... (64/1 ratio) thats every 64th sample being valueable M is the ratio M = 64

    N is number of cascade stages (3?)
    M is decimation factor of current stage
    R is decimation factor of the next stage(1/64? or 64?)

    ++ Integrator
    Seems to be the anti-aliasing section... 
    removes potential 'noise' that could come from the compressing of the data down to a lower sample rate
    */
    //INTEGRATOR
    /* verilator lint_off UNOPTFLAT */
    wire signed [(OW-1):0] integrator_data [0:M];
    wire integrator_ready [0:M]; //ready
    assign integrator_data[0] = {{(OW-IW){i_data[IW-1]}},i_data};
    assign integrator_ready[0] = i_ready; // ready command may cause problems... maybe not, it looks like it all runs at once (as expected of Verilog)

    genvar i;
    generate
        for (i=1; i<=M; i++) begin

            integrator #(
                .IW(OW),
                .OW(OW))
            integrator_inst (
                .i_clk(i_clk),
                .i_data(integrator_data[i-1]),
                .i_ready(integrator_ready[i-1]), //ready
                .o_data(integrator_data[i]),
                .o_ready(integrator_ready[i]) //ready
        ); 
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */

    //This is where the sample size compression will take place.
    //DECIMATOR
    wire decimator_ready; //ready
    wire signed [(OW-1):0] decimator_data;
    decimator #(.W(OW),
                .R(R)) 
    decimator_0 (
        .i_clk(i_clk),
        .i_data(integrator_data[M]),
        .i_ready(integrator_ready[M]), //ready
        .o_data(decimator_data),
        .o_ready(decimator_ready) //ready
    );

    //Not sure what to make of this yet... worth investigation.
    //COMB
    wire signed [(OW-1):0] comb_data [0:M];
    wire comb_ready [0:M]; //ready
    assign comb_data[0] = decimator_data;
    assign comb_ready[0] = decimator_ready; //ready
    genvar j;
    generate
        for (j=1; j<=M; j++) begin
            comb #(
                .IW(OW),
                .OW(OW),
                .N(1*R/R)) 
            comb_0 (
                .i_clk(i_clk),
                .i_data(comb_data[j-1]),
                .i_ready(comb_ready[j-1]), //ready
                .o_data(comb_data[j]),
                .o_ready(comb_ready[j]) //ready
            );
        end
    endgenerate

    assign o_data = comb_data[M];
    assign o_ready = comb_ready[M]; //ready

    `ifdef COCOTB_SIM
    initial begin
    $dumpfile ("cic.vcd");
    $dumpvars (0, cic);
    end
    `endif   
    

endmodule