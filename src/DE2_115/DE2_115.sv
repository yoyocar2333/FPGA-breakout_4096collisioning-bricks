module DE2_115 (
    input CLOCK_50,
    input CLOCK2_50,
    input CLOCK3_50,
    input ENETCLK_25,
    input SMA_CLKIN,
    output SMA_CLKOUT,
    output [8:0] LEDG,
    output [17:0] LEDR,
    input [3:0] KEY,
    input [17:0] SW,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5,
    output [6:0] HEX6,
    output [6:0] HEX7,
    output LCD_BLON,
    inout [7:0] LCD_DATA,
    output LCD_EN,
    output LCD_ON,
    output LCD_RS,
    output LCD_RW,
    output UART_CTS,
    input UART_RTS,
    input UART_RXD,
    output UART_TXD,
    inout PS2_CLK,
    inout PS2_DAT,
    inout PS2_CLK2,
    inout PS2_DAT2,
    output SD_CLK,
    inout SD_CMD,
    inout [3:0] SD_DAT,
    input SD_WP_N,
    output [7:0] VGA_B,
    output VGA_BLANK_N,
    output VGA_CLK,
    output [7:0] VGA_G,
    output VGA_HS,
    output [7:0] VGA_R,
    output VGA_SYNC_N,
    output VGA_VS,
    input AUD_ADCDAT,
    inout AUD_ADCLRCK,
    inout AUD_BCLK,
    output AUD_DACDAT,
    inout AUD_DACLRCK,
    output AUD_XCK,
    output EEP_I2C_SCLK,
    inout EEP_I2C_SDAT,
    output I2C_SCLK,
    inout I2C_SDAT,
    output ENET0_GTX_CLK,
    input ENET0_INT_N,
    output ENET0_MDC,
    input ENET0_MDIO,
    output ENET0_RST_N,
    input ENET0_RX_CLK,
    input ENET0_RX_COL,
    input ENET0_RX_CRS,
    input [3:0] ENET0_RX_DATA,
    input ENET0_RX_DV,
    input ENET0_RX_ER,
    input ENET0_TX_CLK,
    output [3:0] ENET0_TX_DATA,
    output ENET0_TX_EN,
    output ENET0_TX_ER,
    input ENET0_LINK100,
    output ENET1_GTX_CLK,
    input ENET1_INT_N,
    output ENET1_MDC,
    input ENET1_MDIO,
    output ENET1_RST_N,
    input ENET1_RX_CLK,
    input ENET1_RX_COL,
    input ENET1_RX_CRS,
    input [3:0] ENET1_RX_DATA,
    input ENET1_RX_DV,
    input ENET1_RX_ER,
    input ENET1_TX_CLK,
    output [3:0] ENET1_TX_DATA,
    output ENET1_TX_EN,
    output ENET1_TX_ER,
    input ENET1_LINK100,
    input TD_CLK27,
    input [7:0] TD_DATA,
    input TD_HS,
    output TD_RESET_N,
    input TD_VS,
    inout [15:0] OTG_DATA,
    output [1:0] OTG_ADDR,
    output OTG_CS_N,
    output OTG_WR_N,
    output OTG_RD_N,
    input OTG_INT,
    output OTG_RST_N,
    input IRDA_RXD,
    output [12:0] DRAM_ADDR,
    output [1:0] DRAM_BA,
    output DRAM_CAS_N,
    output DRAM_CKE,
    output DRAM_CLK,
    output DRAM_CS_N,
    inout [31:0] DRAM_DQ,
    output [3:0] DRAM_DQM,
    output DRAM_RAS_N,
    output DRAM_WE_N,
    output [19:0] SRAM_ADDR,
    output SRAM_CE_N,
    inout [15:0] SRAM_DQ,
    output SRAM_LB_N,
    output SRAM_OE_N,
    output SRAM_UB_N,
    output SRAM_WE_N,
    output [22:0] FL_ADDR,
    output FL_CE_N,
    inout [7:0] FL_DQ,
    output FL_OE_N,
    output FL_RST_N,
    input FL_RY,
    output FL_WE_N,
    output FL_WP_N,
    inout [35:0] GPIO,
    input HSMC_CLKIN_P1,
    input HSMC_CLKIN_P2,
    input HSMC_CLKIN0,
    output HSMC_CLKOUT_P1,
    output HSMC_CLKOUT_P2,
    output HSMC_CLKOUT0,
    inout [3:0] HSMC_D,
    input [16:0] HSMC_RX_D_P,
    output [16:0] HSMC_TX_D_P,
    inout [6:0] EX_IO
);

    // ==============================================================
    // 1. 產生音訊晶片所需的時脈 (100kHz for I2C, 12.5MHz for AUD_XCK)
    // ==============================================================
    reg [8:0] cnt_100k;
    reg clk_100k = 0;
    always @(posedge CLOCK_50) begin
        if (cnt_100k >= 9'd249) begin
            cnt_100k <= 0;
            clk_100k <= ~clk_100k;
        end else begin
            cnt_100k <= cnt_100k + 1'b1;
        end
    end

    reg [1:0] cnt_12m;
    reg clk_12m = 0;
    always @(posedge CLOCK_50) begin
        cnt_12m <= cnt_12m + 1'b1;
        if (cnt_12m == 2'd0 || cnt_12m == 2'd2) clk_12m <= ~clk_12m;
    end
    
    // 【關鍵修復】：給予音效晶片主時脈，否則完全不會發聲！
    assign AUD_XCK = clk_12m; 


    // ==============================================================
    // 2. 滑鼠與打磚塊遊戲核心實體化
    // ==============================================================
    wire [9:0] mouse_x_signal;
    wire       click_signal;
    wire [7:0] current_score; 
    wire [3:0] current_level;
    wire [1:0] current_lives;
    wire [1:0] current_mode;
    wire [1:0] collision_sound_trigger; // 這條線用來接通兩兄弟！

    assign LEDR[17] = PS2_CLK;
    assign LEDR[16] = PS2_DAT;
    assign LEDR[0] = (current_lives >= 1);
    assign LEDR[1] = (current_lives >= 2);
    assign LEDR[2] = (current_lives >= 3);
    assign LEDR[15:3] = 13'b0; 

    ps2_mouse u_mouse_decoder (
        .clk              (CLOCK_50),       
        .rst_n            (KEY[0]),         
        .ps2_clk          (PS2_CLK),        
        .ps2_dat          (PS2_DAT),        
        .mouse_x          (mouse_x_signal),
        .mouse_left_click (click_signal) 
    );

    game_interface u_breakout_game (
        .clk_50M      (CLOCK_50),      
        .rst_n        (KEY[0]),        
        .cpu_paddle_x (mouse_x_signal), 
        .click        (click_signal),  
        .switch       (SW[11]),
        .vga_r        (VGA_R),         
        .vga_g        (VGA_G),
        .vga_b        (VGA_B),
        .vga_hs       (VGA_HS),
        .vga_vs       (VGA_VS),
        .vga_blank_n  (VGA_BLANK_N),
        .vga_sync_n   (VGA_SYNC_N),
        .vga_clk      (VGA_CLK),
        .score_led    (current_score),
        .level        (current_level),
        .lives        (current_lives),
        .out_mode     (current_mode),
        .snd_trig     (collision_sound_trigger) // 【對接點 A】遊戲核心發出聲音請求
    );


    // ==============================================================
    // 3. 音效核心實體化 (直接引用你的 audio_Top)
    // ==============================================================
    audio_Top u_audio_system (
        .i_rst_n       (KEY[0]),
        .i_clk         (CLOCK_50),
        .i_play        (collision_sound_trigger), // 【對接點 B】音效核心接收聲音請求！
        .o_play_busy   (), // 留空即可
        
        // 給予內部產生的時脈
        .i_clk_100k    (clk_100k), 
        
        // 實體音效腳位
        .o_I2C_SCLK    (I2C_SCLK),
        .io_I2C_SDAT   (I2C_SDAT),
        .i_AUD_DACLRCK (AUD_DACLRCK),
        .i_AUD_BCLK    (AUD_BCLK),
        .o_AUD_DACDAT  (AUD_DACDAT)
    );


    // ==============================================================
    // 4. 計分板七段顯示器解碼邏輯
    // ==============================================================
    assign LEDG[7:0] = current_score;

    wire [3:0] score_ones = current_score % 10;
    wire [3:0] score_tens = (current_score / 10) % 10;
    wire [3:0] score_huns = current_score / 100;
    wire [6:0] dec_score_o, dec_score_t, dec_score_h, dec_level;

    hex_decoder h0 (.bin_in(score_ones), .hex_out(dec_score_o));
    hex_decoder h1 (.bin_in(score_tens), .hex_out(dec_score_t));
    hex_decoder h2 (.bin_in(score_huns), .hex_out(dec_score_h));
    hex_decoder h_lvl (.bin_in(current_level), .hex_out(dec_level));

    reg [6:0] out_hex7, out_hex6, out_hex5, out_hex4, out_hex3, out_hex2, out_hex1, out_hex0;

    always @(*) begin
        out_hex7 = 7'b1111111; out_hex6 = 7'b1111111; out_hex5 = 7'b1111111; out_hex4 = 7'b1111111;
        out_hex3 = 7'b1111111; out_hex2 = 7'b1111111; out_hex1 = 7'b1111111; out_hex0 = 7'b1111111;

        if (current_mode == 2'd0) begin
            out_hex7 = 7'b0010010; 
            out_hex6 = 7'b0000110; 
            out_hex5 = 7'b1000111; 
            out_hex4 = 7'b1000110; 
        end 
        else if (current_mode == 2'd1) begin
            out_hex7 = 7'b1000111; 
            out_hex6 = 7'b1000001; 
            out_hex5 = 7'b0111111; 
            out_hex4 = dec_level;  
            out_hex2 = dec_score_h; 
            out_hex1 = dec_score_t; 
            out_hex0 = dec_score_o; 
        end 
        else if (current_mode == 2'd2) begin
            out_hex7 = 7'b1000000; 
            out_hex6 = 7'b1000001; 
            out_hex5 = 7'b0000110; 
            out_hex4 = 7'b0101111; 
            out_hex2 = dec_score_h; 
            out_hex1 = dec_score_t; 
            out_hex0 = dec_score_o; 
        end
    end

    assign HEX7 = out_hex7;
    assign HEX6 = out_hex6;
    assign HEX5 = out_hex5;
    assign HEX4 = out_hex4;
    assign HEX3 = out_hex3;
    assign HEX2 = out_hex2;
    assign HEX1 = out_hex1;
    assign HEX0 = out_hex0;

endmodule

// 七段顯示器解碼器
module hex_decoder(
    input  [3:0] bin_in,
    output reg [6:0] hex_out
);
    always @(*) begin
        case(bin_in)
            4'h0: hex_out = 7'b1000000; 
            4'h1: hex_out = 7'b1111001; 
            4'h2: hex_out = 7'b0100100; 
            4'h3: hex_out = 7'b0110000; 
            4'h4: hex_out = 7'b0011001; 
            4'h5: hex_out = 7'b0010010; 
            4'h6: hex_out = 7'b0000010; 
            4'h7: hex_out = 7'b1111000; 
            4'h8: hex_out = 7'b0000000; 
            4'h9: hex_out = 7'b0010000; 
            default: hex_out = 7'b1111111; 
        endcase
    end
endmodule