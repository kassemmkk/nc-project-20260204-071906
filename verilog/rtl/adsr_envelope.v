`default_nettype none

module adsr_envelope #(
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
  
  input  wire [NUM_VOICES-1:0] gate,
  
  input  wire [15:0] voice_in [0:NUM_VOICES-1],
  output wire [15:0] voice_out [0:NUM_VOICES-1]
);

  localparam ADDR_VOICE_BASE = 8'h00;
  
  reg [15:0] attack_rate [0:NUM_VOICES-1];
  reg [15:0] decay_rate [0:NUM_VOICES-1];
  reg [15:0] sustain_level [0:NUM_VOICES-1];
  reg [15:0] release_rate [0:NUM_VOICES-1];
  
  reg [15:0] envelope_level [0:NUM_VOICES-1];
  reg [1:0]  envelope_state [0:NUM_VOICES-1];
  
  localparam ENV_IDLE    = 2'h0;
  localparam ENV_ATTACK  = 2'h1;
  localparam ENV_DECAY   = 2'h2;
  localparam ENV_SUSTAIN = 2'h3;
  localparam ENV_RELEASE = 2'h4;
  
  integer i;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_VOICES; i = i + 1) begin
        attack_rate[i] <= 16'h1000;
        decay_rate[i] <= 16'h0800;
        sustain_level[i] <= 16'hC000;
        release_rate[i] <= 16'h0400;
        envelope_level[i] <= 16'h0000;
        envelope_state[i] <= ENV_IDLE;
      end
    end else begin
      if (wb_cyc_i && wb_stb_i && wb_we_i && wb_ack_o) begin
        if (wb_adr_i[7:2] >= ADDR_VOICE_BASE[7:2]) begin
          automatic integer voice_idx;
          automatic integer reg_offset;
          voice_idx = ({26'h0, wb_adr_i[7:2]} - {26'h0, ADDR_VOICE_BASE[7:2]}) >> 2;
          reg_offset = ({26'h0, wb_adr_i[7:2]} - {26'h0, ADDR_VOICE_BASE[7:2]}) & 32'h3;
          
          if (voice_idx < NUM_VOICES) begin
            case (reg_offset)
              32'h0: attack_rate[voice_idx] <= wb_dat_i[15:0];
              32'h1: decay_rate[voice_idx] <= wb_dat_i[15:0];
              32'h2: sustain_level[voice_idx] <= wb_dat_i[15:0];
              32'h3: release_rate[voice_idx] <= wb_dat_i[15:0];
            endcase
          end
        end
      end
      
      if (sample_clk_en) begin
        for (i = 0; i < NUM_VOICES; i = i + 1) begin
          case (envelope_state[i])
            ENV_IDLE: begin
              if (gate[i]) begin
                envelope_state[i] <= ENV_ATTACK;
              end else begin
                envelope_level[i] <= 16'h0000;
              end
            end
            
            ENV_ATTACK: begin
              if (!gate[i]) begin
                envelope_state[i] <= ENV_RELEASE;
              end else if (envelope_level[i] >= 16'hFF00) begin
                envelope_level[i] <= 16'hFFFF;
                envelope_state[i] <= ENV_DECAY;
              end else begin
                envelope_level[i] <= envelope_level[i] + attack_rate[i];
              end
            end
            
            ENV_DECAY: begin
              if (!gate[i]) begin
                envelope_state[i] <= ENV_RELEASE;
              end else if (envelope_level[i] <= sustain_level[i] + decay_rate[i]) begin
                envelope_level[i] <= sustain_level[i];
                envelope_state[i] <= ENV_SUSTAIN;
              end else begin
                envelope_level[i] <= envelope_level[i] - decay_rate[i];
              end
            end
            
            ENV_SUSTAIN: begin
              if (!gate[i]) begin
                envelope_state[i] <= ENV_RELEASE;
              end else begin
                envelope_level[i] <= sustain_level[i];
              end
            end
            
            ENV_RELEASE: begin
              if (gate[i]) begin
                envelope_state[i] <= ENV_ATTACK;
              end else if (envelope_level[i] <= release_rate[i]) begin
                envelope_level[i] <= 16'h0000;
                envelope_state[i] <= ENV_IDLE;
              end else begin
                envelope_level[i] <= envelope_level[i] - release_rate[i];
              end
            end
            
            default: envelope_state[i] <= ENV_IDLE;
          endcase
        end
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
        if (wb_adr_i[7:2] >= ADDR_VOICE_BASE[7:2]) begin
          automatic integer voice_idx;
          automatic integer reg_offset;
          voice_idx = ({26'h0, wb_adr_i[7:2]} - {26'h0, ADDR_VOICE_BASE[7:2]}) >> 2;
          reg_offset = ({26'h0, wb_adr_i[7:2]} - {26'h0, ADDR_VOICE_BASE[7:2]}) & 32'h3;
          
          if (voice_idx < NUM_VOICES) begin
            case (reg_offset)
              32'h0: wb_dat_o <= {16'h0000, attack_rate[voice_idx]};
              32'h1: wb_dat_o <= {16'h0000, decay_rate[voice_idx]};
              32'h2: wb_dat_o <= {16'h0000, sustain_level[voice_idx]};
              32'h3: wb_dat_o <= {16'h0000, release_rate[voice_idx]};
              default: wb_dat_o <= 32'hDEADBEEF;
            endcase
          end else begin
            wb_dat_o <= 32'hDEADBEEF;
          end
        end else begin
          wb_dat_o <= 32'hDEADBEEF;
        end
      end
    end
  end
  
  genvar v;
  generate
    for (v = 0; v < NUM_VOICES; v = v + 1) begin : gen_voice_multiply
      wire signed [31:0] mult_result;
      assign mult_result = ($signed(voice_in[v]) * $signed({1'b0, envelope_level[v]})) >>> 16;
      assign voice_out[v] = mult_result[15:0];
    end
  endgenerate

endmodule

`default_nettype wire
