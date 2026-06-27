# Hardware Accelerated Breakout 🧱

> 硬體加速打磚塊 — 從傳統網格到 4096 顆粒子群的極限物理運算

一個跑在 **Terasic DE2-115 FPGA** 開發板上的打磚塊遊戲，使用 Verilog / SystemVerilog 實作。
畫面透過 VGA 輸出、音效透過 WM8731 Audio CODEC 播放，並以 PS/2 滑鼠操作。

本專案最大的亮點是：利用 **True Dual-Port BRAM** 的 ping-pong double buffering，
搭配 50 MHz 的 pipelined FSM，在硬體上同時運算 **4096 顆磚塊** 的碰撞物理，達成 zero-latency 的 VGA 渲染。

— 國立臺灣大學（數位電路實驗）期末專題・第十組：黃彥富、謝昊璇、林宸民

---

## ✨ 特色 Features

- **4096 顆磚塊極限模式**：捨棄外部 frame buffer，直接以 VGA 的 `pixel_x / pixel_y` 截斷後作為 BRAM 讀取位址，組合邏輯 MUX 即時轉成 24-bit RGB。
- **Double-Buffering（雙重緩衝）**：兩塊 True Dual-Port BRAM 互為前後端，FSM 全時運作不需停機。
- **多時脈域設計**：VGA 渲染跑 25 MHz、物理引擎跑 50 MHz、音訊子系統跑 `AUD_BCLK`，渲染與運算硬體解耦。
- **非同步分數佇列（Score Queue）**：把所有加分事件丟進緩衝佇列、逐幀 +1，避免多重驅動 (multiple drivers) 與 latch。
- **硬體音效**：碰撞、消磚等事件透過 `snd_trig` 觸發，由 Lab 3 的 I2S 音訊子系統播放。
- **雙遊戲模式**：經典模式與極限物理模式，用 `SW[11]` 切換，並在頂層做輸入遮罩避免互相干擾。

---

## 🛠️ 硬體需求 Hardware

| 項目 | 規格 |
|------|------|
| 開發板 | Terasic **DE2-115**（Intel/Altera Cyclone IV E） |
| 顯示 | VGA 螢幕（640×480 @ 60 Hz） |
| 輸入 | **PS/2 滑鼠** |
| 音效 | 內建 WM8731 Audio CODEC + 喇叭/耳機 |
| 工具 | **Quartus Prime**（建議 18.1 Lite 以上） |

---

## 🎮 操作方式 Controls

| 操作 | 對應 |
|------|------|
| 移動擋板（paddle） | 滑鼠左右移動 |
| 發球 | 滑鼠左鍵 |
| 切換遊戲模式 | 撥動 `SW[11]` |
| 重置遊戲 | 按下 `KEY[0]` |

---

## 🧩 系統架構 Architecture

```
                 ┌──────────────┐
   CLK 50MHz ───►│  PLL / I2C   │
                 └──────────────┘
   CLK 50MHz ───►┌──────────────────────────┐
                 │  Physics Engine (FSM)    │◄──► Brick State Registers
                 │  P_IDLE → P_CLEAR_BG →   │
                 │  P_UPD_0/1/2 → P_SWAP    │◄──► TDP BRAM A / BRAM B
                 └──────────────────────────┘        (Ping-Pong Buffer)
                          │ snd_trig                       │ Port A
                          ▼                                ▼ pixel_x/y
                 ┌──────────────┐   25MHz   ┌──────────────────────┐
                 │  Audio (I2S) │           │  VGA Controller +    │──► VGA DAC
                 │  → WM8731    │           │  RGB Multiplexer     │
                 └──────────────┘           └──────────────────────┘
```

**物理引擎工作流程**：
`P_IDLE`（等 VGA frame tick，每 2 幀更新一次）→
`P_CLEAR_BG`（清空後端緩衝畫布）→
`P_UPD_0` Fetch → `P_UPD_1` Address → `P_UPD_2` Collide & Write-back（處理 0–4095 號磚塊）→
`P_SWAP`（前後端緩衝交換）。

詳細資料路徑與演算法請見 [`docs/team10_final_report.pdf`](docs/team10_final_report.pdf)。

---

## 📂 檔案結構 File Structure

```
.
├── README.md
├── LICENSE
├── .gitignore
├── docs/                      # 書面報告與簡報
│   ├── team10_final_report.pdf
│   └── Presentation.pdf
└── src/
    ├── breakout_top.v         # 遊戲主模組（物理引擎 + TDP BRAM）
    ├── interface.sv           # 頂層整合：模式切換與輸入遮罩
    ├── vga_controller.v       # VGA 時序控制
    ├── DE2_115/               # 開發板頂層與腳位約束
    │   ├── DE2_115.sv         # 板級頂層（PS/2 滑鼠、VGA、音訊接腳）
    │   ├── DE2_115.qsf        # Quartus 腳位/設定
    │   ├── DE2_115.sdc        # 時序約束
    │   ├── Debounce.sv
    │   └── SevenHexDecoder.sv
    └── sound/                 # 音效子系統（改自 Lab 3）
        ├── *_rom/             # 各音效的 ROM IP
        ├── src/               # AudDSP / AudPlayer / I2C 初始化 / IP cores
        ├── *.mif / *.wav / *.raw
        └── mif_gen*.py        # 由音檔產生 .mif 的工具腳本
```

---

## 🚀 如何編譯與燒錄 Build & Flash

> 因為 IP Core 與部分絕對路徑與 Quartus 環境綁定，建議用 Quartus 重新建立專案後再加入原始檔。

1. 開啟 **Quartus Prime**，新建專案，元件選 **Cyclone IV E `EP4CE115F29C7`**（DE2-115）。
2. 將 `src/` 內的 `.v` / `.sv` 加入專案，頂層設為 **`DE2_115`**。
3. 匯入腳位約束：在 `Assignments → Import Assignments` 選擇 `src/DE2_115/DE2_115.qsf`；時序約束加入 `DE2_115.sdc`。
4. 重新產生 `src/sound/` 內所需的 IP（`*_rom`、`audio_rom`、`lab3_qsys` 等），或直接沿用附帶的 `.qip` / `.mif`。
5. `Processing → Start Compilation` 編譯。
6. `Tools → Programmer`，連接 DE2-115，燒錄 `output_files/*.sof`。
7. 接上 VGA 螢幕與 PS/2 滑鼠，開機即可遊玩。

### 重新產生音效 .mif

```bash
cd src/sound
python3 mif_gen.py        # 依腳本內設定，把 .wav/.raw 轉成 .mif
```

---

## 👥 團隊 Team

第十組 — 黃彥富、謝昊璇、林宸民

## 📄 授權 License

本專案採用 [MIT License](LICENSE)，歡迎參考與學習。
