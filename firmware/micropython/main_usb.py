import sys
from machine import SPI, Pin
import shrike

shrike.flash("usbspi.bin")

spi = SPI(0, baudrate=1_000_000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
          sck=Pin(2), mosi=Pin(3), miso=Pin(0))
cs = Pin(1, Pin.OUT, value=1)

def spi_transfer(b: int) -> int:
    rx = bytearray(1)
    cs(0)
    spi.write_readinto(bytes([b]), rx)
    cs(1)
    return rx[0]

while True:
    raw = sys.stdin.buffer.read(1)
    if raw:
        reply = spi_transfer(raw[0])
        sys.stdout.buffer.write(bytes([reply]))
