# Hardware-Accelerated Breakout 🧱

> A real-time Breakout game on FPGA — scaling from a classic brick grid to a **4096-brick particle-physics engine** running entirely in hardware.

A Breakout game implemented in **Verilog / SystemVerilog** on the **Terasic DE2-115 (Intel Cyclone IV E)** FPGA board. The display is driven over **VGA**, audio is played through the on-board **WM8731 codec (I²S)**, and the paddle is controlled with a **PS/2 mouse**.

The headline achievement is a **4096-brick "extreme physics" mode**: by combining **true dual-port BRAM ping-pong double buffering** with a **50 MHz pipelined FSM**, the design computes collision physics for 4096 bricks every frame while rendering the VGA output with **zero added latency** — no external frame buffer required.

*National Taiwan University — Digital Circuit Lab, Final Project · Team 10: Yen-Fu Huang, Hao-Hsuan Hsieh, Chen-Min Lin*

---

## 🎮 Demo

All screenshots are captured from real hardware (DE2-115 → VGA monitor).

**Level select — custom brick layouts (heart, smiley, space invader, and more):**

![Level select screen](docs/images/level_select.png)

**Classic mode — a clean, ordered brick grid:**

![Classic mode](docs/images/classic_mode.png)

**Extreme physics mode — 4096 independent bricks, each with its own velocity vector, computed every frame:**

![4096-brick physics](docs/images/physics_4096.png)

![4096-brick particle explosion](docs/images/physics_explosion.png)

> The "spray" you see is not a particle effect — every coloured cell is a real brick whose position and collision are evaluated in hardware each frame by the pipelined physics FSM.

---

## ✨ Highlights

- **4096-brick extreme mode** — Instead of an external frame buffer, the VGA `pixel_x / pixel_y` coordinates are bit-truncated (`{pixel_y[8:2], pixel_x[9:2]}`) and used directly as the BRAM read address. The 3-bit readout feeds a combinational MUX that maps to 24-bit RGB, giving a **zero-latency** display data path.
- **Double-buffered rendering** — Two true dual-port BRAMs act as front/back buffers and swap each frame, so the physics FSM never has to stall.
- **Multi-clock-domain design** — VGA rendering at 25 MHz, the physics engine at 50 MHz, and the audio subsystem on `AUD_BCLK`, decoupling rendering from computation in hardware.
- **Asynchronous score queue** — Scoring events are pushed into a buffer queue and applied one-per-frame, eliminating multiple-driver conflicts and inferred latches when several events fire on the same cycle.
- **Hardware audio** — Collision and brick-break events raise a `snd_trig` flag that drives an I²S audio subsystem (reused from Lab 3) into the WM8731 codec.
- **Dual game modes** — A classic mode and the extreme-physics mode, toggled with `SW[11]`, with top-level input masking so the inactive module can't interfere.

---

## 🛠️ Hardware

| Item | Specification |
|------|---------------|
| FPGA board | Terasic **DE2-115** (Intel/Altera Cyclone IV E, `EP4CE115F29C7`) |
| Display | VGA monitor (640×480 @ 60 Hz) |
| Input | **PS/2 mouse** |
| Audio | On-board WM8731 audio codec + speaker/headphones |
| Toolchain | **Intel Quartus Prime** (18.1 Lite or newer recommended) |

---

## 🎮 Controls

| Action | Input |
|--------|-------|
| Move paddle | Move the mouse left / right |
| Launch ball | Left mouse button |
| Switch game mode | Toggle `SW[11]` |
| Reset game | Press `KEY[0]` |

---

## 🧩 System Architecture

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

**Physics engine pipeline (FSM):**
`P_IDLE` (wait for VGA frame tick; physics updates every 2 frames) →
`P_CLEAR_BG` (clear the back-buffer canvas) →
`P_UPD_0` Fetch → `P_UPD_1` Address → `P_UPD_2` Collide & Write-back (iterating bricks 0–4095) →
`P_SWAP` (swap front/back buffers).

