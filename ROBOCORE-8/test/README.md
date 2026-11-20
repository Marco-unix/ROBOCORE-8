# ROBOCORE-8 tests

`test.py` checks reset, heartbeat requirement, forward / left / right autonomous behavior, all-obstacles brake, manual mode, arm/disarm and watchdog expiry/recovery. The main module instance in `tb.v` is `tt_um_robocore8`.

Run `make` from this folder with Cocotb and Icarus installed, or push to GitHub and check the original template Actions/test flow. There is no claim of a completed physical GDS or silicon test until the corresponding flow has run.
