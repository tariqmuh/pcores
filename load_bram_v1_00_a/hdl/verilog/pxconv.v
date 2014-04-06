module pxconv
#(
parameter VRES = 480,
parameter HRES = 640,
parameter BURST = 128
)
(
    input clk,
    input rst,
	
	input [15:0] axi_to_pxconv_data,
	input axi_to_pxconv_valid,
	
	input pixel_ack,
	
	output reg pxconv_to_axi_ready_to_rd,
	output [11:0] pxconv_to_axi_mst_length,
	
	output [0:0] pxconv_to_bram_we,
	output reg [15:0] pxconv_to_bram_data,
	output reg pxconv_to_bram_wr_en,
	output reg [12:0] pxconv_to_bram_addr,
	
	output busy,
	output reg wnd_in_bram
    );
	 
	 parameter NLINES = 8;
	 parameter FULL_BRAM = NLINES*HRES;
	 parameter FRAME_SIZE = HRES*VRES;
	 parameter PIXELS_PER_BURST = BURST/2;

	wire [7:0] px_low_red, px_low_blue, px_low_green;
	wire [8:0] px_low_add;
	wire [8:0] px_low_grey;
	
	reg [23:0] px_cnt;
	reg [23:0] row_cnt;
	reg [23:0] px_cnt_d;
	reg [23:0] rd_cnt;
	reg fill_win;
	
	reg [15:0] axi_to_pxconv_data_d;
	reg axi_to_pxconv_valid_d;
	
	assign px_low_red = {axi_to_pxconv_data_d[15:11], 3'b0};
	assign px_low_green = {axi_to_pxconv_data_d[10:5], 2'b0};
	assign px_low_blue = {axi_to_pxconv_data_d[4:0], 3'b0};
	
	assign px_low_add = (px_low_red + px_low_green + px_low_blue);
	assign px_low_grey = px_low_add/3;

	assign pxconv_to_bram_we = 1;

	assign busy = pxconv_to_bram_wr_en;
	
	always@(posedge clk) begin
		if(rst) begin
			pxconv_to_bram_data <= 'h0;
			pxconv_to_bram_addr <= FULL_BRAM-1;
			pxconv_to_bram_wr_en <= 1'b0;
			px_cnt <= 24'b0;
			px_cnt_d <= 24'b0;
			fill_win <= 1'b1;
		end
		else begin
			axi_to_pxconv_data_d <= axi_to_pxconv_data;
			axi_to_pxconv_valid_d <= axi_to_pxconv_valid;
			px_cnt_d <= px_cnt;
			
			pxconv_to_bram_data <= {8'b0, px_low_grey};
			
			if(px_cnt >= FULL_BRAM) begin
				fill_win <= 1'b0;
			end
			
			if(axi_to_pxconv_valid) begin
				if(px_cnt == FRAME_SIZE-1) begin  //640*480 in hex
					px_cnt <= 24'h0;
					fill_win <= 1'b1;
				end
				else begin
					px_cnt <= px_cnt + 1'b1;
				end

			end
			if(axi_to_pxconv_valid_d) begin
				pxconv_to_bram_wr_en <= 1'b1;
				if(pxconv_to_bram_addr == FULL_BRAM-1) begin
					pxconv_to_bram_addr <= 'h0;
				end 
				else begin
					pxconv_to_bram_addr <= pxconv_to_bram_addr + 1'b1;
				end
			end
			else begin
				pxconv_to_bram_wr_en <= 1'b0;
			end
		end
	end
	
	assign pxconv_to_axi_mst_length = BURST;
	

	always@(posedge clk) begin
		if(rst) begin
			pxconv_to_axi_ready_to_rd <= 1'b1;
			rd_cnt <= HRES/PIXELS_PER_BURST;
			//row_cnt <= PIXELS_PER_BURST;
			row_cnt <= 'b0;
		end
		else begin
			if(fill_win) begin
//				if(px_cnt < FULL_BRAM - BURST) begin
//					pxconv_to_axi_ready_to_rd <= 1'b1;
//				end
//				else begin
//					pxconv_to_axi_ready_to_rd <= 1'b0;
//				end
				if(axi_to_pxconv_valid) begin
					if(row_cnt == PIXELS_PER_BURST-1) begin
						row_cnt <= 24'b0;
						pxconv_to_axi_ready_to_rd <= 1'b1;
					end
					else begin
						row_cnt <= row_cnt + 1'b1;
						pxconv_to_axi_ready_to_rd <= 1'b0;
					end
				end
				rd_cnt <= HRES/PIXELS_PER_BURST;
			end
			else begin
				if(pixel_ack) begin
					rd_cnt <= 0;
					pxconv_to_axi_ready_to_rd <= 1'b1;
				end
				
				else if(rd_cnt < HRES/PIXELS_PER_BURST) begin
					if(axi_to_pxconv_valid) begin
						if(row_cnt == PIXELS_PER_BURST-1) begin
							row_cnt <= 24'b0;
							rd_cnt <= rd_cnt + 1'b1;
							pxconv_to_axi_ready_to_rd <= 1'b1;
						end
						else begin
							row_cnt <= row_cnt + 1'b1;
							pxconv_to_axi_ready_to_rd <= 1'b0;
						end
					end
				end
				else begin
					pxconv_to_axi_ready_to_rd <= 1'b0;
				end
			end
		end
	end
	
//	always@(posedge clk) begin
//		if(rst) begin
//			pxconv_to_axi_ready_to_rd <= 1'b0;
//			rd_cnt <= HRES/BURST;
//			row_cnt <= BURST;
//		end
//		else begin
//			if(px_cnt < FULL_BRAM - BURST) begin //8c0 -1 = 8bf, need to stop ready_to_rd 1 cycle early.
//				pxconv_to_axi_ready_to_rd <= 1'b1;
//				rd_cnt <= HRES/BURST;
//			end
//			else begin
//
//				if(pixel_ack) begin
//					rd_cnt <= 0;
//					pxconv_to_axi_ready_to_rd <= 1'b1;
//				end
//				else if(rd_cnt < HRES/BURST) begin
//					pxconv_to_axi_ready_to_rd <= 1'b1;
//				end
//				else begin
//					pxconv_to_axi_ready_to_rd <= 1'b0;
//				end
//				
//				if(axi_to_pxconv_valid) begin
//					if(row_cnt == BURST) begin
//						row_cnt <= 24'b0;
//						rd_cnt <= rd_cnt + 1'b1;
//					end
//					else begin
//						row_cnt <= row_cnt + 1'b1;
//					end
//				end
//			end
//		end
//	end
	
	always@(posedge clk) begin
		if(rst) begin
			wnd_in_bram <= 1'b0;
		end
		else begin
			if(px_cnt_d >= FULL_BRAM) wnd_in_bram <= 1'b1;
			else wnd_in_bram <= 1'b0;
		end
	end
	
endmodule