In `P_UPD_2`, a non-zero readout from the front-buffer BRAM signals a spatial-hash collision with another brick; combined with the ball-collision latch, the brick is either cleared (written as `3'd0`) or has its velocity vector reflected and its new position written back.

For the full data path and timing analysis, see [`docs/team10_final_report.pdf`](docs/team10_final_report.pdf).

---

## ⚙️ Engineering Challenges Solved

This section captures the real hardware-design problems encountered and how they were resolved — the parts I learned the most from.

- **Routing explosion from a 4096-iteration `for` loop.** An early version scanned all 4096 bricks inside VGA combinational logic, so the synthesizer tried to unroll tens of thousands of multiplexers and Analysis & Synthesis stalled for 30+ minutes. **Fix:** rewrite the loop as a true dual-port BRAM with ping-pong buffering, driven by a 50 MHz pipelined FSM.
- **Multiple drivers and inferred latches.** When "ball breaks brick" and "collect bonus" fired on the same cycle, two logic blocks assigned to the score register simultaneously. **Fix:** an asynchronous score queue that serializes scoring events one-per-frame, plus strictly moving all combinational `wire` assignments outside `always` blocks for clean D-FF synthesis.
- **Ghost inputs across game modules.** After integrating two game modules, the mouse `click` signal reached both, so the background module silently ran and triggered a false Game Over. **Fix:** hardware input masking at the top level (e.g. `click & ~switch`) to fully isolate the inactive module.

---

## 📂 File Structure

```
.
├── README.md
├── LICENSE
├── .gitignore
├── docs/                      # Written report, presentation & images
│   ├── team10_final_report.pdf
│   ├── Presentation.pdf
│   └── images/                # Demo screenshots
└── src/
    ├── breakout_top.v         # Main game module (physics engine + TDP BRAM)
    ├── interface.sv           # Top-level integration: mode switching & input masking
    ├── vga_controller.v       # VGA timing controller
    ├── DE2_115/               # Board-level top & pin constraints
    │   ├── DE2_115.sv         # Board top (PS/2 mouse, VGA, audio pins)
    │   ├── DE2_115.qsf        # Quartus pin / settings
    │   ├── DE2_115.sdc        # Timing constraints
    │   ├── Debounce.sv
    │   └── SevenHexDecoder.sv
    └── sound/                 # Audio subsystem (adapted from Lab 3)
        ├── *_rom/             # Per-sound ROM IP
        ├── src/               # AudDSP / AudPlayer / I2C init / IP cores
        ├── *.mif / *.wav / *.raw
        └── mif_gen*.py        # Scripts that generate .mif from audio files
```

---

## 🚀 Build & Flash

> Because the IP cores and some paths are tied to the Quartus environment, the most reliable approach is to recreate the project in Quartus and add the source files.

1. Open **Quartus Prime**, create a new project, and select the device **Cyclone IV E `EP4CE115F29C7`** (DE2-115).
2. Add the `.v` / `.sv` files under `src/` to the project and set **`DE2_115`** as the top-level entity.
3. Import constraints: `Assignments → Import Assignments`, choose `src/DE2_115/DE2_115.qsf`; add `DE2_115.sdc` for timing.
4. Regenerate the IP under `src/sound/` (`*_rom`, `audio_rom`, `lab3_qsys`, etc.), or reuse the included `.qip` / `.mif` files.
5. `Processing → Start Compilation`.
6. `Tools → Programmer`, connect the DE2-115, and flash `output_files/*.sof`.
7. Connect a VGA monitor and a PS/2 mouse, then power on to play.

### Regenerating audio `.mif`

```bash
cd src/sound
python3 mif_gen.py        # Converts .wav/.raw into .mif per the script's settings
```

---

## 👥 Team

Team 10 — Yen-Fu Huang, Hao-Hsuan Hsieh, Chen-Min Lin

## 📄 License

Released under the [MIT License](LICENSE). Feel free to reference and learn from it.