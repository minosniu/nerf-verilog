`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:57:07 05/30/2012 
// Design Name: 
// Module Name:    synapse 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

// max frequency 88.746 MHz
module synapse_stdp_eric(
                input wire clk,
                input wire reset,
                input wire spike_in,
                input wire postsynaptic_spike_in,
                
                
                output reg signed [31:0] I_out,  // updates once per population (scaling factor 1024) 
                output reg signed [31:0] each_I, // updates on each synapse
                
                output reg [31:0] synaptic_strength, //synaptic weight
                
                input wire [31:0] base_strength, // baseline synaptic strength
                
                input wire [31:0] ltp,              // long term potentiation delta (stdp)
                input wire [31:0] ltd,              // long term depression delta   (stdp)
                input wire [31:0] p_delta           // probability of synaptic decay event
    );

// COMPUTE EACH SYNAPTIC CURRENT /////////////////////////////////////////////////////////////////
//wire [31:0] ltp;
//assign ltp = 32'd10;
//wire [31:0] ltd;
//assign ltd = 32'd5;
//wire [31:0] p_delta;
//assign p_delta= 32'd0;

wire [31:0] impulse;

reg spike;
reg postsynaptic_spike;
//assign impulse = spike ? 31'd1024 : 0; // 1(unit?) current per spike
//assign impulse = spike ? 31'd10240 : 0; // 10(unit?) c urrent per spike
assign impulse = spike ? impulse_mem_in : 0;  // synaptic strength

wire [31:0] i_mem; // I_out
wire [31:0] i_mem_in;

//i_mem updates every neuron_clk
assign i_mem_in = first_pass ? 0 : (i_mem >>> 1) + (i_mem >>> 2) + (i_mem >>> 3) + (i_mem >>> 4) +  (i_mem >>> 5) + impulse; //I = 0.97*I + impulse  (current decay+impulse) 

wire [31:0] spike_history_mem;
wire [31:0] spike_history_mem_in;

assign spike_history_mem_in = first_pass ? 0 : {spike_history_mem[30:0], spike};

wire [31:0] delta_w_ltp;

assign delta_w_ltp = postsynaptic_spike ? ((spike_history_mem == 32'd0) ? 0 : ltp) : 0 ; // make a LookupTabe STDP curve & check last spike only. 

wire [31:0] ps_spike_history_mem;
wire [31:0] ps_spike_history_mem_in;

assign ps_spike_history_mem_in = first_pass ? 0 : {ps_spike_history_mem[30:0], postsynaptic_spike};

wire [31:0] delta_w_ltd;

assign delta_w_ltd = spike ? ((ps_spike_history_mem == 32'd0) ? 0 : ltd) : 0 ; // make a LookupTabe STDP curve
                        
wire [31:0] random_out;
wire [31:0] impulse_decay;

assign impulse_decay = (random_out <= p_delta) ? impulse_mem >>> 7 : 0; // I don't get this. -Eric
    
    rng decay_rng(
            .clk1(clk),
            .clk2(clk),
            .reset(reset),
            .out(random_out),
            
            .lfsr(),
            .casr()
    );
    
wire [31:0] impulse_mem;
wire [31:0] impulse_mem_in;

wire [31:0] impulse_stdp;
//wire [31:0] impulse_bcm;
//reg [31:0] impulse_bcm;

//assign impulse_mem_in = first_pass ? 32'd10240 : impulse_mem+delta_w+delta_w_ltd-impulse_decay;
//assign impulse_stdp = first_pass ? 32'd10240 : impulse_mem+delta_w+delta_w_ltd-impulse_decay;
//assign impulse_stdp = first_pass ? base_strength : impulse_mem+delta_w-delta_w_ltd-impulse_decay;  
assign impulse_stdp = first_pass ? base_strength : impulse_mem - (impulse_mem >>> 11) + delta_w_ltp - delta_w_ltd; //-synaptic strength_decay; // small decay. modified by eric

//assign impulse_mem_in = impulse_bcm;
//assign impulse_mem_in = impulse_mem;

assign impulse_mem_in = impulse_stdp;
// STATE MACHINE //////////////////////////////////////////////////////////////////////////////////////
    
    reg state;
    reg read;
    reg write;
    reg first_pass;
    reg [6:0] neuron_index;

    
    
    always @ (posedge clk or posedge reset)
    begin
        if (reset) begin
            state <= 1;
            write <= 0;
            spike <= 0;
            postsynaptic_spike <= 0;
            neuron_index<=0;
        end else begin
            case(state)
                0:  begin
                    neuron_index <= neuron_index + 1;
                    write <= 0;
                    state <= 1;
                    spike <= spike;
                    postsynaptic_spike <= postsynaptic_spike;
                    end
                1:  begin
                    neuron_index <= neuron_index;
                    write <= 1;
                    state <= 0;
                    spike <= spike_in;
                    postsynaptic_spike <= postsynaptic_spike_in;
                    end
             endcase
        end
    end
    
    // PERFORM READ/COMPUTE/WRITE CYCLE ON RAM CONTENTS


wire reset_bar;
assign reset_bar = ~reset;
always @ (negedge clk or negedge reset_bar) begin
    if (~reset_bar) begin
       first_pass <= 1;
       I_out <= 0;
       each_I <= 0;
       synaptic_strength <= 0;
    end else begin
        if (state) begin
            each_I <= i_mem_in;
            if (neuron_index == 7'h7f) begin  //every 128 neuron_clk
                first_pass <= 0;
                I_out <= i_mem_in;
                synaptic_strength <= impulse_mem_in;
            end
        end
    end
end

    
    neuron_ram i_ram (
  .clka(~clk), // input clka
  .wea(write), // input [0 : 0] wea
  .addra(neuron_index), // input [6 : 0] addra
  .dina(i_mem_in), // input [31 : 0] dina
  .douta(i_mem), // output [31 : 0] douta
  .clkb(clk), // input clkb
  .web(1'b0), // input [0 : 0] web
  .addrb(7'd0), // input [6 : 0] addrb
  .dinb(32'd0), // input [31 : 0] dinb
  .doutb() // output [31 : 0] doutb
    );

    neuron_ram spike_history_ram (
  .clka(~clk), // input clka
  .wea(write), // input [0 : 0] wea
  .addra(neuron_index), // input [6 : 0] addra
  .dina(spike_history_mem_in), // input [31 : 0] dina
  .douta(spike_history_mem), // output [31 : 0] douta
  .clkb(clk), // input clkb
  .web(1'b0), // input [0 : 0] web
  .addrb(7'd0), // input [6 : 0] addrb
  .dinb(32'd0), // input [31 : 0] dinb
  .doutb() // output [31 : 0] doutb
    );
    
     neuron_ram ps_spike_history_ram (
  .clka(~clk), // input clka
  .wea(write), // input [0 : 0] wea
  .addra(neuron_index), // input [6 : 0] addra
  .dina(ps_spike_history_mem_in), // input [31 : 0] dina
  .douta(ps_spike_history_mem), // output [31 : 0] douta
  .clkb(clk), // input clkb
  .web(1'b0), // input [0 : 0] web
  .addrb(7'd0), // input [6 : 0] addrb
  .dinb(32'd0), // input [31 : 0] dinb
  .doutb() // output [31 : 0] doutb
    );

    neuron_ram impulse_ram (
  .clka(~clk), // input clka
  .wea(write), // input [0 : 0] wea
  .addra(neuron_index), // input [6 : 0] addra
  .dina(impulse_mem_in), // input [31 : 0] dina
  .douta(impulse_mem), // output [31 : 0] douta
  .clkb(clk), // input clkb
  .web(1'b0), // input [0 : 0] web
  .addrb(7'd0), // input [6 : 0] addrb
  .dinb(32'd0), // input [31 : 0] dinb
  .doutb() // output [31 : 0] doutb
    );
endmodule


