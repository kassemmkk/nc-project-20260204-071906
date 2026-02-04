`default_nettype none

module keyboard_scanner #(
  parameter NUM_ROWS = 6,
  parameter NUM_COLS = 7,
  parameter FIFO_DEPTH = 16
)(
  input  wire        clk,
  input  wire        rst_n,
  
  input  wire [5:0]  row_in,
  output reg  [5:0]  row_out,
  input  wire [6:0]  col_in,
  
  input  wire        wb_cyc_i,
  input  wire        wb_stb_i,
  input  wire        wb_we_i,
  input  wire [31:0] wb_adr_i,
  input  wire [31:0] wb_dat_i,
  output reg  [31:0] wb_dat_o,
  output reg         wb_ack_o,
  
  output wire        irq
);

  localparam ADDR_CTRL       = 8'h00;
  localparam ADDR_STATUS     = 8'h04;
  localparam ADDR_EVENT      = 8'h08;
  localparam ADDR_IRQ_EN     = 8'h0C;
  localparam ADDR_IRQ_STATUS = 8'h10;
  localparam ADDR_SCAN_MAP   = 8'h14;
  
  reg [31:0] ctrl_reg;
  reg [31:0] irq_en_reg;
  reg [31:0] irq_status_reg;
  
  wire       enable;
  wire       scan_mode;
  wire [3:0] debounce_time;
  wire [7:0] scan_rate_div;
  
  assign enable = ctrl_reg[0];
  assign scan_mode = ctrl_reg[1];
  assign debounce_time = ctrl_reg[7:4];
  assign scan_rate_div = ctrl_reg[15:8];
  
  reg [2:0]  current_row;
  reg [15:0] scan_counter;
  reg [15:0] debounce_counter [41:0];
  reg [41:0] key_state;
  reg [41:0] key_state_prev;
  reg [15:0] velocity_timer [41:0];
  reg [41:0] velocity_measuring;
  
  wire [41:0] key_pressed;
  wire [41:0] key_released;
  
  reg [31:0] event_fifo [0:FIFO_DEPTH-1];
  reg [3:0]  fifo_wr_ptr;
  reg [3:0]  fifo_rd_ptr;
  reg [3:0]  fifo_count;
  
  wire       fifo_empty;
  wire       fifo_full;
  wire       fifo_overflow;
  
  assign fifo_empty = (fifo_count == 4'h0);
  assign fifo_full = (fifo_count == 4'd16);
  
  reg fifo_overflow_flag;
  assign fifo_overflow = fifo_overflow_flag;
  
  integer i;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg <= 32'h00000051;
      irq_en_reg <= 32'h00000001;
      irq_status_reg <= 32'h00000000;
      fifo_overflow_flag <= 1'b0;
    end else begin
      if (wb_cyc_i && wb_stb_i && wb_we_i && wb_ack_o) begin
        case (wb_adr_i[7:2])
          ADDR_CTRL[7:2]: ctrl_reg <= wb_dat_i;
          ADDR_IRQ_EN[7:2]: irq_en_reg <= wb_dat_i;
          ADDR_IRQ_STATUS[7:2]: irq_status_reg <= irq_status_reg & ~wb_dat_i;
          default: ;
        endcase
      end
      
      if (!fifo_empty && irq_en_reg[0])
        irq_status_reg[0] <= 1'b1;
      
      if (fifo_overflow && irq_en_reg[1]) begin
        irq_status_reg[1] <= 1'b1;
        fifo_overflow_flag <= 1'b1;
      end
      
      if (wb_cyc_i && wb_stb_i && wb_we_i && (wb_adr_i[7:2] == ADDR_IRQ_STATUS[7:2]))
        if (wb_dat_i[1])
          fifo_overflow_flag <= 1'b0;
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
          ADDR_CTRL[7:2]:       wb_dat_o <= ctrl_reg;
          ADDR_STATUS[7:2]:     wb_dat_o <= {20'h0, fifo_count, 4'h0, fifo_overflow, fifo_full, !fifo_empty, enable};
          ADDR_EVENT[7:2]:      wb_dat_o <= fifo_empty ? 32'h00000000 : event_fifo[fifo_rd_ptr];
          ADDR_IRQ_EN[7:2]:     wb_dat_o <= irq_en_reg;
          ADDR_IRQ_STATUS[7:2]: wb_dat_o <= irq_status_reg;
          ADDR_SCAN_MAP[7:2]:   wb_dat_o <= {18'h0, col_in, 4'h0, 1'b0, current_row};
          default:              wb_dat_o <= 32'hDEADBEEF;
        endcase
      end
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_row <= 3'h0;
      scan_counter <= 16'h0000;
      row_out <= 6'b000000;
      for (i = 0; i < 42; i = i + 1) begin
        key_state[i] <= 1'b0;
        key_state_prev[i] <= 1'b0;
        debounce_counter[i] <= 16'h0000;
        velocity_timer[i] <= 16'h0000;
        velocity_measuring[i] <= 1'b0;
      end
    end else begin
      if (enable) begin
        scan_counter <= scan_counter + 1'b1;
        
        if (scan_counter >= {scan_rate_div, 8'h00}) begin
          scan_counter <= 16'h0000;
          
          if (current_row < NUM_ROWS - 1)
            current_row <= current_row + 1'b1;
          else
            current_row <= 3'h0;
        end
        
        row_out <= (6'b000001 << current_row);
        
        for (i = 0; i < NUM_COLS; i = i + 1) begin
          if (i < NUM_COLS) begin
            automatic integer key_num;
            automatic logic col_pressed;
            key_num = current_row * NUM_COLS + i;
            
            if (key_num < 42) begin
              col_pressed = !col_in[i];
              
              if (col_pressed && !velocity_measuring[key_num]) begin
                velocity_measuring[key_num] <= 1'b1;
                velocity_timer[key_num] <= 16'h0000;
              end else if (velocity_measuring[key_num]) begin
                if (velocity_timer[key_num] < 16'hFFFF)
                  velocity_timer[key_num] <= velocity_timer[key_num] + 1'b1;
              end
              
              if (col_pressed != key_state[key_num]) begin
                if (debounce_counter[key_num] < {debounce_time, 12'h000})
                  debounce_counter[key_num] <= debounce_counter[key_num] + 1'b1;
                else begin
                  key_state[key_num] <= col_pressed;
                  debounce_counter[key_num] <= 16'h0000;
                  
                  if (col_pressed)
                    velocity_measuring[key_num] <= 1'b0;
                end
              end else begin
                debounce_counter[key_num] <= 16'h0000;
              end
            end
          end
        end
        
        key_state_prev <= key_state;
      end else begin
        row_out <= 6'b000000;
        current_row <= 3'h0;
        scan_counter <= 16'h0000;
      end
    end
  end
  
  assign key_pressed = key_state & ~key_state_prev;
  assign key_released = ~key_state & key_state_prev;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fifo_wr_ptr <= 4'h0;
      fifo_rd_ptr <= 4'h0;
      fifo_count <= 4'h0;
      for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
        event_fifo[i] <= 32'h00000000;
      end
    end else begin
      if (wb_cyc_i && wb_stb_i && !wb_we_i && (wb_adr_i[7:2] == ADDR_EVENT[7:2]) && !fifo_empty) begin
        if (fifo_rd_ptr < FIFO_DEPTH - 1)
          fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
        else
          fifo_rd_ptr <= 4'h0;
        
        if (fifo_count > 0)
          fifo_count <= fifo_count - 1'b1;
      end
      
      if (enable) begin
        for (i = 0; i < 42; i = i + 1) begin
          if (key_pressed[i] || key_released[i]) begin
            if (!fifo_full) begin
              automatic logic [7:0] velocity;
              automatic logic [7:0] timestamp;
              
              if (velocity_timer[i] < 16'h0080)
                velocity = 8'h7F;
              else if (velocity_timer[i] < 16'h0100)
                velocity = 8'h70 - (velocity_timer[i][7:4]);
              else if (velocity_timer[i] < 16'h0200)
                velocity = 8'h60 - (velocity_timer[i][8:5]);
              else if (velocity_timer[i] < 16'h0400)
                velocity = 8'h50 - (velocity_timer[i][9:6]);
              else if (velocity_timer[i] < 16'h0800)
                velocity = 8'h40 - (velocity_timer[i][10:7]);
              else
                velocity = 8'h20;
              
              timestamp = scan_counter[15:8];
              
              event_fifo[fifo_wr_ptr] <= {timestamp, 7'h00, key_pressed[i], velocity, i[7:0]};
              
              if (fifo_wr_ptr < FIFO_DEPTH - 1)
                fifo_wr_ptr <= fifo_wr_ptr + 1'b1;
              else
                fifo_wr_ptr <= 4'h0;
              
              if (fifo_count < FIFO_DEPTH)
                fifo_count <= fifo_count + 1'b1;
            end else begin
              fifo_overflow_flag <= 1'b1;
            end
          end
        end
      end
    end
  end
  
  assign irq = |(irq_status_reg & irq_en_reg);

endmodule

`default_nettype wire
