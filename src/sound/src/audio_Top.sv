module audio_Top (
    input  i_rst_n,
    input  i_clk,
    input [1:0] i_play, // 00, do nothing; 01, play audio 1; 10, play audio 2; 11, play audio 3
    output o_play_busy,
    
    // SRAM 位址介面
    // output [19:0] o_SRAM_ADDR,
    // input  [15:0] i_ROM_data_0,
    // input  [15:0] i_ROM_data_1,
    // input  [15:0] i_ROM_data_2,
    
    // Audio 介面
    input  i_clk_100k,
    output o_I2C_SCLK,
    inout  io_I2C_SDAT,
    inout  i_AUD_DACLRCK,
    inout  i_AUD_BCLK,
    output o_AUD_DACDAT
);
    localparam S_IDLE = 0, S_PLA1 = 1, S_PLA2 = 2, S_PLA3 = 3;
    logic [1:0] state_w, state_r;

    logic [15:0] dac_data;
    logic [13:0] play_addr;
    wire  play_en = (state_r != S_IDLE);
    logic end_of_audio;
    assign o_play_busy = play_en;

    logic [15:0] i_ROM_data_0, i_ROM_data_1, i_ROM_data_2;

    // ROM 選擇多工器
    always_comb begin
        case(state_r)
            S_PLA1: dac_data = i_ROM_data_0;
            S_PLA2: dac_data = i_ROM_data_1;
            S_PLA3: dac_data = i_ROM_data_2;
            default: dac_data = i_ROM_data_0;
        endcase
    end

    BONK_rom     ROM0 (.address(play_addr), .clock(i_AUD_BCLK), .q(i_ROM_data_0));
    GrandmaBomb  ROM1 (.address(play_addr), .clock(i_AUD_BCLK), .q(i_ROM_data_1));
    woodFishBonk ROM2 (.address(play_addr), .clock(i_AUD_BCLK), .q(i_ROM_data_2));
    
    logic i2c_oen, i2c_sdat;
    logic i2c_finished;
    logic i2c_start_r, i2c_start_w;

    assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

    assign i2c_start_w = 1'b0;
    always_ff @(posedge i_clk_100k or negedge i_rst_n) begin
        if (~i_rst_n) begin
            i2c_start_r <= 1'b1;
        end else begin
            i2c_start_r <= i2c_start_w;
        end
    end

    I2cInitializer init0(
        .i_rst_n(i_rst_n),
        .i_clk(i_clk_100k),
        .i_start(1'b1),
        .o_finished(i2c_finished),
        .o_sclk(o_I2C_SCLK),
        .o_sdat(i2c_sdat),
        .o_oen(i2c_oen) 
    );

    AudDSP u_dsp (
        .i_rst_n(i_rst_n),
        .i_clk(i_AUD_BCLK),
        .i_start(play_en),
        .o_stop(end_of_audio),
        .i_daclrck(i_AUD_DACLRCK),
        .i_sram_data(dac_data),
        .o_sram_addr(play_addr)
    );

    AudPlayer u_player (
        .i_rst_n(i_rst_n),
        .i_bclk(i_AUD_BCLK),
        .i_daclrck(i_AUD_DACLRCK),
        .i_en(play_en),
        .i_dac_data(dac_data),
        .o_aud_dacdat(o_AUD_DACDAT)
    );

    logic [1:0] deb_play;
    audio_debouncer DEB (
        .clk(i_AUD_BCLK),
        .rst_n(i_rst_n),
        .async_in(i_play),
        .debounced_out(deb_play)
    );

    // 狀態機控制
    always_comb begin
        state_w = state_r;
        case(state_r)
            S_IDLE: begin
                case (deb_play)
                    2'b00: state_w = S_IDLE;
                    2'b01: state_w = S_PLA1;
                    2'b10: state_w = S_PLA2;
                    2'b11: state_w = S_PLA3;
                endcase
            end
            S_PLA1, S_PLA2, S_PLA3: begin
                if (end_of_audio) state_w = S_IDLE;
            end
        endcase
    end

    always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
        if (!i_rst_n) state_r <= S_IDLE;
        else state_r <= state_w;
    end
endmodule

module audio_debouncer (
    input clk,
    input rst_n,
    input [1:0] async_in,
    output logic [1:0] debounced_out
);

    logic [1:0] sync_stage1;
    logic [1:0] sync_stage2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sync_stage1 <= 2'b0;
            sync_stage2 <= 2'b0;
        end else begin
            sync_stage1 <= async_in;
            sync_stage2 <= sync_stage1;
        end
    end

    logic [1:0] m_data_reg [3:0];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            m_data_reg[0] <= 2'b0;
            m_data_reg[1] <= 2'b0;
            m_data_reg[2] <= 2'b0;
            m_data_reg[3] <= 2'b0;
        end else begin
            m_data_reg[0] <= sync_stage2;
            m_data_reg[1] <= m_data_reg[0];
            m_data_reg[2] <= m_data_reg[1];
            m_data_reg[3] <= m_data_reg[2];
        end
    end

    wire m_data_stable = (m_data_reg[0] == m_data_reg[1]) && (m_data_reg[1] == m_data_reg[2]) && (m_data_reg[2] == m_data_reg[3]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            debounced_out <= 2'b00;
        end else begin
            if (m_data_stable) begin
                debounced_out <= m_data_reg[0];
            end
        end
    end
    
endmodule

// module bridge (
//     input s_clk,
//     input m_clk,
//     input rst_n,
//     input [1:0] s_data, // with valid
//     output logic s_ready,
//     output logic [1:0] m_data,
//     input m_busy
// );

//     localparam
//         IDLE = 0,
//         LATCH= 1;
//     logic s_state_w, s_state_r;
    
//     // Cross-domain feedback from Master domain to release Slave domain
//     logic m_ack;
//     logic s_ack_sync0, s_ack_sync1;

//     always_comb begin
//         s_state_w = s_state_r;
//         s_ready = 1'b0;

//         case (s_state_r)
//             IDLE: begin
//                 if (s_data != 2'b0) s_state_w = LATCH;
//                 s_ready = 1'b1;
//             end
//             LATCH: begin
//                 s_ready = 1'b0;
//                 // Leave LATCH state once the Master side acknowledges receipt
//                 if (s_ack_sync1) begin
//                     s_state_w = IDLE;
//                 end
//             end
//         endcase
//     end
    
//     always_ff @(posedge s_clk or negedge rst_n) begin
//         if (~rst_n) begin
//             s_state_r   <= IDLE;
//             s_ack_sync0 <= 1'b0;
//             s_ack_sync1 <= 1'b0;
//         end else begin
//             s_state_r   <= s_state_w;
//             // 2-FF Synchronizer for Ack feedback line
//             s_ack_sync0 <= m_ack;
//             s_ack_sync1 <= s_ack_sync0;
//         end
//     end

//     logic [1:0] s_data_reg;

//     always_ff @(posedge s_clk or negedge rst_n) begin
//         if (~rst_n) begin
//             s_data_reg <= 2'b00;
//         end else begin
//             if (s_state_r == IDLE) begin
//                 s_data_reg <= s_data;
//             end else if (s_state_r == LATCH && s_state_w == IDLE) begin
//                 // Force data register to clear back to zero when returning to IDLE
//                 s_data_reg <= 2'b00;
//             end
//         end
//     end

//     logic [1:0] m_data_reg [3:0];
    
//     always_ff @(posedge m_clk or negedge rst_n) begin
//         if (~rst_n) begin
//             m_data_reg[0] <= 2'b0;
//             m_data_reg[1] <= 2'b0;
//             m_data_reg[2] <= 2'b0;
//             m_data_reg[3] <= 2'b0;
//         end else begin
//             m_data_reg[0] <= s_data_reg;
//             m_data_reg[1] <= m_data_reg[0];
//             m_data_reg[2] <= m_data_reg[1];
//             m_data_reg[3] <= m_data_reg[2];
//         end
//     end

//     wire m_data_stable = (m_data_reg[0] == m_data_reg[1]) && (m_data_reg[1] == m_data_reg[2]) && (m_data_reg[2] == m_data_reg[3]);
//     wire m_data_valid  = (m_data_reg[0] != 2'b0) && m_data_stable;

//     logic m_state_w, m_state_r;

//     always_comb begin
//         m_state_w = m_state_r;
//         m_ack     = 1'b0;

//         case (m_state_r)
//             IDLE: begin
//                 // Only move to LATCH when data is valid AND the master is free to take it
//                 if (m_data_valid && ~m_busy) begin
//                     m_state_w = LATCH;
//                 end
//             end
//             LATCH: begin
//                 // Hold acknowledgment high, forcing the slave domain to clear its data
//                 m_ack = 1'b1;
                
//                 // We can ONLY return to IDLE once the slave has acknowledged our ack
//                 // by clearing its data register, and those zeros have rippled through
//                 if (~m_data_valid) begin
//                     m_state_w = IDLE;
//                 end
//             end
//         endcase
//     end
    
//     always_ff @(posedge m_clk or negedge rst_n) begin
//         if (~rst_n) begin
//             m_state_r <= IDLE;
//         end else begin
//             m_state_r <= m_state_w;
//         end
//     end

//     logic [1:0] o_data_reg;

//     always_ff @(posedge m_clk or negedge rst_n) begin
//         if (~rst_n) begin
//             o_data_reg <= 2'b00;
//         end else begin
//             if (m_state_r == IDLE && m_state_w == LATCH) begin
//                 o_data_reg <= m_data_reg[0]; // Capture verified data safely
//             end else if (m_state_r == LATCH && m_state_w == IDLE) begin
//                 o_data_reg <= 2'b00;         // Reset after handshake completes
//             end
//         end
//     end

//     assign m_data = o_data_reg;

// endmodule

// module bridge (
//     input  logic        s_clk,
//     input  logic        m_clk,
//     input  logic        rst_n,
//     input  logic        s_valid,
//     output logic        s_ack,
//     input  logic  [1:0] s_data,
//     output logic        m_valid,
//     input  logic        m_ack,
//     output logic  [1:0] m_data
// );

//     // -------------------------------------------------------------------------
//     // Signals in Source Clock Domain (s_clk)
//     // -------------------------------------------------------------------------
//     logic       s_req_reg;
//     logic [1:0] s_data_reg;
//     logic       s_ack_sync_m1, s_ack_sync_m2; 

//     // -------------------------------------------------------------------------
//     // Signals in Manager/Destination Clock Domain (m_clk)
//     // -------------------------------------------------------------------------
//     logic       m_valid_reg;
//     logic [1:0] m_data_reg;
//     logic       m_req_sync_s1, m_req_sync_s2; 
//     logic       m_req_sync_s2_q;              

//     // =========================================================================
//     // SOURCE DOMAIN LOGIC (s_clk)
//     // =========================================================================
    
//     // 2-FF Synchronizer: m_clk domain -> s_clk domain
//     always_ff @(posedge s_clk or negedge rst_n) begin
//         if (!rst_n) begin
//             s_ack_sync_m1 <= 1'b0;
//             s_ack_sync_m2 <= 1'b0;
//         end else begin
//             s_ack_sync_m1 <= m_valid_reg; 
//             s_ack_sync_m2 <= s_ack_sync_m1;
//         end
//     end

//     // Control logic
//     always_ff @(posedge s_clk or negedge rst_n) begin
//         if (!rst_n) begin
//             s_req_reg  <= 1'b0;
//             s_data_reg <= 2'b00;
//             s_ack      <= 1'b0;
//         end else begin
//             if (s_valid && !s_req_reg && !s_ack_sync_m2 && !s_ack) begin
//                 s_data_reg <= s_data;
//                 s_req_reg  <= 1'b1;
//             end else if (s_req_reg && s_ack_sync_m2) begin
//                 s_req_reg  <= 1'b0;
//                 s_ack      <= 1'b1; 
//             end else if (s_ack && !s_valid) begin
//                 s_ack      <= 1'b0;
//             end
//         end
//     end


//     // =========================================================================
//     // DESTINATION DOMAIN LOGIC (m_clk)
//     // =========================================================================
    
//     // 2-FF Synchronizer: s_clk domain -> m_clk domain
//     always_ff @(posedge m_clk or negedge rst_n) begin
//         if (!rst_n) begin
//             m_req_sync_s1   <= 1'b0;
//             m_req_sync_s2   <= 1'b0;
//             m_req_sync_s2_q <= 1'b0;
//         end else begin
//             m_req_sync_s1   <= s_req_reg;
//             m_req_sync_s2   <= m_req_sync_s1;
//             m_req_sync_s2_q <= m_req_sync_s2;
//         end
//     end

//     // Control logic
//     always_ff @(posedge m_clk or negedge rst_n) begin
//         if (!rst_n) begin
//             m_valid_reg <= 1'b0;
//             m_data_reg  <= 2'b00;
//         end else begin
//             if (m_req_sync_s2 && !m_req_sync_s2_q && !m_valid_reg) begin
//                 m_data_reg  <= s_data_reg;
//                 m_valid_reg <= 1'b1;
//             end else if (m_valid_reg && m_ack) begin
//                 m_valid_reg <= 1'b0;
//             end
//         end
//     end

//     assign m_valid = m_valid_reg;
//     assign m_data  = m_data_reg;

// endmodule