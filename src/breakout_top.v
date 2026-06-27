// 4096 bricks

module tdp_ram #(
    parameter D=3, 
    parameter A=15
) (
    input  wire clk,
    // Port A
    input  wire [A-1:0] addr_a,
    input  wire we_a,
    input  wire [D-1:0] din_a,
    output reg  [D-1:0] dout_a,
    // Port B
    input  wire [A-1:0] addr_b,
    input  wire we_b,
    input  wire [D-1:0] din_b,
    output reg  [D-1:0] dout_b
);
    reg [D-1:0] mem [0:(1<<A)-1];

    always @(posedge clk) begin
        if (we_a) mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    always @(posedge clk) begin
        if (we_b) mem[addr_b] <= din_b;
        dout_b <= mem[addr_b];
    end
endmodule

module breakout_top(
    input  wire clk_50M,
    input  wire rst_n,
    input  wire [9:0] cpu_paddle_x,
    input  wire click,            
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
    output reg  [1:0] snd_trig    
);

    // legacy support
    assign score_led = 8'd0; 
    assign out_mode  = 2'd0;
    assign level = 4'd7;
    assign lives = 2'd3;

    // VGA interface
    reg clk_25M = 0;
    always @(posedge clk_50M) clk_25M <= ~clk_25M;

    wire [9:0] pixel_x, pixel_y;
    wire video_on;

    vga_controller u_vga (
        .clk_25M(clk_25M),
        .rst_n(rst_n),
        .h_sync(vga_hs),
        .v_sync(vga_vs),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    assign vga_blank_n = video_on; 
    assign vga_sync_n  = 1'b0;     
    assign vga_clk     = clk_25M;

    // V-Sync
    wire frame_tick = (pixel_x == 10'd0) && (pixel_y == 10'd480);
    reg prev_ft_50;
    always @(posedge clk_50M) prev_ft_50 <= frame_tick;
    wire start_phys = frame_tick && !prev_ft_50;

    // parameter
    wire [9:0] wall_thick = 10'd10;

    // mouse
    reg prev_click_50;
    always @(posedge clk_50M or negedge rst_n) begin
        if (!rst_n) prev_click_50 <= 1'b0;
        else prev_click_50 <= click;
    end
    wire click_pulse_50 = click & ~prev_click_50;

    // paddle
    reg [9:0] paddle_x = 10'd280;
    always @(posedge clk_25M) begin
        if (cpu_paddle_x < 10'd8) paddle_x <= 10'd8;
        else if (cpu_paddle_x > 10'd552) paddle_x <= 10'd552;
        else paddle_x <= cpu_paddle_x;
    end

    // Ping pong buffering.
    // If has item, dout != 0.
    wire [14:0] vga_grid_addr = {pixel_y[8:2], pixel_x[9:2]}; 
    wire [2:0]  vga_out_A, vga_out_B;
    
    reg  [14:0] phys_read_addr;
    reg  [14:0] phys_write_addr;
    reg         phys_we;
    reg  [2:0]  phys_write_data;
    
    wire [2:0]  phys_hit_color_A, phys_hit_color_B;
    reg         active_grid; 

    reg force_clear_both; 
    reg [14:0] clr_idx;

    // port A for VGA
    // port B for next state
    tdp_ram #(.D(3), .A(15)) grid_A (
        .clk(clk_50M),
        .addr_a(force_clear_both ? clr_idx : vga_grid_addr), 
        .we_a  (force_clear_both), 
        .din_a (3'd0), 
        .dout_a(vga_out_A),
        .addr_b((active_grid == 1'b0) ? phys_read_addr : phys_write_addr), 
        .we_b  ((active_grid == 1'b0) ? 1'b0 : phys_we), 
        .din_b (phys_write_data), 
        .dout_b(phys_hit_color_A)
    );

    tdp_ram #(.D(3), .A(15)) grid_B (
        .clk(clk_50M),
        .addr_a(force_clear_both ? clr_idx : vga_grid_addr), 
        .we_a  (force_clear_both), 
        .din_a (3'd0), 
        .dout_a(vga_out_B),
        .addr_b((active_grid == 1'b1) ? phys_read_addr : phys_write_addr), 
        .we_b  ((active_grid == 1'b1) ? 1'b0 : phys_we), 
        .din_b (phys_write_data), 
        .dout_b(phys_hit_color_B)
    );

    wire [2:0] phys_hit_color = (active_grid == 1'b0) ? phys_hit_color_A : phys_hit_color_B;
    wire [2:0] grid_pixel = (active_grid == 1'b0) ? vga_out_A : vga_out_B;

    // collision math
    // brick-brick
    reg [19:0] brick_mem [0:4095]; 
    reg [19:0] cur_brick;

    wire [2:0] cb_col = cur_brick[19:17];
    wire       cb_dy  = cur_brick[16];
    wire       cb_dx  = cur_brick[15];
    wire [6:0] cb_y   = cur_brick[14:8];
    wire [7:0] cb_x   = cur_brick[7:0];

    wire [7:0] cb_nx = cb_dx ? (cb_x - 8'd1) : (cb_x + 8'd1);
    wire [6:0] cb_ny = cb_dy ? (cb_y - 7'd1) : (cb_y + 7'd1);

    wire hit_brick  = (phys_hit_color != 3'd0);

    // brick-wall
    wire wall_x     = (cb_nx == 8'd0) || (cb_nx >= 8'd159);
    wire wall_y     = (cb_ny == 7'd0) || (cb_ny >= 7'd119);
    
    // brick-paddle
    wire [7:0] pad_grid_x = paddle_x[9:2]; 
    wire hit_paddle = (cb_ny >= 7'd110 && cb_ny <= 7'd112) && (cb_nx >= pad_grid_x) && (cb_nx <= pad_grid_x + 8'd20);
    
    wire hit_any    = hit_brick || hit_paddle;

    wire       new_dx = (wall_x || hit_any) ? ~cb_dx : cb_dx;
    wire       new_dy = (wall_y || hit_any) ? ~cb_dy : cb_dy;
    wire [7:0] new_x  = (wall_x || hit_any) ? cb_x : cb_nx;
    wire [6:0] new_y  = (wall_y || hit_any) ? cb_y : cb_ny;

    // brick-ball
    reg [9:0] ball_x;
    reg [9:0] ball_y;
    reg       ball_dir_x; 
    reg       ball_dir_y; 
    reg       ball_active;
    reg       ball_dead;
    reg       ball_hit_brick_latched; 

    wire hit_player_ball = (cb_x >= ball_x[9:2] - 8'd2 && cb_x <= ball_x[9:2] + 8'd2) && 
                           (cb_y >= ball_y[8:2] - 7'd2 && cb_y <= ball_y[8:2] + 7'd2);

    // State machine.

    localparam P_CLEAR_ALL = 3'd0; 
    localparam P_INIT      = 3'd1; 
    localparam P_IDLE      = 3'd2; 
    localparam P_CLEAR_BG  = 3'd3; 
    localparam P_UPD_0     = 3'd4; 
    localparam P_UPD_1     = 3'd5; 
    localparam P_UPD_2     = 3'd6; 
    localparam P_SWAP      = 3'd7; 

    reg [2:0]  p_state;
    reg [11:0] upd_idx;
    reg [1:0]  frame_div; 

    always @(posedge clk_50M or negedge rst_n) begin
        if (!rst_n) begin // reset
            p_state <= P_CLEAR_ALL;
            clr_idx <= 15'd0;
            upd_idx <= 12'd0;
            force_clear_both <= 1'b1;
            active_grid <= 1'b0;
            phys_we <= 1'b0;
            frame_div <= 2'd0;
            cur_brick <= 20'd0;
            snd_trig <= 2'd0;
            
            ball_x <= 10'd320;
            ball_y <= 10'd400;
            ball_dir_x <= 1'b0;
            ball_dir_y <= 1'b1;
            ball_active <= 1'b0;
            ball_hit_brick_latched <= 1'b0;
            ball_dead <= 1'b1;
        end else begin
            
            if (click_pulse_50 && ball_dead) begin // restart
                p_state <= P_CLEAR_ALL;
                clr_idx <= 15'd0;
                upd_idx <= 12'd0;
                force_clear_both <= 1'b1;
                snd_trig <= 2'd0;
                
                ball_x <= 10'd320;
                ball_y <= 10'd400;
                ball_dir_x <= 1'b0;
                ball_dir_y <= 1'b1;
                ball_active <= 1'b0;
                ball_hit_brick_latched <= 1'b0;
                ball_dead <= 1'b0;
            end else begin // in game

                // ball
                if (start_phys) begin
                    if (!ball_active && !ball_dead) begin // stick to paddle
                        ball_x <= paddle_x + 10'd36;
                        ball_y <= 10'd432;
                        if (click) begin 
                            ball_active <= 1'b1;
                            ball_dir_y <= 1'b1;
                        end
                    end else if (ball_active) begin // moving
                        if (ball_hit_brick_latched) begin // stuck
                            ball_dir_y <= ~ball_dir_y; 
                        end

                        if (ball_dir_x == 1'b0) begin // left right
                            if (ball_x + 10'd8 >= 10'd636 - wall_thick) ball_dir_x <= 1'b1;
                            else ball_x <= ball_x + 10'd3; 
                        end else begin
                            if (ball_x <= wall_thick + 10'd4) ball_dir_x <= 1'b0;
                            else ball_x <= ball_x - 10'd3;
                        end

                        if (ball_dir_y == 1'b0) begin // up down
                            if (ball_y + 10'd8 >= 10'd440 && ball_y + 10'd8 <= 10'd446 &&
                                ball_x + 10'd8 >= paddle_x && ball_x <= paddle_x + 10'd80) begin
                                ball_dir_y <= 1'b1;
                            end else if (ball_y + 10'd8 >= 10'd480) begin
                                ball_active <= 1'b0; 
                                ball_dead <= 1'b1;
                            end else begin
                                ball_y <= ball_y + 10'd3;
                            end
                        end else begin
                            if (ball_y <= wall_thick + 10'd4) begin
                                ball_dir_y <= 1'b0;
                            end else begin
                                ball_y <= ball_y - 10'd3;
                            end
                        end
                    end
                end

                // brick
                case (p_state)
                    P_CLEAR_ALL: begin
                        force_clear_both <= 1'b1;
                        if (clr_idx == 15'd32767) begin
                            p_state <= P_INIT;
                            upd_idx <= 12'd0;
                        end else begin
                            clr_idx <= clr_idx + 15'd1;
                        end
                    end
                    P_INIT: begin
                        force_clear_both <= 1'b0;
                        phys_we <= 1'b0;
                        brick_mem[upd_idx] <= {
                            (upd_idx[6:4] == 3'd0 ? 3'd1 : upd_idx[6:4]),
                            upd_idx[0],
                            upd_idx[1],
                            7'd10 + upd_idx[11:7],
                            8'd16 + upd_idx[6:0]
                        };
                        if (upd_idx == 12'd4095) begin
                            p_state <= P_IDLE;
                            upd_idx <= 12'd0;
                        end else begin
                            upd_idx <= upd_idx + 12'd1;
                        end
                    end
                    P_IDLE: begin
                        phys_we <= 1'b0;
                        snd_trig <= 2'd0;
                        if (start_phys) begin
                            frame_div <= frame_div + 2'd1;
                            if (frame_div == 2'd1) begin
                                p_state <= P_CLEAR_BG;
                                clr_idx <= 15'd0;
                            end
                        end
                    end
                    P_CLEAR_BG: begin
                        phys_write_addr <= clr_idx;
                        phys_we <= 1'b1;
                        phys_write_data <= 3'd0;
                        ball_hit_brick_latched <= 1'b0; 
                        if (clr_idx == 15'd32767) begin
                            p_state <= P_UPD_0;
                            upd_idx <= 12'd0;
                            phys_we <= 1'b0;
                        end else begin
                            clr_idx <= clr_idx + 15'd1;
                        end
                    end
                    P_UPD_0: begin
                        phys_we <= 1'b0;
                        cur_brick <= brick_mem[upd_idx];
                        p_state <= P_UPD_1;
                    end
                    P_UPD_1: begin
                        phys_read_addr <= {cb_ny, cb_nx};
                        p_state <= P_UPD_2;
                    end
                    P_UPD_2: begin
                        if (hit_paddle) snd_trig <= 2'd1;
                        else if (hit_brick || (cb_col != 3'd0 && hit_player_ball)) snd_trig <= 2'd2;

                        if (cb_col != 3'd0 && hit_player_ball) begin
                            ball_hit_brick_latched <= 1'b1; 
                            brick_mem[upd_idx]     <= 20'd0; 

                            phys_write_addr <= {cb_y, cb_x};
                            phys_we <= 1'b1;
                            phys_write_data <= 3'd0; 
                        end else begin
                            brick_mem[upd_idx] <= {cb_col, new_dy, new_dx, new_y, new_x};
                            
                            phys_write_addr <= {new_y, new_x};
                            phys_we <= 1'b1;
                            phys_write_data <= cb_col;
                        end

                        if (upd_idx == 12'd4095) begin
                            p_state <= P_SWAP;
                        end else begin
                            upd_idx <= upd_idx + 12'd1;
                            p_state <= P_UPD_0;
                        end
                    end
                    P_SWAP: begin
                        phys_we <= 1'b0;
                        active_grid <= ~active_grid; 
                        p_state <= P_IDLE;
                    end
                endcase
            end
        end
    end

    // draw
    wire draw_border = (pixel_x < 10'd4) || (pixel_x >= 10'd636) || (pixel_y < 10'd4);
    wire draw_paddle = (pixel_x >= paddle_x) && (pixel_x < paddle_x + 10'd80) && (pixel_y >= 10'd440) && (pixel_y < 10'd450);
    wire draw_ball   = (pixel_x >= ball_x) && (pixel_x < ball_x + 10'd8) && (pixel_y >= ball_y) && (pixel_y < ball_y + 10'd8);

    reg [7:0] rout, gout, bout;
    always @(*) begin
        if (!video_on) begin
            rout = 8'h00; gout = 8'h00; bout = 8'h00;
        end else if (draw_border) begin
            rout = 8'h55; gout = 8'h55; bout = 8'h55;
        end else if (draw_ball) begin
            rout = 8'hFF; gout = 8'hFF; bout = 8'hFF; 
        end else if (draw_paddle) begin
            rout = 8'hFF; gout = 8'hFF; bout = 8'hFF; 
        end else if (grid_pixel != 3'd0) begin
            case (grid_pixel)
                3'd1: begin rout = 8'hFF; gout = 8'h00; bout = 8'h00; end 
                3'd2: begin rout = 8'h00; gout = 8'hFF; bout = 8'h00; end 
                3'd3: begin rout = 8'h00; gout = 8'h00; bout = 8'hFF; end 
                3'd4: begin rout = 8'hFF; gout = 8'hFF; bout = 8'h00; end 
                3'd5: begin rout = 8'hFF; gout = 8'h00; bout = 8'hFF; end 
                3'd6: begin rout = 8'h00; gout = 8'hFF; bout = 8'hFF; end 
                3'd7: begin rout = 8'hFF; gout = 8'h80; bout = 8'h00; end 
                default: begin rout = 8'hFF; gout = 8'h00; bout = 8'hFF; end
            endcase
        end else begin
            rout = 8'h00; gout = 8'h00; bout = 8'h00; 
        end
    end

    assign vga_r = rout;
    assign vga_g = gout;
    assign vga_b = bout;

endmodule