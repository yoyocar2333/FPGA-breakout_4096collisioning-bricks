module vga_controller(
    input  wire clk_25M,      // 來自 PLL 的 25MHz
    input  wire rst_n,        // 系統重置 (Active Low)
    output wire h_sync,       // 水平同步訊號
    output wire v_sync,       // 垂直同步訊號
    output wire video_on,     // 目前是否在可視範圍 (Blanking 區間外)
    output wire [9:0] pixel_x, // 目前掃描的 X 座標 (0~799)
    output wire [9:0] pixel_y  // 目前掃描的 Y 座標 (0~524)
);

    // VGA 640x480 @ 60Hz 時序參數
    localparam HD = 640; // 水平顯示區域
    localparam HF = 16;  // 水平前緣 (Front Porch)
    localparam HB = 48;  // 水平後緣 (Back Porch)
    localparam HR = 96;  // 水平同步脈衝 (Retrace)
    localparam HT = HD + HF + HB + HR; // 總寬 800

    localparam VD = 480; // 垂直顯示區域
    localparam VF = 10;  // 垂直前緣
    localparam VB = 33;  // 垂直後緣
    localparam VR = 2;   // 垂直同步脈衝
    localparam VT = VD + VF + VB + VR; // 總高 525

    reg [9:0] h_count;
    reg [9:0] v_count;

    // 水平與垂直計數器
    always @(posedge clk_25M or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == HT - 1) begin
                h_count <= 0;
                if (v_count == VT - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // 產生同步訊號 (VGA 協定中，h_sync 與 v_sync 在這解析度通常是 Active Low)
    assign h_sync = (h_count >= (HD + HF) && h_count < (HD + HF + HR)) ? 1'b0 : 1'b1;
    assign v_sync = (v_count >= (VD + VF) && v_count < (VD + VF + VR)) ? 1'b0 : 1'b1;
    
    // 輸出目前座標與顯示狀態
    assign video_on = (h_count < HD) && (v_count < VD);
    assign pixel_x  = h_count;
    assign pixel_y  = v_count;

endmodule

// ----------------------------------------------------------------------------
// 模組 2: VGA 訊號產生器
// ----------------------------------------------------------------------------
// module vga_controller (
//     input  wire clk_25M,
//     input  wire rst_n,
//     output wire h_sync,
//     output wire v_sync,
//     output wire video_on,
//     output wire [9:0] pixel_x,
//     output wire [9:0] pixel_y
// );
//     reg [9:0] h_count;
//     reg [9:0] v_count;

//     always @(posedge clk_25M or negedge rst_n) begin
//         if (!rst_n) begin
//             h_count <= 10'd0;
//             v_count <= 10'd0;
//         end else begin
//             if (h_count == 10'd799) begin
//                 h_count <= 10'd0;
//                 if (v_count == 10'd524) v_count <= 10'd0;
//                 else v_count <= v_count + 10'd1;
//             end else begin
//                 h_count <= h_count + 10'd1;
//             end
//         end
//     end

//     assign h_sync = (h_count < 10'd96) ? 1'b0 : 1'b1;
//     assign v_sync = (v_count < 10'd2) ? 1'b0 : 1'b1;
//     assign video_on = (h_count >= 10'd144 && h_count < 10'd784) && 
//                       (v_count >= 10'd35  && v_count < 10'd515);
    
//     assign pixel_x = video_on ? (h_count - 10'd144) : 10'd0;
//     assign pixel_y = video_on ? (v_count - 10'd35) : 10'd0;
// endmodule
