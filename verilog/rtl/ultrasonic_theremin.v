`default_nettype none

module ultrasonic_theremin(
  input  wire        clk,
  input  wire        rst_n,
  
  input  wire        wb_cyc_i,
  input  wire        wb_stb_i,
  input  wire        wb_we_i,
  input  wire [31:0] wb_adr_i,
  input  wire [31:0] wb_dat_i,
  output reg  [31:0] wb_dat_o,
  output reg         wb_ack_o,
  
  output reg         pitch_trigger,
  input  wire        pitch_echo,
  output reg         volume_trigger,
  input  wire        volume_echo,
  
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
  localparam ADDR_TRIGGER_PERIOD = 8'h20;
  
  reg [31:0] ctrl_reg;
  reg [15:0] pitch_raw;
  reg [15:0] volume_raw;
  reg [15:0] pitch_scale;
  reg [15:0] volume_scale;
  reg [15:0] trigger_period;
  
  wire enable;
  wire auto_sample;
  
  assign enable = ctrl_reg[0];
  assign auto_sample = ctrl_reg[1];
  
  reg measuring_busy;
  reg data_ready;
  
  assign irq = data_ready;
  
  localparam TRIGGER_WIDTH = 16'd500;
  
  reg [15:0] trigger_counter;
  reg trigger_active;
  
  reg pitch_measuring;
  reg [15:0] pitch_timer;
  reg pitch_echo_prev;
  
  reg volume_measuring;
  reg [15:0] volume_timer;
  reg volume_echo_prev;
  
  reg [2:0] measure_state;
  localparam STATE_IDLE = 3'h0;
  localparam STATE_PITCH_TRIGGER = 3'h1;
  localparam STATE_PITCH_WAIT = 3'h2;
  localparam STATE_PITCH_MEASURE = 3'h3;
  localparam STATE_VOLUME_TRIGGER = 3'h4;
  localparam STATE_VOLUME_WAIT = 3'h5;
  localparam STATE_VOLUME_MEASURE = 3'h6;
  localparam STATE_DONE = 3'h7;
  
  integer i;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg <= 32'h00000003;
      pitch_scale <= 16'h0100;
      volume_scale <= 16'h0100;
      trigger_period <= 16'd3000;
      pitch_raw <= 16'h0000;
      volume_raw <= 16'h0000;
      pitch_mod <= 16'h0000;
      volume_mod <= 16'h8000;
      trigger_counter <= 16'h0000;
      trigger_active <= 1'b0;
      measuring_busy <= 1'b0;
      data_ready <= 1'b0;
      measure_state <= STATE_IDLE;
      pitch_trigger <= 1'b0;
      volume_trigger <= 1'b0;
      pitch_measuring <= 1'b0;
      pitch_timer <= 16'h0000;
      pitch_echo_prev <= 1'b0;
      volume_measuring <= 1'b0;
      volume_timer <= 16'h0000;
      volume_echo_prev <= 1'b0;
    end else begin
      if (wb_cyc_i && wb_stb_i && wb_we_i && wb_ack_o) begin
        case (wb_adr_i[7:2])
          ADDR_CTRL[7:2]: ctrl_reg <= wb_dat_i;
          ADDR_PITCH_SCALE[7:2]: pitch_scale <= wb_dat_i[15:0];
          ADDR_VOLUME_SCALE[7:2]: volume_scale <= wb_dat_i[15:0];
          ADDR_TRIGGER_PERIOD[7:2]: trigger_period <= wb_dat_i[15:0];
          default: ;
        endcase
      end
      
      if (enable && auto_sample) begin
        if (trigger_counter >= trigger_period) begin
          trigger_counter <= 16'h0000;
          trigger_active <= 1'b1;
        end else begin
          trigger_counter <= trigger_counter + 1'b1;
          trigger_active <= 1'b0;
        end
      end else begin
        trigger_counter <= 16'h0000;
        trigger_active <= 1'b0;
      end
      
      pitch_echo_prev <= pitch_echo;
      volume_echo_prev <= volume_echo;
      
      case (measure_state)
        STATE_IDLE: begin
          if (trigger_active && !measuring_busy) begin
            measure_state <= STATE_PITCH_TRIGGER;
            measuring_busy <= 1'b1;
            data_ready <= 1'b0;
          end
        end
        
        STATE_PITCH_TRIGGER: begin
          pitch_trigger <= 1'b1;
          pitch_timer <= 16'h0000;
          if (pitch_timer < TRIGGER_WIDTH)
            pitch_timer <= pitch_timer + 1'b1;
          else begin
            pitch_trigger <= 1'b0;
            measure_state <= STATE_PITCH_WAIT;
          end
        end
        
        STATE_PITCH_WAIT: begin
          if (pitch_echo && !pitch_echo_prev) begin
            pitch_measuring <= 1'b1;
            pitch_timer <= 16'h0001;
            measure_state <= STATE_PITCH_MEASURE;
          end else if (pitch_timer > 16'd30000) begin
            pitch_raw <= 16'hFFFF;
            measure_state <= STATE_VOLUME_TRIGGER;
          end else begin
            pitch_timer <= pitch_timer + 1'b1;
          end
        end
        
        STATE_PITCH_MEASURE: begin
          if (pitch_echo) begin
            if (pitch_timer < 16'hFFFE)
              pitch_timer <= pitch_timer + 1'b1;
          end else if (pitch_echo_prev && !pitch_echo) begin
            pitch_measuring <= 1'b0;
            pitch_raw <= pitch_timer;
            pitch_mod <= ((pitch_timer * pitch_scale) >> 8) & 16'hFFFF;
            measure_state <= STATE_VOLUME_TRIGGER;
          end
        end
        
        STATE_VOLUME_TRIGGER: begin
          volume_trigger <= 1'b1;
          volume_timer <= 16'h0000;
          if (volume_timer < TRIGGER_WIDTH)
            volume_timer <= volume_timer + 1'b1;
          else begin
            volume_trigger <= 1'b0;
            measure_state <= STATE_VOLUME_WAIT;
          end
        end
        
        STATE_VOLUME_WAIT: begin
          if (volume_echo && !volume_echo_prev) begin
            volume_measuring <= 1'b1;
            volume_timer <= 16'h0001;
            measure_state <= STATE_VOLUME_MEASURE;
          end else if (volume_timer > 16'd30000) begin
            volume_raw <= 16'hFFFF;
            measure_state <= STATE_DONE;
          end else begin
            volume_timer <= volume_timer + 1'b1;
          end
        end
        
        STATE_VOLUME_MEASURE: begin
          if (volume_echo) begin
            if (volume_timer < 16'hFFFE)
              volume_timer <= volume_timer + 1'b1;
          end else if (volume_echo_prev && !volume_echo) begin
            volume_measuring <= 1'b0;
            volume_raw <= volume_timer;
            volume_mod <= ((volume_timer * volume_scale) >> 8) & 16'hFFFF;
            measure_state <= STATE_DONE;
          end
        end
        
        STATE_DONE: begin
          measuring_busy <= 1'b0;
          data_ready <= 1'b1;
          measure_state <= STATE_IDLE;
        end
        
        default: measure_state <= STATE_IDLE;
      endcase
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
          ADDR_STATUS[7:2]: wb_dat_o <= {30'h00000000, data_ready, measuring_busy};
          ADDR_PITCH_RAW[7:2]: wb_dat_o <= {16'h0000, pitch_raw};
          ADDR_VOLUME_RAW[7:2]: wb_dat_o <= {16'h0000, volume_raw};
          ADDR_PITCH_MOD[7:2]: wb_dat_o <= {16'h0000, pitch_mod};
          ADDR_VOLUME_MOD[7:2]: wb_dat_o <= {16'h0000, volume_mod};
          ADDR_PITCH_SCALE[7:2]: wb_dat_o <= {16'h0000, pitch_scale};
          ADDR_VOLUME_SCALE[7:2]: wb_dat_o <= {16'h0000, volume_scale};
          ADDR_TRIGGER_PERIOD[7:2]: wb_dat_o <= {16'h0000, trigger_period};
          default: wb_dat_o <= 32'hDEADBEEF;
        endcase
      end
    end
  end

endmodule

`default_nettype wire
