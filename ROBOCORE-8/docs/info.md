# ROBOCORE-8: 8-bit robot motion and watchdog control

ROBOCORE-8 is a minimal, synthesizeable finite-state-style robot controller described in Verilog and targeted at Tiny Tapeout GF. It maps **8 dedicated digital inputs to 8 dedicated digital outputs**. It contains an obstacle avoidance priority decoder and a clock-cycle heartbeat watchdog. `uio` pins are disabled.

Please see the root `README.md` for the complete pinout, behavior, timing and safety limitations.

The project does **not** contain an ESP32 firmware implementation, physical circuit board, machine-learning engine, camera vision pipeline, or confirmed manufactured silicon. Those are future integration options.
