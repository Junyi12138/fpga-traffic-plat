# fpga-traffic-plat
FPGA-based traffic light evaluation platform — plug in different control strategies and compare them using real per-vehicle statistics, rather than watching if a set of lights looks right.

This started as an MSc dissertation project at the University of Edinburgh (School of Engineering). It runs on a low-cost FPGA connected to a Raspberry Pi, and is built for two teaching uses: showing a control strategy running live on physical hardware, and letting an instructor define custom traffic scenarios to evaluate a student's control algorithm using real journey/wait-time statistics rather than simulation.

## Hardware

- iCE40HX1K FPGA (ice4pi board)
- Raspberry Pi 4, connected over the 40-pin GPIO header
- Custom PCB: four-direction LED junction, driven by seven 74HC595 shift registers

## Getting Started

1. Physical connection. Plug the ice4pi board onto the Raspberry Pi's 40-pin GPIO header.
2. Connect to the Pi. Over SSH from another machine, or directly with a keyboard/monitor attached. Enable SPI first (sudo raspi-config → Interface Options → SPI) — this is what lets the Pi flash and talk to the FPGA. Also free up /dev/ttyAMA0 for the FPGA's UART connection: disable Bluetooth (sudo raspi-config → Interface Options → Serial Port → disable) and disable the login shell over serial (same menu, separate option) — both independently claim this interface, and disabling only one still leaves the connection unreliable. If statistics transmission is still flaky after both are off, check for any other process still holding /dev/ttyAMA0 open (e.g. sudo lsof /dev/ttyAMA0) and kill it.
3. Install the toolchain.
   sudo apt install git yosys fpga-icestorm arachne-pnr flashrom
4. Get ice4pi_prog. Clone the official board repo and keep the example/ folder's ice4pi_prog file for the next step:
   git clone https://github.com/lightside-instruments/ice4pi.git
5. Create one working folder on the Pi, and copy everything into it: every .v file, top_v2.pcf, ice4pi_prog (from step 4), the Makefile, and the Python scripts from this repo's verilog/ and python/ folders. They all need to sit together, flat, in this one folder — the Makefile and test_runner.py both use relative paths and won't find anything split across separate directories.
6. Build and flash:
   make
   sudo make load

## Repository structure

Assumes you're working on the Raspberry Pi (over SSH from another machine, or directly) with the ice4pi board plugged into the Pi's 40-pin header and SPI enabled — that connection is what lets the Pi flash and communicate with the FPGA in the first place.

- `verilog/` — all FPGA source: `top_v2.v`, `road_control_AB.v` / `road_control_lite.v` (full-statistics and lite variants — both declare `module road_control` internally, since `top.v` instantiates them by that name regardless of which file is used), `calculator.v`, three example control strategies (`traffic_light_timer.v`, `traffic_light_sensor.v`, `traffic_light_extend.v` for combine), `hc595_serializer_v2.v`, `buzzer_gate.v`, `frame_clk_div.v`, `stat_reporter.v`, `uart_tx.v`, and the pin constraint file `top_v2.pcf`
- `python/` — test automation: `test_config.py` defines the traffic density/road-type test matrix, `test_runner.py` drives the hardware and records results
- Note: verilog/ and python/ are separated here for browsing on GitHub only. On the Raspberry Pi itself, everything — all Verilog source files, top_v2.pcf, ice4pi_prog, and the Python scripts — should sit together in one working directory; the Makefile and test_runner.py both expect relative paths within that single folder, not the split structure shown above.

## Building and flashing

Toolchain: ice4pi open-source flow (yosys, arachne-pnr, icepack, flashed via ice4pi_prog). ice4pi_prog comes from the official lightside-instruments/ice4pi repository, in its example/ folder alongside the sample Makefile — clone that repo and copy ice4pi_prog from there if it's missing from this project.

sudo apt install git yosys fpga-icestorm arachne-pnr flashrom

To switch which control strategy is running, copy the desired variant into the project as traffic_light_extend.v. The whole project folder — every file listed in the Makefile, top.pcf, and the ice4pi_prog executable — must be present and named exactly as-is; the load step calls ./ice4pi_prog by relative path and won't run without it.

make
sudo make load

## Running an evaluation

Traffic density and road type are set in `test_config.py` as plain Python values (`BASE_INTERVAL`, `MINOR_MULTIPLIER`). Edit these, then run `test_runner.py` to generate a new set of test combinations. Each run produces a timestamped CSV with car count, journey/wait time (total and max), and throughput per direction. 

## Manual demo (classroom use)

demo.py is a simple interactive control panel for live demonstration — not for running the automated 27-combination evaluation (test_runner.py does that). It lets you manually pulse a single car into any direction, trigger the pedestrian button, or reset the FPGA, one command at a time from the terminal:

python3 demo.py

Then type a/b/c/d to send one car to that direction, p for a pedestrian request, r to reset, or q to quit. Useful for showing a control strategy running live on the hardware without setting up a full test run.

## Writing a control strategy

A control strategy is a single Verilog module, `traffic_light_extend`, and nothing outside it needs to be touched. It must accept `clk_12mhz`, `rst`, `Sa`, `Sb` (merged sensor inputs for the two direction pairs), `Pb` (pedestrian button), and drive `Ga`/`Ya`/`Ra`, `Gb`/`Yb`/`Rb`, `Gp`/`Rp`. The port list must stay exactly as-is even if a design doesn't use every signal — leave unused inputs unread, and tie unused outputs to a constant (e.g. `assign Gp = 1'b0;`) rather than dropping the port.

The current interface only supports strategies that treat the junction as two direction pairs (AC and BD together); it cannot express four independently-controlled directions without also changing `top.v`.

## Known limitations

- Each control strategy was evaluated once per test combination in the accompanying thesis, not repeated — some results reflect single-run timing variation, not a robust average.
- `calculator.v`'s BRAM read has a known timing edge case: under back-to-back vehicle completions, it can read the previous vehicle's entry timestamp instead of the current one's, slightly misattributing journey time in dense traffic. Not yet fixed.
- The web-based remote-access layer that originally motivated this project (students uploading code and watching it run over the internet) was not built.

## License

MIT — see LICENSE.
