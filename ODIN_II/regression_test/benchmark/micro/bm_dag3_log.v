// DEFINES
`define BITS 2         // Bit width of the operands

module 	bm_dag3_log(clock, 
		a_in, 
		b_in, 
		out);

// SIGNAL DECLARATIONS
input	clock;

input [`BITS-1:0] a_in;
input [`BITS-1:0] b_in;

output [`BITS-1:0] out;

wire [`BITS-1:0]    out;
wire [`BITS-1:0]    a;
wire [`BITS-1:0]    b;
wire [`BITS-1:0]    c;
wire [`BITS-1:0]    d;

// ASSIGN STATEMENTS
assign out = a | b | c | d;
assign a = b_in & c;
assign b = a_in ^ c;
assign c = ~a_in;
assign d = b | b_in;

endmodule
