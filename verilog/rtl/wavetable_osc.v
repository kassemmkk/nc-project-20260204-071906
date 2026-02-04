`default_nettype none

module wavetable_osc #(
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
  
  output reg         sram_cyc_o,
  output reg         sram_stb_o,
  output reg  [31:0] sram_adr_o,
  input  wire [31:0] sram_dat_i,
  input  wire        sram_ack_i,
  
  output wire [15:0] voice_out [0:NUM_VOICES-1]
);

  localparam ADDR_CTRL    = 8'h00;
  localparam ADDR_CLK_DIV = 8'h04;
  localparam ADDR_VOICE_BASE = 8'h08;
  
  reg [31:0] ctrl_reg;
  reg [31:0] clk_div_reg;
  
  reg [31:0] voice_ctrl [0:NUM_VOICES-1];
  reg [31:0] voice_freq [0:NUM_VOICES-1];
  reg [31:0] voice_phase [0:NUM_VOICES-1];
  reg [31:0] voice_wavetable [0:NUM_VOICES-1];
  
  wire enable;
  wire output_mute;
  
  assign enable = ctrl_reg[0];
  assign output_mute = ctrl_reg[1];
  
  reg [15:0] sample_counter;
  reg        sample_tick;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sample_counter <= 16'h0000;
      sample_tick <= 1'b0;
    end else begin
      if (enable) begin
        if (sample_counter >= clk_div_reg[15:0] - 1) begin
          sample_counter <= 16'h0000;
          sample_tick <= 1'b1;
        end else begin
          sample_counter <= sample_counter + 1'b1;
          sample_tick <= 1'b0;
        end
      end else begin
        sample_counter <= 16'h0000;
        sample_tick <= 1'b0;
      end
    end
  end
  
  integer i;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg <= 32'h00000001;
      clk_div_reg <= 32'h000003E8;
      for (i = 0; i < NUM_VOICES; i = i + 1) begin
        voice_ctrl[i] <= 32'h00000000;
        voice_freq[i] <= 32'h00000000;
        voice_phase[i] <= 32'h00000000;
        voice_wavetable[i] <= 32'h00000000;
      end
    end else begin
      if (wb_cyc_i && wb_stb_i && wb_we_i && wb_ack_o) begin
        case (wb_adr_i[7:2])
          ADDR_CTRL[7:2]: ctrl_reg <= wb_dat_i;
          ADDR_CLK_DIV[7:2]: clk_div_reg <= wb_dat_i;
          default: begin
            if (wb_adr_i[7:2] >= ADDR_VOICE_BASE[7:2]) begin
              automatic integer voice_idx;
              automatic integer reg_offset;
              voice_idx = (wb_adr_i[7:2] - ADDR_VOICE_BASE[7:2]) >> 2;
              reg_offset = (wb_adr_i[7:2] - ADDR_VOICE_BASE[7:2]) & 2'h3;
              
              if (voice_idx < NUM_VOICES) begin
                case (reg_offset)
                  2'h0: voice_ctrl[voice_idx] <= wb_dat_i;
                  2'h1: voice_freq[voice_idx] <= wb_dat_i;
                  2'h2: voice_phase[voice_idx] <= wb_dat_i;
                  2'h3: voice_wavetable[voice_idx] <= wb_dat_i;
                endcase
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
          ADDR_CLK_DIV[7:2]: wb_dat_o <= clk_div_reg;
          default: begin
            if (wb_adr_i[7:2] >= ADDR_VOICE_BASE[7:2]) begin
              automatic integer voice_idx;
              automatic integer reg_offset;
              voice_idx = (wb_adr_i[7:2] - ADDR_VOICE_BASE[7:2]) >> 2;
              reg_offset = (wb_adr_i[7:2] - ADDR_VOICE_BASE[7:2]) & 2'h3;
              
              if (voice_idx < NUM_VOICES) begin
                case (reg_offset)
                  2'h0: wb_dat_o <= voice_ctrl[voice_idx];
                  2'h1: wb_dat_o <= voice_freq[voice_idx];
                  2'h2: wb_dat_o <= voice_phase[voice_idx];
                  2'h3: wb_dat_o <= voice_wavetable[voice_idx];
                  default: wb_dat_o <= 32'hDEADBEEF;
                endcase
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
  
  reg [2:0] current_voice;
  reg [2:0] sram_state;
  
  localparam STATE_IDLE = 3'h0;
  localparam STATE_READ_REQ = 3'h1;
  localparam STATE_READ_WAIT = 3'h2;
  localparam STATE_INTERPOLATE = 3'h3;
  
  reg [31:0] sample_n;
  reg [31:0] sample_n1;
  reg [15:0] voice_output [0:NUM_VOICES-1];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_voice <= 3'h0;
      sram_state <= STATE_IDLE;
      sram_cyc_o <= 1'b0;
      sram_stb_o <= 1'b0;
      sram_adr_o <= 32'h00000000;
      sample_n <= 32'h00000000;
      sample_n1 <= 32'h00000000;
      for (i = 0; i < NUM_VOICES; i = i + 1) begin
        voice_output[i] <= 16'h0000;
      end
    end else begin
      case (sram_state)
        STATE_IDLE: begin
          if (sample_tick && enable) begin
            current_voice <= 3'h0;
            sram_state <= STATE_READ_REQ;
          end
        end
        
        STATE_READ_REQ: begin
          if (voice_ctrl[current_voice][0]) begin
            automatic logic [11:0] wave_base;
            automatic logic [7:0] wave_len;
            automatic logic [31:0] phase_int;
            
            wave_base = voice_wavetable[current_voice][11:0];
            wave_len = voice_wavetable[current_voice][19:12];
            phase_int = voice_phase[current_voice][31:16];
            
            sram_adr_o <= {20'h0, wave_base} + (phase_int & {{24{1'b0}}, wave_len});
            sram_cyc_o <= 1'b1;
            sram_stb_o <= 1'b1;
            sram_state <= STATE_READ_WAIT;
          end else begin
            voice_output[current_voice] <= 16'h0000;
            if (current_voice < NUM_VOICES - 1) begin
              current_voice <= current_voice + 1'b1;
              sram_state <= STATE_READ_REQ;
            end else begin
              sram_state <= STATE_IDLE;
            end
          end
        end
        
        STATE_READ_WAIT: begin
          if (sram_ack_i) begin
            sample_n <= sram_dat_i;
            sram_cyc_o <= 1'b0;
            sram_stb_o <= 1'b0;
            sram_state <= STATE_INTERPOLATE;
          end
        end
        
        STATE_INTERPOLATE: begin
          automatic logic [15:0] frac;
          automatic logic signed [31:0] interp_result;
          
          frac = voice_phase[current_voice][15:0];
          interp_result = $signed(sample_n[15:0]) + 
                         ((($signed(sample_n1[15:0]) - $signed(sample_n[15:0])) * $signed({1'b0, frac})) >>> 16);
          
          voice_output[current_voice] <= interp_result[15:0];
          
          voice_phase[current_voice] <= voice_phase[current_voice] + voice_freq[current_voice];
          
          if (current_voice < NUM_VOICES - 1) begin
            current_voice <= current_voice + 1'b1;
            sram_state <= STATE_READ_REQ;
          end else begin
            sram_state <= STATE_IDLE;
          end
        end
        
        default: sram_state <= STATE_IDLE;
      endcase
    end
  end
  
  genvar v;
  generate
    for (v = 0; v < NUM_VOICES; v = v + 1) begin : gen_voice_outputs
      assign voice_out[v] = output_mute ? 16'h0000 : voice_output[v];
    end
  endgenerate

endmodule

`default_nettype wire
