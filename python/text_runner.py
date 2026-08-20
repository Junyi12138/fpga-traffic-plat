#!/usr/bin/env python3
import time
import threading
import struct
import csv
import serial
import RPi.GPIO as GPIO   # switch this if demo.py uses a different library (e.g. gpiozero)
from datetime import datetime
from test_config import TEST_MATRIX

# ============ parameters to confirm against actual wiring ============
PIN_RST         = 17
PIN_START_A     = 27
PIN_START_B     = 5
PIN_START_C     = 6
PIN_START_D     = 13
PIN_READ_STATS  = 18
PIN_PB          = 22

SERIAL_PORT = '/dev/serial0'
BAUD_RATE   = 9600

# Use 1 minute first to confirm the whole pipeline works, then switch to
# 900 (15 minutes) for the real run
TEST_DURATION_SEC = 900

OUTPUT_CSV = f"results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"

PULSE_WIDTH = 0.05   # 50ms, kept consistent with demo.py


def setup_gpio():
    GPIO.setmode(GPIO.BCM)
    for pin in [PIN_RST, PIN_START_A, PIN_START_B, PIN_START_C, PIN_START_D, PIN_READ_STATS, PIN_PB]:
        GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)


def pulse(pin, width=PULSE_WIDTH):
    GPIO.output(pin, GPIO.HIGH)
    time.sleep(width)
    GPIO.output(pin, GPIO.LOW)


def reset_fpga():
    pulse(PIN_RST)
    time.sleep(0.1)   # give the FPGA a moment to finish resetting


def traffic_worker(pin_pair, interval, stop_event):
    """Every `interval` seconds, pulse start on a direction pair (AC or BD)
    together, until stop_event is set."""
    while not stop_event.is_set():
        for pin in pin_pair:
            GPIO.output(pin, GPIO.HIGH)
        time.sleep(PULSE_WIDTH)
        for pin in pin_pair:
            GPIO.output(pin, GPIO.LOW)
        stop_event.wait(interval - PULSE_WIDTH)


def parse_line(raw):
    if raw is None or len(raw) != 12 or raw[11] != 0x0A:
        return None
    direction = chr(raw[0])
    car_count, total_journey, max_journey, total_wait, max_wait = struct.unpack('>5H', raw[1:11])
    avg_wait = (total_wait / car_count) if car_count > 0 else None
    return {
        'direction': direction,
        'car_count': car_count,
        'total_journey_time': total_journey,
        'max_journey_time': max_journey,
        'total_wait_time': total_wait,
        'max_wait_time': max_wait,
        'avg_wait_time': avg_wait,
        'throughput': car_count / TEST_DURATION_SEC,
    }


def read_two_lines(ser):
    """Read a larger chunk and actively search it for the A and B lines,
    rather than assuming they start exactly at byte 0."""
    raw = ser.read(60)   # read extra so a few stray leading bytes are still fine

    idx_a = None
    for i in range(len(raw) - 11):
        if raw[i] == ord('A') and raw[i+11] == 0x0A:
            idx_a = i
            break

    idx_b = None
    if idx_a is not None:
        for i in range(idx_a + 12, len(raw) - 11):
            if raw[i] == ord('B') and raw[i+11] == 0x0A:
                idx_b = i
                break

    line_a = raw[idx_a:idx_a+12] if idx_a is not None else None
    line_b = raw[idx_b:idx_b+12] if idx_b is not None else None
    return line_a, line_b, raw


def run_one_test(combo, ser):
    reset_fpga()

    stop_event = threading.Event()
    t_ac = threading.Thread(target=traffic_worker, args=((PIN_START_A, PIN_START_C), combo['ac_interval'], stop_event))
    t_bd = threading.Thread(target=traffic_worker, args=((PIN_START_B, PIN_START_D), combo['bd_interval'], stop_event))
    t_ac.start()
    t_bd.start()

    time.sleep(TEST_DURATION_SEC)

    stop_event.set()
    t_ac.join()
    t_bd.join()

    time.sleep(0.3)   # a little margin for the threads to wind down

    ser.reset_input_buffer()
    pulse(PIN_READ_STATS)

    line_a, line_b, raw = read_two_lines(ser)

    print(f"    [debug] received {len(raw)} raw bytes: {raw!r}")
    print(f"    [debug] line_a: {line_a!r}")
    print(f"    [debug] line_b: {line_b!r}")

    return parse_line(line_a), parse_line(line_b)


def main():
    setup_gpio()
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=5)

    fieldnames = ['density', 'road_type', 'direction',
                  'car_count', 'total_journey_time', 'max_journey_time', 'total_wait_time',
                  'max_wait_time', 'avg_wait_time', 'throughput']

    with open(OUTPUT_CSV, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        for combo in TEST_MATRIX:
            print(f"running combination: {combo['density']} / {combo['road_type']} ...")
            result_a, result_b = run_one_test(combo, ser)

            for result in (result_a, result_b):
                if result is None:
                    print("  warning: failed to parse this row, skipping")
                    continue
                row = {'density': combo['density'], 'road_type': combo['road_type']}
                row.update(result)
                writer.writerow(row)
                f.flush()

            print(f"  done: A={result_a}, B={result_b}")

    ser.close()
    GPIO.cleanup()
    print(f"all done, results saved to {OUTPUT_CSV}")


if __name__ == '__main__':
    main()
