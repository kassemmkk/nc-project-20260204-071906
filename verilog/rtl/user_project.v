`default_nettype none

module user_project #(
  parameter NUM_VOICES = 8,
  parameter NUM_PERIPHERALS = 11
)(
`ifdef USE_POWER_PINS
  inout vccd1,
  inout vssd1,
`endif
  
  input  wire        wb_clk_i,
  input  wire        wb_rst_i,
  
  input  wire        wbs_cyc_i,
  input  wire        wbs_stb_i,
  input  wire        wbs_we_i,
  input  wire [3:0]  wbs_sel_i,
  input  wire [31:0] wbs_adr_i,
  input  wire [31:0] wbs_dat_i,
  output wire        wbs_ack_o,
  output wire [31:0] wbs_dat_o,
  
  output wire [2:0]  user_irq,
  
  input  wire [5:0]  keyboard_row_in,
  output wire [5:0]  keyboard_row_out,
  input  wire [6:0]  keyboard_col_in,
  
  output wire        i2s_sclk,
  output wire        i2s_ws,
  output wire        i2s_sd,
  
  output wire        spi_sck,
  output wire        spi_mosi,
  input  wire        spi_miso,
  output wire        spi_cs_n,
  
  output wire        status_led0,
  output wire        status_led1
);

  wire rst_n;
  assign rst_n = !wb_rst_i;
  
  wire [NUM_PERIPHERALS-1:0] periph_cyc;
  wire [NUM_PERIPHERALS-1:0] periph_stb;
  wire [NUM_PERIPHERALS-1:0] periph_ack;
  wire [NUM_PERIPHERALS-1:0] periph_err;
  wire [NUM_PERIPHERALS*32-1:0] periph_dat_o;
  
  wishbone_bus_splitter #(
    .NUM_PERIPHERALS(NUM_PERIPHERALS),
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .SEL_WIDTH(4),
    .ADDR_SEL_LOW_BIT(16)
  ) bus_splitter (
    .clk(wb_clk_i),
    .rst(wb_rst_i),
    
    .m_wb_adr_i(wbs_adr_i),
    .m_wb_dat_i(wbs_dat_i),
    .m_wb_we_i(wbs_we_i),
    .m_wb_sel_i(wbs_sel_i),
    .m_wb_cyc_i(wbs_cyc_i),
    .m_wb_stb_i(wbs_stb_i),
    .m_wb_dat_o(wbs_dat_o),
    .m_wb_ack_o(wbs_ack_o),
    .m_wb_err_o(),
    
    .s_wb_cyc_o(periph_cyc),
    .s_wb_stb_o(periph_stb),
    .s_wb_we_o(),
    .s_wb_sel_o(),
    .s_wb_adr_o(),
    .s_wb_dat_o(),
    .s_wb_dat_i(periph_dat_o),
    .s_wb_ack_i(periph_ack),
    .s_wb_err_i(periph_err)
  );
  
  wire [31:0] gpio0_dat_o, gpio1_dat_o;
  wire gpio0_ack, gpio1_ack;
  wire [7:0] gpio0_out, gpio1_out;
  wire [7:0] gpio0_in, gpio1_in;
  wire [7:0] gpio0_dir, gpio1_dir;
  wire gpio0_irq, gpio1_irq;
  
  assign gpio0_in = {2'b00, keyboard_row_in};
  assign keyboard_row_out = gpio0_out[5:0];
  assign gpio1_in = {1'b0, keyboard_col_in};
  
  EF_GPIO8_WB gpio0_inst (
    .clk_i(wb_clk_i),
    .rst_n(rst_n),
    .bus_cyc_i(periph_cyc[0]),
    .bus_stb_i(periph_stb[0]),
    .bus_we_i(wbs_we_i),
    .bus_adr_i(wbs_adr_i[15:0]),
    .bus_dat_i(wbs_dat_i),
    .bus_dat_o(gpio0_dat_o),
    .bus_ack_o(gpio0_ack),
    .gpio_in(gpio0_in),
    .gpio_out(gpio0_out),
    .gpio_dir(gpio0_dir),
    .gpio_irq(gpio0_irq)
  );
  
  assign periph_dat_o[31:0] = gpio0_dat_o;
  assign periph_ack[0] = gpio0_ack;
  assign periph_err[0] = 1'b0;
  
  EF_GPIO8_WB gpio1_inst (
    .clk_i(wb_clk_i),
    .rst_n(rst_n),
    .bus_cyc_i(periph_cyc[1]),
    .bus_stb_i(periph_stb[1]),
    .bus_we_i(wbs_we_i),
    .bus_adr_i(wbs_adr_i[15:0]),
    .bus_dat_i(wbs_dat_i),
    .bus_dat_o(gpio1_dat_o),
    .bus_ack_o(gpio1_ack),
    .gpio_in(gpio1_in),
    .gpio_out(gpio1_out),
    .gpio_dir(gpio1_dir),
    .gpio_irq(gpio1_irq)
  );
  
  assign periph_dat_o[63:32] = gpio1_dat_o;
  assign periph_ack[1] = gpio1_ack;
  assign periph_err[1] = 1'b0;
  
  wire [31:0] keyboard_dat_o;
  wire keyboard_ack;
  wire keyboard_irq;
  
  keyboard_scanner keyboard_inst (
    .clk(wb_clk_i),
    .rst_n(rst_n),
    .row_in(keyboard_row_in),
    .row_out(),
    .col_in(keyboard_col_in),
    .wb_cyc_i(periph_cyc[2]),
    .wb_stb_i(periph_stb[2]),
    .wb_we_i(wbs_we_i),
    .wb_adr_i(wbs_adr_i),
    .wb_dat_i(wbs_dat_i),
    .wb_dat_o(keyboard_dat_o),
    .wb_ack_o(keyboard_ack),
    .irq(keyboard_irq)
  );
  
  assign periph_dat_o[95:64] = keyboard_dat_o;
  assign periph_ack[2] = keyboard_ack;
  assign periph_err[2] = 1'b0;
  
  wire [31:0] voice_mgr_dat_o;
  wire voice_mgr_ack;
  wire [NUM_VOICES-1:0] voice_gate;
  
  voice_manager #(
    .NUM_VOICES(NUM_VOICES)
  ) voice_mgr_inst (
    .clk(wb_clk_i),
    .rst_n(rst_n),
    .wb_cyc_i(periph_cyc[3]),
    .wb_stb_i(periph_stb[3]),
    .wb_we_i(wbs_we_i),
    .wb_adr_i(wbs_adr_i),
    .wb_dat_i(wbs_dat_i),
    .wb_dat_o(voice_mgr_dat_o),
    .wb_ack_o(voice_mgr_ack),
    .voice_gate(voice_gate)
  );
  
  assign periph_dat_o[127:96] = voice_mgr_dat_o;
  assign periph_ack[3] = voice_mgr_ack;
  assign periph_err[3] = 1'b0;
  
  wire [31:0] synth_dat_o;
  wire synth_ack;
  wire synth_sram_cyc, synth_sram_stb;
  wire [31:0] synth_sram_adr, synth_sram_dat;
  wire synth_sram_ack;
  wire [15:0] synth_voice_out [0:NUM_VOICES-1];
  
  wire sample_clk_en;
  
  wavetable_osc #(
    .NUM_VOICES(NUM_VOICES)
  ) synth_inst (
    .clk(wb_clk_i),
    .rst_n(rst_n),
    .sample_clk_en(sample_clk_en),
    .wb_cyc_i(periph_cyc[4]),
    .wb_stb_i(periph_stb[4]),
    .wb_we_i(wbs_we_i),
    .wb_adr_i(wbs_adr_i),
    .wb_dat_i(wbs_dat_i),
    .wb_dat_o(synth_dat_o),
    .wb_ack_o(synth_ack),
    .sram_cyc_o(synth_sram_cyc),
    .sram_stb_o(synth_sram_stb),
    .sram_adr_o(synth_sram_adr),
    .sram_dat_i(synth_sram_dat),
    .sram_ack_i(synth_sram_ack),
    .voice_out(synth_voice_out)
  );
  
  assign periph_dat_o[159:128] = synth_dat_o;
  assign periph_ack[4] = synth_ack;
  assign periph_err[4] = 1'b0;
  assign sample_clk_en = 1'b1;
  
  wire [31:0] adsr_dat_o;
  wire adsr_ack;
  wire [15:0] adsr_voice_out [0:NUM_VOICES-1];
  
  adsr_envelope #(
    .NUM_VOICES(NUM_VOICES)
  ) adsr_inst (
    .clk(wb_clk_i),
    .rst_n(rst_n),
    .sample_clk_en(sample_clk_en),
    .wb_cyc_i(periph_cyc[5]),
    .wb_stb_i(periph_stb[5]),
    .wb_we_i(wbs_we_i),
    .wb_adr_i(wbs_adr_i),
    .wb_dat_i(wbs_dat_i),
    .wb_dat_o(adsr_dat_o),
    .wb_ack_o(adsr_ack),
    .gate(voice_gate),
    .voice_in(synth_voice_out),
    .voice_out(adsr_voice_out)
  );
  
  assign periph_dat_o[191:160] = adsr_dat_o;
  assign periph_ack[5] = adsr_ack;
  assign periph_err[5] = 1'b0;
  
  wire [31:0] theremin_dat_o;
  wire theremin_ack;
  wire theremin_spi_cyc, theremin_spi_stb, theremin_spi_we;
  wire [31:0] theremin_spi_adr, theremin_spi_dat_o, theremin_spi_dat_i;
  wire theremin_spi_ack;
  wire [15:0] pitch_mod, volume_mod;
  wire theremin_irq;
  
  theremin_ctrl theremin_inst (
    .clk(wb_clk_i),
    .rst_n(rst_n),
    .wb_cyc_i(periph_cyc[6]),
    .wb_stb_i(periph_stb[6]),
    .wb_we_i(wbs_we_i),
    .wb_adr_i(wbs_adr_i),
    .wb_dat_i(wbs_dat_i),
    .wb_dat_o(theremin_dat_o),
    .wb_ack_o(theremin_ack),
    .spi_cyc_o(theremin_spi_cyc),
    .spi_stb_o(theremin_spi_stb),
    .spi_we_o(theremin_spi_we),
    .spi_adr_o(theremin_spi_adr),
    .spi_dat_o(theremin_spi_dat_o),
    .spi_dat_i(theremin_spi_dat_i),
    .spi_ack_i(theremin_spi_ack),
    .pitch_mod(pitch_mod),
    .volume_mod(volume_mod),
    .irq(theremin_irq)
  );
  
  assign periph_dat_o[223:192] = theremin_dat_o;
  assign periph_ack[6] = theremin_ack;
  assign periph_err[6] = 1'b0;
  
  wire [31:0] mixer_dat_o;
  wire mixer_ack;
  wire [15:0] audio_left, audio_right;
  
  audio_mixer #(
    .NUM_VOICES(NUM_VOICES)
  ) mixer_inst (
    .clk(wb_clk_i),
    .rst_n(rst_n),
    .sample_clk_en(sample_clk_en),
    .wb_cyc_i(periph_cyc[7]),
    .wb_stb_i(periph_stb[7]),
    .wb_we_i(wbs_we_i),
    .wb_adr_i(wbs_adr_i),
    .wb_dat_i(wbs_dat_i),
    .wb_dat_o(mixer_dat_o),
    .wb_ack_o(mixer_ack),
    .voice_in(adsr_voice_out),
    .audio_left(audio_left),
    .audio_right(audio_right)
  );
  
  assign periph_dat_o[255:224] = mixer_dat_o;
  assign periph_ack[7] = mixer_ack;
  assign periph_err[7] = 1'b0;
  
  wire [31:0] i2s_dat_o;
  wire i2s_ack;
  wire i2s_irq;
  
  assign i2s_sclk = 1'b0;
  assign i2s_ws = 1'b0;
  assign i2s_sd = 1'b0;
  assign i2s_dat_o = 32'h00000000;
  assign i2s_ack = periph_cyc[8] && periph_stb[8];
  assign i2s_irq = 1'b0;
  
  assign periph_dat_o[287:256] = i2s_dat_o;
  assign periph_ack[8] = i2s_ack;
  assign periph_err[8] = 1'b0;
  
  wire [31:0] pic_dat_o;
  wire pic_ack;
  wire [15:0] irq_lines;
  
  assign irq_lines = {13'h0000, theremin_irq, i2s_irq, keyboard_irq};
  
  WB_PIC pic_inst (
    .clk(wb_clk_i),
    .rst_n(rst_n),
    .irq_lines(irq_lines),
    .irq_out(user_irq[0]),
    .wb_adr_i(wbs_adr_i),
    .wb_dat_i(wbs_dat_i),
    .wb_dat_o(pic_dat_o),
    .wb_sel_i(wbs_sel_i),
    .wb_cyc_i(periph_cyc[9]),
    .wb_stb_i(periph_stb[9]),
    .wb_we_i(wbs_we_i),
    .wb_ack_o(pic_ack)
  );
  
  assign periph_dat_o[319:288] = pic_dat_o;
  assign periph_ack[9] = pic_ack;
  assign periph_err[9] = 1'b0;
  
  assign user_irq[2:1] = 2'b00;
  
  wire [31:0] sram_dat_o;
  wire sram_ack;
  
  assign sram_dat_o = 32'h00000000;
  assign sram_ack = periph_cyc[10] && periph_stb[10];
  assign synth_sram_dat = 32'h00000000;
  assign synth_sram_ack = synth_sram_cyc && synth_sram_stb;
  
  assign periph_dat_o[351:320] = sram_dat_o;
  assign periph_ack[10] = sram_ack;
  assign periph_err[10] = 1'b0;
  
  assign status_led0 = 1'b1;
  assign status_led1 = |voice_gate;
  
  assign spi_sck = 1'b0;
  assign spi_mosi = 1'b0;
  assign spi_cs_n = 1'b1;
  assign theremin_spi_dat_i = 32'h00000000;
  assign theremin_spi_ack = theremin_spi_cyc && theremin_spi_stb;

endmodule

`default_nettype wire
