`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:01:54 03/11/2014 
// Design Name: 
// Module Name:    bram_dm 
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
module Disp_Map_Calc
#(
/* CONFIGURABLE PARAMETERS */
parameter NUM_OF_ROWS_IN_BRAM = 8,
parameter NUM_OF_WIN = 64,
parameter VRES = 480,
parameter HRES = 640,
parameter BRAM_DATA_WIDTH = 16,
parameter BRAM_ADDR_WIDTH = 13,
parameter BRAM_WE_WIDTH = 1,

// 640*480 frame with 3x3 window - 1.6sec/frame
// 640*480 frame with 7x7 window - 8.5sec/frame
parameter window = 7
/***************************/
)
(
input reset,
input clk,
output reg en_search,
output reg [BRAM_WE_WIDTH - 1 : 0] we_search,
output [BRAM_ADDR_WIDTH - 1 : 0] addr_search,
input [BRAM_DATA_WIDTH - 1 : 0] dout_search,

// Reference Frame
output reg en_ref,
output reg [BRAM_WE_WIDTH - 1 : 0] we_ref,
output reg [BRAM_ADDR_WIDTH - 1: 0] addr_ref,
input [BRAM_DATA_WIDTH - 1 : 0] dout_ref,

input go,
input busy_ref,
input busy_search,

output reg finished_row,

output [31 : 0] din_fifo,
output reg wr_en_fifo
    );

parameter IDLE  = 3'b000, START = 3'b001, COMP = 3'b010, DONE = 3'b011, NEXT = 3'b100, BUSY = 3'b101;


/* DERIVED PARAMETERS */
parameter TOTAL_NUM_PIXELS = (VRES - 6) * (HRES - 6); // (640 - 6) * (480 - 6)
parameter TOTAL_NUM_ROWS = VRES - 6;
parameter TOTAL_NUM_COLS = HRES - 6;
/***************************/

parameter window_half = window/2;

//reg [8:0] ref_window [0:49];
//integer i;
//initial begin
//	
// 	for (i = 0; i < 49; i = i +1) begin
//  	  	//$display ("Current value of i is %d", i);
//		ref_window [i] = i;
//  	end
//end

reg [2:0] curr_state;
reg [2:0] next_state;
reg [2:0] saved_state;

//wire [31 : 0] addrb;

//wire [31 : 0] dout_search;
//wire [2:0] window;
//assign window = 3'b011;
reg [BRAM_ADDR_WIDTH - 1 : 0] start_addr;

reg [11 : 0] comp_p_row;
reg [11 : 0] comp_p_col;

reg [5 : 0] counter; // number of pixels in a window processed

reg [5 : 0] address_counter; // number of pixels an address has been generated for
reg [6 : 0] address_win_count; // number of total window addresses calculated

reg [5 : 0] win_row_index; // number of each row index in a window
reg [5 : 0] win_col_index; // number of each column index in a window
reg [6 : 0] win_count; // number of total windows calculated
//reg [11 : 0] total_num_of_pix;

reg [11 : 0] window_sum;

reg [11 : 0] lowest_disp;
reg [5 : 0] lowest_disp_index;

reg [31 : 0] grayscale_pixels;
reg grayscale_fifo_wr_sel;

//wire [2:0] window_half;
wire [5 : 0] pixels_in_window;

//assign window_half = window >> 1; 
assign pixels_in_window = window * window;

//reg finished_row;

wire busy;

assign busy = busy_ref | busy_search;

//reg [3 : 0] we_search;

//reg en_search;
//wire rst_fifo, wr_clk_fifo, rd_clk_fifo, rd_en_fifo, full_fifo, empty_fifo;
//output reg wr_en_fifo;
//wire [31 : 0] din_fifo;
//wire [31 : 0] dout_fifo;
//wire [5 : 0] rd_data_count_fifo;

//assign done = finished_row;


always @(*)
begin : FSM
	case (curr_state)
	
		IDLE:
			if (go == 1'b1) begin
				if(~busy)
					next_state = START;
				else
					next_state = BUSY;
				saved_state = curr_state;
			end
			else begin
				next_state = IDLE;
			end
		
		NEXT: begin
			if(~busy)
				next_state = START;
			else
				next_state = BUSY;
				
			saved_state = curr_state;
		end
		
		START:
			if (~busy) begin
				next_state = COMP;
			end
			else begin
				next_state = BUSY;
				saved_state = COMP;
			end
			
		COMP:
			if(~busy) begin
				if (win_count == (NUM_OF_WIN))
					next_state = DONE;
				else
					next_state = COMP;
			end
			else begin
				next_state = BUSY;
				if (win_count == (NUM_OF_WIN))
					saved_state = DONE;
				else
					saved_state  = COMP;
			end
			
		DONE:
			if (~busy) begin
				if((comp_p_col == (HRES - 1 - window_half)) & (comp_p_row == (VRES - 1 - window_half))) begin
					next_state = IDLE;
				end
				else begin
					next_state = NEXT;
				end
			end
			else begin
				next_state = BUSY;
				saved_state = NEXT;
			end
		
		BUSY:
			if (busy)
				next_state = BUSY;
			else
				next_state = saved_state;
		
		default: begin
			next_state 	= IDLE;
			saved_state = IDLE;
		end
	endcase
end

always @(posedge clk)
begin
	if (reset) begin
		start_addr 					<= 0;
		curr_state 					<= IDLE;
		counter 						<= 0;
		comp_p_row 					<= window_half;
		comp_p_col 					<= window_half + (NUM_OF_WIN-1); // Start 64 pixels over as we search 64 pixels to the left
		win_row_index 				<= 0;
		win_col_index 				<= 0; 
		win_count 					<= 0; 
//		total_num_of_pix 			<= 0;
		window_sum 					<= 0;
		lowest_disp 				<= 12'hFFF; // highest value
		lowest_disp_index			<= 63;		// highest value
		we_search 					<= 0;
		en_search 					<= 0;
		grayscale_fifo_wr_sel	<= (window_half + (NUM_OF_WIN-1)) % 2;
		address_counter			<= 1;
		address_win_count			<= 0;
		grayscale_pixels			<= 0;
		
		en_ref						<= 0;
		we_ref						<= 0;
		addr_ref						<= 0;
	end
	else begin
		curr_state <= #2 next_state;
		
		/* default values */
		finished_row 				<= 0;
		en_search 					<= #2 0;
		start_addr 					<= start_addr;
		counter 					<= counter;
		comp_p_row 					<= comp_p_row;
		comp_p_col 					<= comp_p_col;
		win_row_index 				<= win_row_index;
		win_col_index 				<= win_col_index; 
		win_count 					<= win_count; 
//		total_num_of_pix 			<= total_num_of_pix;
		window_sum 					<= window_sum;
		lowest_disp 				<= lowest_disp;
		lowest_disp_index			<= lowest_disp_index;
		grayscale_fifo_wr_sel	<= grayscale_fifo_wr_sel;
		wr_en_fifo					<= 0;
		address_win_count			<= address_win_count;
		address_counter			<= address_counter;
		grayscale_pixels			<= grayscale_pixels;
		
		en_ref						<= #2 0;
		we_ref						<= #2 0;
		addr_ref						<= addr_ref;
	
		case (curr_state)
			IDLE: begin 
				start_addr <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - address_win_count - (window_half - win_col_index));
				addr_ref <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - (window_half - win_col_index));
				if (go) begin
					en_search <= #2 1;
					en_ref <= #2 1;
					win_col_index <= #2 win_col_index + 1'b1;
					address_counter <= #2 address_counter + 1'b1;
				end
			end
			NEXT: begin
				start_addr <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - address_win_count - (window_half - win_col_index));
				addr_ref <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - (window_half - win_col_index));
				en_search <= #2 1;
				en_ref <= #2 1;
				win_col_index <= #2 win_col_index + 1'b1;
				address_counter <= #2 address_counter + 1'b1;
			end
			START: begin
				start_addr <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - address_win_count - (window_half - win_col_index));
				addr_ref <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - (window_half - win_col_index));
				address_counter <= #2 address_counter + 1'b1;
				en_search <= #2 1;
				en_ref <= #2 1;
				win_col_index <= #2 win_col_index + 1'b1;
			end
			COMP: begin
			
				if (address_win_count == NUM_OF_WIN) begin
					en_search <= #2 0;
					en_ref <= #2 0;
				end
				else begin
					en_search <= #2 1;
					en_ref <= #2 1;
				end
				
				start_addr <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - address_win_count - (window_half - win_col_index));
				addr_ref <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - (window_half - win_col_index));
				

				// Increment window indexes
				// If the address for all pixels in a window have been calculated
				//		- increment address_win_count (affects address)
				//		- reset pixel position in window
				//		- reset pixel counter for window (for address calculation)
				if (address_counter == pixels_in_window) begin
					win_col_index <= #2 0;
					win_row_index <= #2 0;
					address_win_count <= #2 address_win_count + 1'b1;
					address_counter <= #2 1;
				end
				else begin
					if (win_col_index < (window - 1) )
						win_col_index <= #2 win_col_index + 1'b1;
					else begin
						win_col_index <= #2 0;					
						win_row_index <= #2 win_row_index + 1'b1;
					end
					address_counter <= #2 address_counter + 1'b1;
				end
				
					
				// Accumulate window sum (absolute difference)
				// Hack as there are two pipeline stages
				// Note: the address is 2 clocks ahead of the sum -- CONFIRM THIS
				if (counter == pixels_in_window) begin
					if (dout_search [11 : 0] > dout_ref [11 : 0])
						window_sum <= #2 (dout_search [11 : 0] - dout_ref [11 : 0]);
					else
						window_sum <= #2 (dout_ref [11 : 0] - dout_search [11 : 0]);
				end
				else begin
					if (dout_search [11 : 0] > dout_ref [11 : 0])
						window_sum <= #2 window_sum + (dout_search [11 : 0] - dout_ref [11 : 0]);
					else
						window_sum <= #2 window_sum + (dout_ref [11 : 0] - dout_search [11 : 0]);
				end
				
				// Counter for each pixel in a window
				if (counter == pixels_in_window) 
					counter <= #2 1;
				else
					counter <= #2 counter + 1'b1;
					
				// If window has been calculated, 
				// increase window_count and check if it a lower sum
				if (counter == pixels_in_window) begin
					win_count <= #2 win_count + 1'b1;
					if (lowest_disp > window_sum) begin
						lowest_disp <= #2 window_sum;
						lowest_disp_index <= #2 win_count [5:0] ;
					end
				end
				
			end
			DONE: begin
				
				// Alternate writes to upper and lower half word
				if (~grayscale_fifo_wr_sel) begin
					grayscale_pixels [15:11] <= #2 lowest_disp_index [5:1];
					grayscale_pixels [10:5] <= #2 lowest_disp_index;
					grayscale_pixels [4:0] <= #2 lowest_disp_index [5:1];
				end
				else begin
					grayscale_pixels [31:27] <= #2 lowest_disp_index [5:1];
					grayscale_pixels [26:21] <= #2 lowest_disp_index;
					grayscale_pixels [20:16] <= #2 lowest_disp_index [5:1];
				end
				
				
//				win_col_index <= #2 1;
//				en_search <= #2 1;
//				en_ref <= #2 1;
//				
//				start_addr <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - address_win_count - (window_half - win_col_index));
//				addr_ref <= #2 ((comp_p_row - (window_half - win_row_index)) % NUM_OF_ROWS_IN_BRAM) * HRES + (comp_p_col - (window_half - win_col_index));
//				
				// Increase total_num_pix calculated
				// Reset variables: window_sum, counter,  
				//total_num_of_pix 		<= #2 total_num_of_pix + 1'b1;
				window_sum 				<= #2 0;
				counter 					<= #2 0;
				win_count 				<= #2 0;
				lowest_disp 			<= #2 'hFFF;
				lowest_disp_index 		<= #2 63;
				address_counter			<= 1;
				address_win_count		<= 0;
				win_row_index 			<= 0;
				win_col_index 			<= 0;
				
				if (comp_p_col == (HRES - 1 - window_half)) begin
					comp_p_col <= #2 window_half + (NUM_OF_WIN-1);
					if (comp_p_row == (VRES - 1 - window_half)) begin
						start_addr 					<= 0;
						curr_state 					<= IDLE;
						counter 						<= 0;
						comp_p_row 					<= window_half;
						comp_p_col 					<= window_half + (NUM_OF_WIN-1); // Start 64 pixels over as we search 64 pixels to the left
						win_row_index 				<= 0;
						win_col_index 				<= 0; 
						win_count 					<= 0; 
				//		total_num_of_pix 			<= 0;
						window_sum 					<= 0;
						lowest_disp 				<= 12'hFFF; // highest value
						lowest_disp_index			<= 63;		// highest value
						we_search 					<= 0;
						en_search 					<= 0;
						grayscale_fifo_wr_sel	<= (window_half + (NUM_OF_WIN-1)) % 2;
						address_counter			<= 1;
						address_win_count			<= 0;
						grayscale_pixels			<= 0;
						
						en_ref						<= 0;
						we_ref						<= 0;
						addr_ref					<= 0;							
						comp_p_row <= #2 window_half;
					end
					else begin
						comp_p_row <= #2 comp_p_row + 1'b1;	
					end
					// Enable Write to FIFO
					wr_en_fifo <= #2 1;
					// Indicate Row finished
					finished_row <= #2 1;
					grayscale_fifo_wr_sel	<= #2 (window_half + (NUM_OF_WIN-1)) % 2;
				end
				else begin
					comp_p_col <= #2 comp_p_col + 1'b1;
					// Enable Write to FIFO
					wr_en_fifo <= #2 grayscale_fifo_wr_sel;
					grayscale_fifo_wr_sel <= #2 ~grayscale_fifo_wr_sel;
				end
				
			end
			
			BUSY: begin
			// WAIT
			
			end
			
			default: curr_state <= IDLE;
		endcase
	end
end 

assign addr_search = start_addr;

//assign rst_fifo = reset;

assign din_fifo = grayscale_pixels;

//assign wr_clk_fifo = clk;

//grayscale_pixel_FIFO grascale_fifo (
//  .rst(rst_fifo), // input rst
//  .wr_clk(wr_clk_fifo), // input wr_clk
//  .rd_clk(rd_clk_fifo), // input rd_clk
//  .din(din_fifo), // input [31 : 0] din
//  .wr_en(wr_en_fifo), // input wr_en
//  .rd_en(rd_en_fifo), // input rd_en
//  .dout(dout_fifo), // output [31 : 0] dout
//  .full(full_fifo), // output full
//  .empty(empty_fifo), // output empty
//  .rd_data_count(rd_data_count_fifo) // output [5 : 0] rd_data_count
//);

endmodule
