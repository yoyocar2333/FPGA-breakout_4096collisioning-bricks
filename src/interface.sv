module game_interface (
    input  wire clk_50M,
    input  wire rst_n,
    input  wire [9:0] cpu_paddle_x,
    input  wire click,
    input  wire switch,

    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hs,
    output wire vga_vs,
    output wire vga_blank_n,
    output wire vga_sync_n,
    output wire vga_clk,
    output wire [7:0] score_led,
    output wire [3:0] level,
    output wire [1:0] lives,
    output wire [1:0] out_mode,
    output wire [1:0] snd_trig
);

    // Old game outputs
    wire [7:0] old_vga_r;
    wire [7:0] old_vga_g;
    wire [7:0] old_vga_b;
    wire       old_vga_hs;
    wire       old_vga_vs;
    wire       old_vga_blank_n;
    wire       old_vga_sync_n;
    wire       old_vga_clk;
    wire [7:0] old_score_led;
    wire [3:0] old_level;
    wire [1:0] old_lives;
    wire [1:0] old_out_mode;
    wire [1:0] old_snd_trig;

    // New game outputs
    wire [7:0] new_vga_r;
    wire [7:0] new_vga_g;
    wire [7:0] new_vga_b;
    wire       new_vga_hs;
    wire       new_vga_vs;
    wire       new_vga_blank_n;
    wire       new_vga_sync_n;
    wire       new_vga_clk;
    wire [7:0] new_score_led;
    wire [3:0] new_level;
    wire [1:0] new_lives;
    wire [1:0] new_out_mode;
    wire [1:0] new_snd_trig;

    breakout_top_old u_breakout_game_old (
        .clk_50M      (clk_50M),
        .rst_n        (rst_n),
        .cpu_paddle_x (cpu_paddle_x),
        .click        (click & ~switch),

        .vga_r        (old_vga_r),
        .vga_g        (old_vga_g),
        .vga_b        (old_vga_b),
        .vga_hs       (old_vga_hs),
        .vga_vs       (old_vga_vs),
        .vga_blank_n  (old_vga_blank_n),
        .vga_sync_n   (old_vga_sync_n),
        .vga_clk      (old_vga_clk),
        .score_led    (old_score_led),
        .level        (old_level),
        .lives        (old_lives),
        .out_mode     (old_out_mode),
        .snd_trig     (old_snd_trig)
    );

    breakout_top u_breakout_game_new (
        .clk_50M      (clk_50M),
        .rst_n        (rst_n),
        .cpu_paddle_x (cpu_paddle_x),
        .click        (click & switch),

        .vga_r        (new_vga_r),
        .vga_g        (new_vga_g),
        .vga_b        (new_vga_b),
        .vga_hs       (new_vga_hs),
        .vga_vs       (new_vga_vs),
        .vga_blank_n  (new_vga_blank_n),
        .vga_sync_n   (new_vga_sync_n),
        .vga_clk      (new_vga_clk),
        .score_led    (new_score_led),
        .level        (new_level),
        .lives        (new_lives),
        .out_mode     (new_out_mode),
        .snd_trig     (new_snd_trig)
    );

    // switch = 0 -> old game
    // switch = 1 -> new game
    assign vga_r       = switch ? new_vga_r       : old_vga_r;
    assign vga_g       = switch ? new_vga_g       : old_vga_g;
    assign vga_b       = switch ? new_vga_b       : old_vga_b;
    assign vga_hs      = switch ? new_vga_hs      : old_vga_hs;
    assign vga_vs      = switch ? new_vga_vs      : old_vga_vs;
    assign vga_blank_n = switch ? new_vga_blank_n : old_vga_blank_n;
    assign vga_sync_n  = switch ? new_vga_sync_n  : old_vga_sync_n;
    assign vga_clk     = switch ? new_vga_clk     : old_vga_clk;
    assign score_led   = switch ? new_score_led   : old_score_led;
    assign level       = switch ? new_level       : old_level;
    assign lives       = switch ? new_lives       : old_lives;
    assign out_mode    = switch ? new_out_mode    : old_out_mode;
    assign snd_trig    = switch ? new_snd_trig    : old_snd_trig;

endmodule