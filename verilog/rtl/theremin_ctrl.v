`default_nettype none

module theremin_ctrl(
  input  wire        clk,
  input  wire        rst_n,
  
  input  wire        wb_cyc_i,
  input  wire        wb_stb_i,
  input  wire        wb_we_i,
  input  wire [31:0] wb_adr_i,
  input  wire [31:0] wb_dat_i,
  output reg  [31:0] wb_dat_o,
  output reg         wb_ack_o,
  
  output reg         spi_cyc_o,
  output reg         spi_stb_o,
  output reg         spi_we_o,
  output reg  [31:0] spi_adr_o,
  output reg  [31:0] spi_dat_o,
  input  wire [31:0] spi_dat_i,
  input  wire        spi_ack_i,
  
  output reg  [15:0] pitch_mod,
  output reg  [15:0] volume_mod,
  output wire        irq
);

  localparam ADDR_CTRL = 8'h00;
  localparam ADDR_STATUS = 8'h04;
  localparam ADDR_PITCH_RAW = 8'h08;
  localparam ADDR_VOLUME_RAW = 8'h0C;
  localparam ADDR_PITCH_MOD = 8'h10;
  localparam ADDR_VOLUME_MOD = 8'h14;
  localparam ADDR_PITCH_SCALE = 8'h18;
  localparam ADDR_VOLUME_SCALE = 8'h1C;
  localparam ADDR_FILTER_DEPTH = 8'h20;
  
  reg [31:0] ctrl_reg;
  reg [15:0] pitch_raw;
  reg [15:0] volume_raw;
  reg [15:0] pitch_scale;
  reg [15:0] volume_scale;
  reg [3:0] filter_depth;
  
  wire enable;
  wire auto_sample;
  wire [7:0] sample_rate_div;
  
  assign enable = ctrl_reg[0];
  assign auto_sample = ctrl_reg[1];
  assign sample_rate_div = ctrl_reg[15:8];
  
  reg [15:0] sample_counter;
  reg sample_trigger;
  reg adc_busy;
  reg data_ready;
  
  reg [15:0] pitch_history [0:15];
  reg [15:0] volume_history [0:15];
  reg [3:0] history_idx;
  
  assign irq = data_ready;
  
  integer i;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg <= 32'h00000A01;
      pitch_scale <= 16'h0100;
      volume_scale <= 16'h0100;
      filter_depth <= 4'h8;
      pitch_raw <= 16'h0000;
      volume_raw <= 16'h0000;
      pitch_mod <= 16'h0000;
      volume_mod <= 16'h8000;
      sample_counter <= 16'h0000;
      sample_trigger <= 1'b0;
      adc_busy <= 1'b0;
      data_ready <= 1'b0;
      history_idx <= 4'h0;
      for (i = 0; i < 16; i = i + 1) begin
        pitch_history[i] <= 16'h0000;
        volume_history[i] <= 16'h0000;
      end
    end else begin
      if (wb_cyc_i && wb_stb_i && wb_we_i && wb_ack_o) begin
        case (wb_adr_i[7:2])
          ADDR_CTRL[7:2]: ctrl_reg <= wb_dat_i;
          ADDR_PITCH_SCALE[7:2]: pitch_scale <= wb_dat_i[15:0];
          ADDR_VOLUME_SCALE[7:2]: volume_scale <= wb_dat_i[15:0];
          ADDR_FILTER_DEPTH[7:2]: filter_depth <= wb_dat_i[3:0];
          default: ;
        endcase
      end
      
      if (enable && auto_sample) begin
        if (sample_counter >= {sample_rate_div, 8'h00}) begin
          sample_counter <= 16'h0000;
          sample_trigger <= 1'b1;
        end else begin
          sample_counter <= sample_counter + 1'b1;
          sample_trigger <= 1'b0;
        end
      end else begin
        sample_counter <= 16'h0000;
        sample_trigger <= 1'b0;
      end
      
      if (sample_trigger && !adc_busy) begin
        adc_busy <= 1'b1;
        data_ready <= 1'b0;
      end else if (adc_busy && spi_ack_i) begin
        pitch_raw <= spi_dat_i[15:0];
        
        pitch_history[history_idx] <= spi_dat_i[15:0];
        
        automatic logic [19:0] pitch_sum;
        pitch_sum = 20'h00000;
        for (i = 0; i < 16; i = i + 1) begin
          if (i < filter_depth)
            pitch_sum = pitch_sum + pitch_history[i];
        end
        pitch_mod <= pitch_sum[19:4];
        
        if (history_idx < filter_depth - 1)
          history_idx <= history_idx + 1'b1;
        else
          history_idx <= 4'h0;
        
        adc_busy <= 1'b0;
        data_ready <= 1'b1;
      end
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spi_cyc_o <= 1'b0;
      spi_stb_o <= 1'b0;
      spi_we_o <= 1'b0;
      spi_adr_o <= 32'h00000000;
      spi_dat_o <= 32'h00000000;
    end else begin
      if (sample_trigger && !adc_busy) begin
        spi_cyc_o <= 1'b1;
        spi_stb_o <= 1'b1;
        spi_we_o <= 1'b0;
        spi_adr_o <= 32'h00000000;
      end else if (spi_ack_i) begin
        spi_cyc_o <= 1'b0;
        spi_stb_o <= 1'b0;
      end
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wb_ack_o <= 1'b0;
    end else begin
      wb_ack_o <= wb_cyc_i && wb_stb_i && !wb_ack_o;
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wb_dat_o <= 32'h00000000;
    end else begin
      if (wb_cyc_i && wb_stb_i && !wb_we_i) begin
        case (wb_adr_i[7:2])
          ADDR_CTRL[7:2]: wb_dat_o <= ctrl_reg;
          ADDR_STATUS[7:2]: wb_dat_o <= {30'h00000000, data_ready, adc_busy};
          ADDR_PITCH_RAW[7:2]: wb_dat_o <= {16'h0000, pitch_raw};
          ADDR_VOLUME_RAW[7:2]: wb_dat_o <= {16'h0000, volume_raw};
          ADDR_PITCH_MOD[7:2]: wb_dat_o <= {16'h0000, pitch_mod};
          ADDR_VOLUME_MOD[7:2]: wb_dat_o <= {16'h0000, volume_mod};
          ADDR_PITCH_SCALE[7:2]: wb_dat_o <= {16'h0000, pitch_scale};
          ADDR_VOLUME_SCALE[7:2]: wb_dat_o <= {16'h0000, volume_scale};
          ADDR_FILTER_DEPTH[7:2]: wb_dat_o <= {28'h0000000, filter_depth};
          default: wb_dat_o <= 32'hDEADBEEF;
        endcase
      end
    end
  end

endmodule

`default_nettype wire
