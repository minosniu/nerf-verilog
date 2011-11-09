`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Creator: C. Minos Niu
// 
// Module Name:    
// Project Name: 
// Target Devices: XEM6010 - OpalKelly
// Design properties: xc6slx150-2fgg484
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module stretch_reflex_xem6010(
	input  wire [7:0]  hi_in,
	output wire [1:0]  hi_out,
	inout  wire [15:0] hi_inout,
	inout  wire        hi_aa,

	output wire        i2c_sda,
	output wire        i2c_scl,
	output wire        hi_muxsel,
	input  wire        clk1,
	input  wire        clk2,
	
	output wire [7:0]  led,
    output wire pin0,
    output wire pin1,
    output wire pin2
   );
   
    parameter NN = 8;
		
    // *** Dump all the declarations here:
    wire         ti_clk;
    wire [30:0]  ok1;
    wire [16:0]  ok2;   
//    wire [15:0]  ep00wire, ep01wire, ep02wire, ep20wire, ep21wire, ep22wire, ep23wire;
//    wire [15:0]  ep24wire, ep25wire, ep26wire, ep27wire, ep28wire, ep29wire, ep30wire, ep31wire;
    wire reset_global, reset_sim;
    wire        is_pipe_being_written, is_lce_valid;

    wire [31:0] f_muscle_len;
    wire [15:0] hex_from_py;
 
    // *** Target interface bus:
    assign i2c_sda = 1'bz;
    assign i2c_scl = 1'bz;
    assign hi_muxsel = 1'b0;

    // *** Triggered input from Python
   
    reg [31:0] f_pps_coef_Ia;
    always @(posedge ep50trig[1] or posedge reset_global)
    begin
        if (reset_global)
            f_pps_coef_Ia <= 32'h3F66_6666;
        else
            f_pps_coef_Ia <= {ep02wire, ep01wire};  //firing rate
    end       
    
    reg [31:0] f_pps_coef_II;
    always @(posedge ep50trig[2] or posedge reset_global)
    begin
        if (reset_global)
            f_pps_coef_II <= 32'h3F66_6666;
        else
            f_pps_coef_II <= {ep02wire, ep01wire};  //firing rate
    end           
    
    reg [31:0] gain;
    always @(posedge ep50trig[3] or posedge reset_global)
    begin
        if (reset_global)
            gain <= 32'd0;
        else
            gain <= {ep02wire, ep01wire};  //firing rate
    end        
    
    reg [31:0] f_gamma_dyn;
    always @(posedge ep50trig[4] or posedge reset_global)
    begin
        if (reset_global)
            f_gamma_dyn <= 32'h42A0_0000; // gamma_dyn reset to 80
        else
            f_gamma_dyn <= {ep02wire, ep01wire};  
    end  
    
    reg [31:0] f_gamma_sta;
    always @(posedge ep50trig[5] or posedge reset_global)
    begin
        if (reset_global)
            f_gamma_sta <= 32'h42A0_0000; // gamma_sta reset to 80
        else
            f_gamma_sta <= {ep02wire, ep01wire};  
    end  
    
    reg [31:0] i_gain_MN;
    always @(posedge ep50trig[6] or posedge reset_global)
    begin
        if (reset_global)
            i_gain_MN <= 32'd1; // gamma_sta reset to 80
        else
            i_gain_MN <= {ep02wire, ep01wire};  
    end      
    
    reg [31:0] delay_cnt_max;
    always @(posedge ep50trig[7] or posedge reset_global)
    begin
        if (reset_global)
            delay_cnt_max <= delay_cnt_max;
        else
            delay_cnt_max <= {ep02wire, ep01wire};  //firing rate
    end        
    
    reg [31:0] BDAMP_1, BDAMP_2, BDAMP_chain, GI, GII;
    always @(posedge ep50trig[15] or posedge reset_global)
    begin
        if (reset_global)
            BDAMP_1 <= 32'h3E71_4120; // bag 1 BDAMP reset to 0.2356
        else
            BDAMP_1 <= {ep02wire, ep01wire};  //firing rate
    end
    always @(posedge ep50trig[14] or posedge reset_global)
    begin
        if (reset_global)
            BDAMP_2 <= 32'h3D14_4674; // bag 2 BDAMP reset to 0.0362
        else
            BDAMP_2 <= {ep02wire, ep01wire};  //firing rate
    end    
    always @(posedge ep50trig[13] or posedge reset_global)
    begin
        if (reset_global)
            BDAMP_chain <= 32'h3C58_44D0; // chain BDAMP reset to 0.0132 
        else
            BDAMP_chain <= {ep02wire, ep01wire};  //firing rate
    end
    
    // *** Deriving clocks from on-board clk1:
    wire neuron_clk, sim_clk, spindle_clk;
    wire [NN+2:0] neuronCounter;

    gen_clk #(.NN(NN)) useful_clocks
    (   .rawclk(clk1), 
        .half_cnt(delay_cnt_max), 
        .clk_out1(neuron_clk), 
        .clk_out2(sim_clk), 
        .clk_out3(spindle_clk),
        .int_neuron_cnt_out(neuronCounter) );
                
    
    // *** Generating waveform to stimulate the spindle
	waveform_from_pipe gen(	
        .ti_clk(ti_clk),
        .reset(reset_global),
        .repop(reset_sim),
        .feed_data_valid(is_pipe_being_written),
        .feed_data(hex_from_py),
        .current_element(f_muscle_len),
        .test_clk(sim_clk),
        .done_feeding(is_lce_valid)
    );        

    // *** Spindle: f_muscle_len => f_rawfr_Ia
    wire [31:0] f_rawfr_Ia, x_0, x_1, f_rawfr_II;

    spindle bag1_bag2_chain
    (	.gamma_dyn(f_gamma_dyn), // 32'h42A0_0000
        .gamma_sta(f_gamma_sta),
        .lce(f_muscle_len),
        .clk(spindle_clk),
        .reset(reset_sim),
        .out0(x_0),
        .out1(x_1),
        .out2(f_rawfr_II),
        .out3(f_rawfr_Ia),
        .BDAMP_1(BDAMP_1),
        .BDAMP_2(BDAMP_2),
        .BDAMP_chain(BDAMP_chain)
		);

    // *** Izhikevich: f_fr_Ia => spikes
        // *** Convert float_fr to int_I1
	
    wire [31:0] f_fr_Ia;
    wire [31:0] i_synI_Ia;
	mult scale_pps_Ia( .x(f_rawfr_Ia), .y(f_pps_coef_Ia), .out(f_fr_Ia));
    floor float_to_int_Ia( .in(f_fr_Ia), .out(i_synI_Ia) );
    
    wire Ia_spike, s_Ia;
    wire signed [17:0] v_Ia;   // cell potentials
    Iz_neuron #(.NN(NN),.DELAY(10)) Ia_neuron
    (v_Ia,s_Ia, a,b,c,d, i_synI_Ia, neuron_clk, reset_sim, neuronIndex, neuronWriteEnable, readClock, 4'h2, Ia_spike);

    wire [31:0] f_fr_II;
    wire [31:0] i_synI_II;
    mult scale_pps_II( .x(f_rawfr_II), .y(f_pps_coef_II), .out(f_fr_II));
    floor float_to_int_II( .in(f_fr_II), .out(i_synI_II) );
    wire II_spike, s_II;
    wire signed [17:0] v_II;   // cell potentials
    Iz_neuron #(.NN(NN),.DELAY(10)) II_neuron
    (v_II,s_II, a,b,c,d, i_synI_II, neuron_clk, reset_sim, neuronIndex, neuronWriteEnable, readClock, 4'h2, II_spike);

    //*** Synapse:: spike -> I   
	wire [17:0]  I_out;
	wire [17:0]	w1, w2, w3;
	wire spk1, spk2, spk3;
    wire [31:0] i_postsyn_I;
    
//	synapse_int syn1(
//			.I_out(I_out),
//			.spk1(1'b0),
//			.w1(18'd1),
//			.spk2(Ia_spike),
//			.w2(18'd1),
//			.spk3(1'b0),
//			.w3(18'd1),
//			.clk(sim_clk),
//			.reset(reset_sim)
//	);
	wire signed [17:0] Ia_w1, Ia_w2;  //learned synaptic weights

	synapse   #(.NN(NN)) synIa(I_out, 	Ia_spike, 18'sh01000, 	1'b0, 	18'h0, 			1'b0, 	18'h0, 1'b0, 
								neuron_clk, reset_sim, neuronIndex, neuronWriteEnable, readClock, 0, 0, Ia_w1, Ia_w2, 
								0, 0);    
    
	assign i_postsyn_I = {14'h0, I_out};
    
    // *** izh-Motoneuron :: i_postsyn_I -> (MN_spike, rawspike)
    
	wire [3:0] a, b, tau;
	wire [17:0] c, d, v1, u1, s1;
	assign a = 3 ;  // bits for shifting, a = 0.125
	assign b =  2 ;  // bits for shifting, b = 0.25
	assign c =  18'sh3_599A ; // -0.65  = dec2hex(1+bitcmp(ceil(0.65 * hex2dec('ffff')),18)) = 3599A
	assign d =  18'sh0_147A ; // 0.08 = dec2hex(floor(0.08 * hex2dec('ffff'))) = 147A
	assign tau = 4'h2;
    
	wire [1:0] state;
	assign state = neuronCounter[1:0];
    
	wire [NN:0] neuronIndex;
	assign neuronIndex = neuronCounter[NN+2:2];
	
	wire state1, state2, state3, state4;
	assign state1 = (state == 2'h0);
	assign state2 = (state == 2'h1);
	assign state3 = (state == 2'h2);
	assign state4 = (state == 2'h3);
	
	wire neuronWriteCount, readClock, neuronWriteEnable, dataValid;
	assign neuronWriteCount = state1;	//increment neuronID (ram address)
	assign readClock = state2;				//read RAM
	assign neuronWriteEnable = state4; //(state3 | state4);	//write RAM
	assign dataValid = (neuronCounter == 32'd0);  //(neuronIndex ==0) & state2; //(neuronIndex == 1);   //slight delay of positive edge to allow latch set-up times
		
    wire MN_spike;

	Iz_neuron #(.NN(NN),.DELAY(10)) neuMN(v1,s1, a,b,c,d, i_postsyn_I[17:0] * i_gain_MN[17:0], neuron_clk, reset_sim, neuronIndex, neuronWriteEnable, readClock, tau, MN_spike);
//	always @(negedge ti_clk) raw_MN_spikes <= {1'b0, neuronIndex[NN:2], MN_spike, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
//	always @(negedge ti_clk) raw_Ia_spikes <= {1'b0, neuronIndex[NN:2], 1'b0, Ia_spike, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    
    wire [15:0] raw_Ia_spikes, raw_II_spikes, raw_MN_spikes;

    assign raw_MN_spikes = {1'b0, neuronIndex[NN:2], MN_spike, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
	assign raw_Ia_spikes = {1'b0, neuronIndex[NN:2], 1'b0, Ia_spike, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
	assign raw_II_spikes = {1'b0, neuronIndex[NN:2], 1'b0, 1'b0, II_spike, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    
    // *** Count the spikes: rawspikes -> spike -> spike_count_out
	wire    [31:0] i_MN_spk_cnt;
    wire    clear_out;
//    spikecnt count_rawspikes
//	 (		.spike(MN_spike), 
//			.slow_clk(sim_clk), 
//			.fast_clk(neuron_clk),
//            .int_cnt_out(i_MN_spk_cnt),
//			.reset(reset_sim),
//            .clear_out(clear_out) );   

    spike_counter count_rawspikes
    (   .spike(MN_spike), 
        .slow_clk(sim_clk), 
        .reset(reset_sim),
        .int_cnt_out(i_MN_spk_cnt),
        .clear_out(clear_out) );
            
    // *** Shadmehr muscle: spike_count_out => f_active_state => f_total_force
    wire    [31:0]  f_total_force, f_active_state, f_MN_spk_cnt;
    shadmehr_muscle muscle_for_test
    (   .spike_cnt(i_MN_spk_cnt*gain),
        .pos(f_muscle_len),  // muscle length
        //.vel(current_vel),
        .vel(32'd0),
        .clk(sim_clk),
        .reset(reset_sim),
        .total_force_out(f_total_force),
        .current_A(f_active_state),
        .current_fp_spikes(f_MN_spk_cnt)
    );                    
        
    // ** LEDs 0 = ON    
    assign led[4:2] = 3'b111;
    assign led[0] = ~Ia_spike;
    assign led[1] = 1'b1;
    assign led[5] = ~MN_spike;
    assign led[6] = ~sim_clk;
    assign led[7] = ~reset_global;
    
      
    // *** Buttons, physical on XEM3010, software on XEM3050 & XEM6010
    assign reset_global = ep00wire[0];
    assign reset_sim = ep00wire[1];
    
    // *** Endpoint connections:
    assign pin0 = neuron_clk;
    assign pin1 = sim_clk;
    assign pin2 = spindle_clk;

    // *** OpalKelly XEM interface
    okHost okHI(
        .hi_in(hi_in), .hi_out(hi_out), .hi_inout(hi_inout), .hi_aa(hi_aa), .ti_clk(ti_clk),
        .ok1(ok1), .ok2(ok2));

    wire [17*16-1:0]  ok2x;
    okWireOR # (.N(17)) wireOR (ok2, ok2x);
    wire [15:0]  ep00wire, ep01wire, ep02wire;
    okWireIn     wi00 (.ok1(ok1),                           .ep_addr(8'h00), .ep_dataout(ep00wire));
    okWireIn     wi01 (.ok1(ok1),                           .ep_addr(8'h01), .ep_dataout(ep01wire));
    okWireIn     wi02 (.ok1(ok1),                           .ep_addr(8'h02), .ep_dataout(ep02wire));
    
    okWireOut    wo20 (.ep_datain(f_muscle_len[15:0]), .ok1(ok1), .ok2(ok2x[  0*17 +: 17 ]), .ep_addr(8'h20) );
    okWireOut    wo21 (.ep_datain(f_muscle_len[31:16]), .ok1(ok1), .ok2(ok2x[  1*17 +: 17 ]), .ep_addr(8'h21) );
    okWireOut    wo22 (.ep_datain(f_rawfr_Ia[15:0]), .ok1(ok1), .ok2(ok2x[  2*17 +: 17 ]), .ep_addr(8'h22) );
    okWireOut    wo23 (.ep_datain(f_rawfr_Ia[31:16]), .ok1(ok1), .ok2(ok2x[  3*17 +: 17 ]), .ep_addr(8'h23) );
    okWireOut    wo24 (.ep_datain(f_rawfr_II[15:0]), .ok1(ok1), .ok2(ok2x[  4*17 +: 17 ]), .ep_addr(8'h24) );
    okWireOut    wo25 (.ep_datain(f_rawfr_II[31:16]), .ok1(ok1), .ok2(ok2x[  5*17 +: 17 ]), .ep_addr(8'h25) );
    okWireOut    wo26 (.ep_datain(raw_Ia_spikes[15:0]), .ok1(ok1), .ok2(ok2x[  6*17 +: 17 ]), .ep_addr(8'h26) );
    okWireOut    wo27 (.ep_datain(raw_Ia_spikes[31:16]), .ok1(ok1), .ok2(ok2x[  7*17 +: 17 ]), .ep_addr(8'h27) );
    okWireOut    wo28 (.ep_datain(raw_II_spikes[15:0]), .ok1(ok1), .ok2(ok2x[  8*17 +: 17 ]), .ep_addr(8'h28) );
    okWireOut    wo29 (.ep_datain(raw_II_spikes[31:16]), .ok1(ok1), .ok2(ok2x[  9*17 +: 17 ]), .ep_addr(8'h29) );
    okWireOut    wo30 (.ep_datain(raw_MN_spikes[15:0]), .ok1(ok1), .ok2(ok2x[ 10*17 +: 17 ]), .ep_addr(8'h30) );
    okWireOut    wo31 (.ep_datain(raw_MN_spikes[31:16]), .ok1(ok1), .ok2(ok2x[ 11*17 +: 17 ]), .ep_addr(8'h31) );
    okWireOut    wo32 (.ep_datain(f_total_force[15:0]), .ok1(ok1), .ok2(ok2x[ 12*17 +: 17 ]), .ep_addr(8'h32) );
    okWireOut    wo33 (.ep_datain(f_total_force[31:16]), .ok1(ok1), .ok2(ok2x[ 13*17 +: 17 ]), .ep_addr(8'h33) );

     //ep_ready = 1 (always ready to receive)
     wire pipe_out_read1, pipe_out_read2;

    okBTPipeIn   ep80 (.ok1(ok1), .ok2(ok2x[ 14*17 +: 17 ]), .ep_addr(8'h80), .ep_write(is_pipe_being_written), .ep_blockstrobe(), .ep_dataout(hex_from_py), .ep_ready(1'b1));
    okBTPipeOut  epA0 (.ok1(ok1), .ok2(ok2x[ 15*17 +: 17 ]), .ep_addr(8'ha0), .ep_read(pipe_out_read1),  .ep_blockstrobe(), .ep_datain(raw_Ia_spikes), .ep_ready(1'b1));
    okBTPipeOut  epA1 (.ok1(ok1), .ok2(ok2x[ 16*17 +: 17 ]), .ep_addr(8'ha1), .ep_read(pipe_out_read2),  .ep_blockstrobe(), .ep_datain(raw_MN_spikes), .ep_ready(1'b1));

    wire [15:0] ep50trig;
    okTriggerIn ep50 (.ok1(ok1),  .ep_addr(8'h50), .ep_clk(clk1), .ep_trigger(ep50trig));
endmodule
