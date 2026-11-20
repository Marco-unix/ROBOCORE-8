# ROBOCORE-8 | Tiny Tapeout GlobalFoundries

**Digital motion controller for a small mobile robot, with exactly 8 dedicated digital inputs and 8 dedicated digital outputs.** Built on the original `ttgf-verilog-template` including GitHub Actions flows for test and GDS.

## Port allocation

| Input | Function | Output | Function |
|---|---|---|---|
| ui[0] | front obstacle, 1 = blocked | uo[0] | left motor forward |
| ui[1] | left obstacle, 1 = blocked | uo[1] | right motor forward |
| ui[2] | right obstacle, 1 = blocked | uo[2] | left motor reverse |
| ui[3] | autonomous mode, 1 = auto | uo[3] | right motor reverse |
| ui[4] | manual command bit 0 | uo[4] | brake / stop indicator, 1 = stopped |
| ui[5] | manual command bit 1 | uo[5] | front obstacle indicator |
| ui[6] | arm/enable | uo[6] | heartbeat link is valid |
| ui[7] | heartbeat toggle | uo[7] | mode echo |

Additional Tiny Tapeout reserved interface: `clk`, active-low `rst_n`, and `ena`. **These are not part of the eight dedicated data inputs**. The eight bidirectional pads (`uio`) are not used: `uio_oe=0`, `uio_out=0`. Do not connect motors directly to ASIC outputs.

### Motor output truth table

| Situation | uo[3:0] | Comment |
|---|---|---|
| Safe forward path | `0011` | Both motors forward |
| Front blocked, left clear | `0110` | Left motor reverse; right forward |
| Front and left blocked, right clear | `1001` | Left motor forward; right reverse |
| All blocked / disarmed / link lost | `0000` | Stop, brake indicator = 1 |

Autonomous priority: forward, left pivot, right pivot, stop. This is **rule-based obstacle avoidance, not AI**. Manual command bits `ui[5:4]`: `00` stop, `01` forward, `10` pivot left, `11` pivot right. Selected direction blocked = stop. No automatic reverse translation, because there is no rear obstacle detector.

### Heartbeat watchdog

After reset or disarm, motion requires a **new transition** on ui[7]. It must keep toggling at least once every 1024 clock cycles; otherwise, motor outputs become zero. Nominal `clock_hz=1000000`, so timeout is about 1.024 ms. An ESP32 should toggle the heartbeat substantially faster than this threshold; a typical operating system or Wi-Fi task alone should not be relied upon for such timing. Adjust clock or timeout in RTL if needed, and retest the physical integration.

**Safety caveat:** The watchdog only checks transition activity. It does not authenticate messages, measure sensor integrity, or replace an independent physical emergency-stop circuit. `BRAKE` is a stop indicator: whether short-braking occurs depends on the motor driver design.

## Upload to GitHub

1. Create a **public** repo from the official [Tiny Tapeout GF template](https://github.com/TinyTapeout/ttgf-verilog-template), or create an empty public repo.
2. Upload **all contents** of this ZIP project folder, including `.github/workflows`, not the ZIP itself. Keep `src/project.v`, `info.yaml`, and `test/test.py` in the same relative paths.
3. Open **Actions** and run/inspect the **test** workflow. Then inspect **gds** workflow for synthesis and placement.
4. If GDS completes, use its build artifact and layout viewer. **No passing CI/GDS is claimed until GitHub actually executes it.**

## Run Cocotb tests locally (if installed)

```bash
python3 -m pip install -r test/requirements.txt
sudo apt install iverilog
cd test
make
```

`src/config.json` and CI configuration remain from the original GF template. The one-tile setting is an **initial target**, not proof it physically fits; verify with the GDS run.

## Suggested connection

Sensors -> external signal conditioning / ESP32 GPIO -> `ui[7:0]` -> GF ASIC -> logic-level interface + **motor driver** -> two motors. Voltage compatibility and level shifting must be checked based on the actual fabricated hardware. A camera and web dashboard, if added, run outside the ASIC.
