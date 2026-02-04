`default_nettype none

module voice_manager #(
  parameter NUM_VOICES = 8
)(
  input  wire        clk,
  input  wire        rst_n,
  
  input  wire        wb_cyc_i,
  input  wire        wb_stb_i,
  input  wire        wb_we_i,
  input  wire [31:0] wb_adr_i,
  input  wire [31:0] wb_dat_i,
  output reg  [31:0] wb_dat_o,
  output reg         wb_ack_o,
  
  output reg  [NUM_VOICES-1:0] voice_gate
);

  localparam ADDR_CTRL = 8'h00;
  localparam ADDR_STATUS = 8'h04;
  localparam ADDR_VOICE_BASE = 8'h08;
  
  reg [31:0] ctrl_reg;
  
  reg [7:0] voice_note [0:NUM_VOICES-1];
  reg [7:0] voice_velocity [0:NUM_VOICES-1];
  reg [NUM_VOICES-1:0] voice_active;
  
  wire enable;
  wire [2:0] steal_policy;
  
  assign enable = ctrl_reg[0];
  assign steal_policy = ctrl_reg[3:1];
  
  reg [7:0] active_voice_count;
  
  integer i;
  
  always @(*) begin
    active_voice_count = 8'h00;
    for (i = 0; i < NUM_VOICES; i = i + 1) begin
      if (voice_active[i])
        active_voice_count = active_voice_count + 1'b1;
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg <= 32'h00000001;
      voice_gate <= {NUM_VOICES{1'b0}};
      for (i = 0; i < NUM_VOICES; i = i + 1) begin
        voice_note[i] <= 8'h00;
        voice_velocity[i] <= 8'h00;
        voice_active[i] <= 1'b0;
      end
    end else begin
      if (wb_cyc_i && wb_stb_i && wb_we_i && wb_ack_o) begin
        case (wb_adr_i[7:2])
          ADDR_CTRL[7:2]: ctrl_reg <= wb_dat_i;
          default: begin
            if (wb_adr_i[7:2] >= ADDR_VOICE_BASE[7:2]) begin
              automatic integer voice_idx;
              voice_idx = wb_adr_i[7:2] - ADDR_VOICE_BASE[7:2];
              
              if (voice_idx < NUM_VOICES) begin
                voice_note[voice_idx] <= wb_dat_i[7:0];
                voice_velocity[voice_idx] <= wb_dat_i[15:8];
                voice_active[voice_idx] <= wb_dat_i[16];
                voice_gate[voice_idx] <= wb_dat_i[17];
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
          ADDR_STATUS[7:2]: wb_dat_o <= {20'h00000, active_voice_count, voice_active};
          default: begin
            if (wb_adr_i[7:2] >= ADDR_VOICE_BASE[7:2]) begin
              automatic integer voice_idx;
              voice_idx = wb_adr_i[7:2] - ADDR_VOICE_BASE[7:2];
              
              if (voice_idx < NUM_VOICES) begin
                wb_dat_o <= {14'h0000, voice_gate[voice_idx], voice_active[voice_idx], 
                             voice_velocity[voice_idx], voice_note[voice_idx]};
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

endmodule

`default_nettype wire
