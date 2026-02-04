`default_nettype none

module audio_mixer #(
  parameter NUM_VOICES = 8
)(
  input  wire        clk,
  input  wire        rst_n,
  
  input  wire        sample_clk_en,
  
  input  wire        wb_cyc_i,
  input  wire        wb_stb_i,
  input  wire        wb_we_i,
  input  wire [31:0] wb_adr_i,
  input  wire [31:0] wb_dat_i,
  output reg  [31:0] wb_dat_o,
  output reg         wb_ack_o,
  
  input  wire [15:0] voice_in [0:NUM_VOICES-1],
  
  output reg  [15:0] audio_left,
  output reg  [15:0] audio_right
);

  localparam ADDR_CTRL = 8'h00;
  localparam ADDR_MASTER_VOL = 8'h04;
  localparam ADDR_PAN_BASE = 8'h08;
  localparam ADDR_CLIP_MODE = 8'h28;
  
  reg [31:0] ctrl_reg;
  reg [15:0] master_volume;
  reg [15:0] pan [0:NUM_VOICES-1];
  reg [1:0] clip_mode;
  
  wire enable;
  wire master_mute;
  
  assign enable = ctrl_reg[0];
  assign master_mute = ctrl_reg[1];
  
  integer i;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg <= 32'h00000001;
      master_volume <= 16'h8000;
      clip_mode <= 2'h1;
      for (i = 0; i < NUM_VOICES; i = i + 1) begin
        pan[i] <= 16'h8000;
      end
    end else begin
      if (wb_cyc_i && wb_stb_i && wb_we_i && wb_ack_o) begin
        case (wb_adr_i[7:2])
          ADDR_CTRL[7:2]: ctrl_reg <= wb_dat_i;
          ADDR_MASTER_VOL[7:2]: master_volume <= wb_dat_i[15:0];
          ADDR_CLIP_MODE[7:2]: clip_mode <= wb_dat_i[1:0];
          default: begin
            if (wb_adr_i[7:2] >= ADDR_PAN_BASE[7:2] && wb_adr_i[7:2] < ADDR_CLIP_MODE[7:2]) begin
              automatic integer pan_idx;
              pan_idx = wb_adr_i[7:2] - ADDR_PAN_BASE[7:2];
              if (pan_idx < NUM_VOICES) begin
                pan[pan_idx] <= wb_dat_i[15:0];
              end
            end
          end
        endcase
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
          ADDR_MASTER_VOL[7:2]: wb_dat_o <= {16'h0000, master_volume};
          ADDR_CLIP_MODE[7:2]: wb_dat_o <= {30'h00000000, clip_mode};
          default: begin
            if (wb_adr_i[7:2] >= ADDR_PAN_BASE[7:2] && wb_adr_i[7:2] < ADDR_CLIP_MODE[7:2]) begin
              automatic integer pan_idx;
              pan_idx = wb_adr_i[7:2] - ADDR_PAN_BASE[7:2];
              if (pan_idx < NUM_VOICES) begin
                wb_dat_o <= {16'h0000, pan[pan_idx]};
              end else begin
                wb_dat_o <= 32'hDEADBEEF;
              end
            end else begin
              wb_dat_o <= 32'hDEADBEEF;
            end
          end
        endcase
      end
    end
  end
  
  reg signed [19:0] mix_sum;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      audio_left <= 16'h0000;
      audio_right <= 16'h0000;
      mix_sum <= 20'sh00000;
    end else begin
      if (sample_clk_en && enable && !master_mute) begin
        mix_sum = 20'sh00000;
        
        for (i = 0; i < NUM_VOICES; i = i + 1) begin
          mix_sum = mix_sum + $signed({{4{voice_in[i][15]}}, voice_in[i]});
        end
        
        automatic logic signed [31:0] left_scaled;
        automatic logic signed [31:0] right_scaled;
        automatic logic signed [15:0] left_final;
        automatic logic signed [15:0] right_final;
        
        left_scaled = (mix_sum * $signed({1'b0, master_volume})) >>> 16;
        right_scaled = (mix_sum * $signed({1'b0, master_volume})) >>> 16;
        
        case (clip_mode)
          2'h0: begin
            left_final = left_scaled[15:0];
            right_final = right_scaled[15:0];
          end
          2'h1: begin
            if (left_scaled > $signed(17'sh7FFF))
              left_final = 16'sh7FFF;
            else if (left_scaled < $signed(17'sh8000))
              left_final = 16'sh8000;
            else
              left_final = left_scaled[15:0];
            
            if (right_scaled > $signed(17'sh7FFF))
              right_final = 16'sh7FFF;
            else if (right_scaled < $signed(17'sh8000))
              right_final = 16'sh8000;
            else
              right_final = right_scaled[15:0];
          end
          default: begin
            left_final = 16'sh0000;
            right_final = 16'sh0000;
          end
        endcase
        
        audio_left <= left_final;
        audio_right <= right_final;
      end else if (master_mute) begin
        audio_left <= 16'h0000;
        audio_right <= 16'h0000;
      end
    end
  end

endmodule

`default_nettype wire
