import RPi.GPIO as GPIO
import time

PIN_RST     = 17
PIN_START_A = 27
PIN_START_B = 5
PIN_START_C = 6
PIN_START_D = 13
PIN_PB      = 22

PULSE_WIDTH = 0.05

def setup():
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    for pin in (PIN_RST, PIN_START_A, PIN_START_B, PIN_START_C, PIN_START_D, PIN_PB):
        GPIO.setup(pin, GPIO.OUT)
        GPIO.output(pin, GPIO.LOW)
    print("[System] GPIO initialized.")

def pulse(pin, label):
    GPIO.output(pin, GPIO.HIGH)
    time.sleep(PULSE_WIDTH)
    GPIO.output(pin, GPIO.LOW)
    print(f"[Action] {label} pulse sent.")

def reset_fpga():
    print("[System] Resetting FPGA...")
    GPIO.output(PIN_RST, GPIO.HIGH)
    time.sleep(0.2)
    GPIO.output(PIN_RST, GPIO.LOW)
    print("[System] FPGA reset complete.")

def main():
    setup()
    reset_fpga()

    print("\n" + "="*50)
    print("🚦 Traffic Light Demo Control Panel 🚦")
    print("="*50)
    print("Commands:")
    print("  [a] Send one car to Street A (start_a pulse)")
    print("  [b] Send one car to Street B (start_b pulse)")
    print("  [c] Send one car to Street C (start_c pulse)")
    print("  [d] Send one car to Street D (start_d pulse)")
    print("  [p] Pedestrian button press (Pb pulse)")
    print("  [r] Reset FPGA")
    print("  [q] Quit program")
    print("="*50)

    try:
        while True:
            cmd = input("\nEnter command (a/b/c/d/p/r/q): ").strip().lower()
            if cmd == 'a':
                pulse(PIN_START_A, "Street A start")
            elif cmd == 'b':
                pulse(PIN_START_B, "Street B start")
            elif cmd == 'c':
                pulse(PIN_START_C, "Street C start")
            elif cmd == 'd':
                pulse(PIN_START_D, "Street D start")
            elif cmd == 'p':
                pulse(PIN_PB, "Pedestrian button")
            elif cmd == 'r':
                reset_fpga()
            elif cmd == 'q':
                print("[System] Exiting...")
                break
            else:
                print("[Error] Invalid command. Use a, b, c, d, p, r, or q.")
    except KeyboardInterrupt:
        print("\n[System] Interrupted by user.")
    finally:
        GPIO.cleanup()
        print("[System] GPIO cleaned up safely. Goodbye!")

if __name__ == '__main__':
    main()
