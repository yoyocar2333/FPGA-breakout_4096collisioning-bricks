module DE2_115 (
    input         CLOCK_50,
    // input         CLOCK2_50,
    // input         CLOCK3_50,
    // input         ENETCLK_25,
    // input         SMA_CLKIN,
    // output        SMA_CLKOUT,
    // output [8:0]  LEDG,
    // output [17:0] LEDR,
    input  [3:0]  KEY,
    input  [17:0] SW,
    // output [6:0]  HEX0,
    // output [6:0]  HEX1,
    // output [6:0]  HEX2,
    // output [6:0]  HEX3,
    // output [6:0]  HEX4,
    // output [6:0]  HEX5,
    // output [6:0]  HEX6,
    // output [6:0]  HEX7,
    // output        LCD_BLON,
    // inout  [7:0]  LCD_DATA,
    // output        LCD_EN,
    // output        LCD_ON,
    // output        LCD_RS,
    // output        LCD_RW,
    // output        UART_CTS,
    // input         UART_RTS,
    // input         UART_RXD,
    // output        UART_TXD,
    // inout         PS2_CLK,
    // inout         PS2_DAT,
    // inout         PS2_CLK2,
    // inout         PS2_DAT2,
    // output        SD_CLK,
    // inout         SD_CMD,
    // inout  [3:0]  SD_DAT,
    // input         SD_WP_N,
    // output [7:0]  VGA_B,
    // output        VGA_BLANK_N,
    // output        VGA_CLK,
    // output [7:0]  VGA_G,
    // output        VGA_HS,
    // output [7:0]  VGA_R,
    // output        VGA_SYNC_N,
    // output        VGA_VS,
    output [19:0] SRAM_ADDR,
    output [15:0] SRAM_DQ,
    output        SRAM_WE_N,
    output        SRAM_CE_N,
    output        SRAM_OE_N,
    output        SRAM_LB_N,
    output        SRAM_UB_N,
    // input         AUD_ADCDAT,
    // inout         AUD_ADCLRCK,
    inout         AUD_BCLK,
    inout         AUD_DACLRCK,
    output        AUD_DACDAT,
    output        I2C_SCLK,
    inout         I2C_SDAT
);

    // 內部連接訊號
    wire [15:0] q0, q1, q2;
    wire [19:0] rom_addr;

    // 實例化 ROMs

    // 實例化 Top 控制核心
    Top top0 (
        .i_rst_n        (KEY[0]),
        .i_clk          (CLOCK_50),
        .i_play         (),
        // .o_SRAM_ADDR    (SRAM_ADDR),
        // .i_ROM_data_0   (q0),
        // .i_ROM_data_1   (q1),
        // .i_ROM_data_2   (q2),
        .i_clk_100k     (clk_100k),
        .o_I2C_SCLK     (I2C_SCLK),
        .io_I2C_SDAT    (I2C_SDAT),
        .i_AUD_DACLRCK  (AUD_DACLRCK),
        .i_AUD_BCLK     (AUD_BCLK),
        .o_AUD_DACDAT   (AUD_DACDAT)
    );

    // 關閉所有未使用的腳位 (防止浮接雜訊導致編譯錯誤)
    assign SRAM_DQ    = 16'bz;
    assign SRAM_WE_N  = 1'b1;
    assign SRAM_CE_N  = 1'b1;
    assign SRAM_OE_N  = 1'b1;
    assign SRAM_LB_N  = 1'b1;
    assign SRAM_UB_N  = 1'b1;

endmodule