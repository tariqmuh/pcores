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
	output reg [11:0] pxconv_to_axi_mst_length,
	
	output [0:0] pxconv_to_bram_we,
	output reg [31:0] pxconv_to_bram_data,
	output reg pxconv_to_bram_wr_en,
	output reg [31:0] pxconv_to_bram_addr,
	
	output busy,
	output reg wnd_in_bram
    );
	 
	 parameter NLINES = 8;
	 parameter FULL_BRAM = NLINES*HRES;
	 parameter FRAME_SIZE = HRES*VRES;

	wire [15:0] px_low_red, px_low_blue, px_low_green;
	
	wire [17:0] px_low_grey;
	
	reg [23:0] px_cnt;
	reg [23:0] row_cnt;
	reg [23:0] px_cnt_d;
	
	reg [15:0] axi_to_pxconv_data_d;
	reg axi_to_pxconv_valid_d;
	
	assign px_low_red = (((axi_to_pxconv_data_d & 16'hf800) >> 11) << 3);
	assign px_low_blue = (((axi_to_pxconv_data_d & 16'h07e0) >> 5) << 2);
	assign px_low_green = ((axi_to_pxconv_data_d & 16'h001f) << 3);
	
	assign px_low_grey = (px_low_red + px_low_blue + px_low_green) / 3;

	assign pxconv_to_bram_we = 4'hf;

	assign busy = pxconv_to_bram_wr_en;
	
	always@(posedge clk) begin
		if(rst) begin
			pxconv_to_bram_data <= 'h0;
			pxconv_to_bram_addr <= 'h1400;
			pxconv_to_bram_wr_en <= 1'b0;
			px_cnt <= 24'b0;
			px_cnt_d <= 24'b0;
			row_cnt <= 24'b0;
		end
		else begin
			axi_to_pxconv_data_d <= axi_to_pxconv_data;
			axi_to_pxconv_valid_d <= axi_to_pxconv_valid;
			px_cnt_d <= px_cnt;
			
			pxconv_to_bram_data <= {16'b0, px_low_grey[15:0]};
			
			if(axi_to_pxconv_valid) begin
				if(px_cnt == FRAME_SIZE) begin  //640*480 in hex
					px_cnt <= 24'h0;
				end
				else begin
					px_cnt <= px_cnt + 1;
				end
			end
			if(axi_to_pxconv_valid_d) begin
				pxconv_to_bram_wr_en <= 1'b1;
				if(px_cnt_d == FRAME_SIZE) begin
					px_cnt_d <= 24'b0;
				end
				else begin
					px_cnt_d <= px_cnt_d + 1;
				end
				if(pxconv_to_bram_addr == FULL_BRAM) begin
					pxconv_to_bram_addr <= 'h0;
				end 
				else begin
					pxconv_to_bram_addr <= pxconv_to_bram_addr + 1;
				end
			end
			else begin
				pxconv_to_bram_wr_en <= 1'b0;
			end
		end
	end
	
	always@(posedge clk) begin
		if(rst) begin
			pxconv_to_axi_mst_length <= BURST; //256 burst is max
		end
		else begin
			if(px_cnt < FULL_BRAM) begin
				pxconv_to_axi_mst_length <= BURST; //256 burst is max
			end
			else begin
				pxconv_to_axi_mst_length <= BURST; //16 burst read for regular reads
			end
		end
	end
	
	always@(posedge clk) begin
		if(rst) begin
			pxconv_to_axi_ready_to_rd <= 1'b0;
			row_cnt <= 24'h0;
		end
		else begin
			if(px_cnt < FULL_BRAM -1) begin //8c0 -1 = 8bf, need to stop ready_to_rd 1 cycle early.
				pxconv_to_axi_ready_to_rd <= 1'b1;
			end
			else begin

				if(pixel_ack) begin
					row_cnt <= row_cnt + 1;
					pxconv_to_axi_ready_to_rd <= 1'b1;
				end
				else begin
					pxconv_to_axi_ready_to_rd <= 1'b0;
				end
			end
		end
	end
	
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