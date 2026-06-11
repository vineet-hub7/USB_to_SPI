import serial
import time

PORT = "COM3"       # set to your RP2040 COM port (Device Manager)
BAUD = 115200

with serial.Serial(PORT, BAUD, timeout=1) as ser:
    time.sleep(0.5)

    payload = [0xAB, 0xCD, 0xEF, 0x42]
    print("Sending bytes to Arduino via FPGA:")

    for val in payload:
        ser.write(bytes([val]))
        print(f"  Sent: 0x{val:02X}")
        time.sleep(0.05)

    print("Done! Check Arduino Serial Monitor.")
