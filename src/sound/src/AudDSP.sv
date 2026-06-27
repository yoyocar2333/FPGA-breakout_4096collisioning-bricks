module AudDSP (
    input  logic        i_rst_n,
    input  logic        i_clk,       // 連接 i_AUD_BCLK
    input  logic        i_start,     // 播放中
    output logic        o_stop,
    input  logic        i_daclrck,   // 32kHz
    input  logic [15:0] i_sram_data, // 來自 ROM 的資料
    output logic [13:0] o_sram_addr
);
    // LRCK 邊緣偵測 (用於同步取樣)
    logic lrc_delay;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) lrc_delay <= 1'b0;
        else          lrc_delay <= i_daclrck;
    end
    wire lrc_fall = (lrc_delay == 1'b1 && i_daclrck == 1'b0);

    logic [13:0] play_addr_r;
    logic [14:0] play_addr_inc;
    assign play_addr_inc = play_addr_r + 14'b1;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            play_addr_r <= 14'd0;
        end else if (i_start && lrc_fall) begin
            play_addr_r <= play_addr_inc[13:0];
        end
    end

    assign o_stop = play_addr_inc[14] && lrc_fall;
    assign o_sram_addr = play_addr_r;
endmodule