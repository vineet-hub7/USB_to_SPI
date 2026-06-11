from machine import SPI, Pin
import shrike, time

shrike.flash("usbspi.bin")
time.sleep(0.5)

spi = SPI(0, baudrate=1_000_000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
            sck=Pin(2), mosi=Pin(3), miso=Pin(0))
cs = Pin(1, Pin.OUT, value=1)

def xfer(b):
      rx = bytearray(1)
      cs(0); spi.write_readinto(bytes([b]), rx); cs(1)
      return rx[0]

prev = None
for b in [0xBB, 0xCD, 0xEF, 0x42, 0x00]:
      r = xfer(b)
      if prev is not None:
          print("sent 0x%02X -> read 0x%02X  %s" %
                (prev, r, "OK" if r == prev else "MANGLED"))
      prev = b