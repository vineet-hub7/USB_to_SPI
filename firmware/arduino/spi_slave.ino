volatile uint8_t rx_byte = 0x00;
volatile bool new_data = false;
void setup() {
  Serial.begin(115200);
  Serial.println("Arduino SPI Slave starting...");
  pinMode(MISO, OUTPUT);
  pinMode(MOSI, INPUT);
  pinMode(SCK, INPUT);
  pinMode(SS, INPUT);
  SPCR = 0;
  SPCR |= (1 << SPE);
  SPCR |= (1 << SPIE);
  SPDR = 0x00;
  Serial.println("Ready. Waiting for FPGA...");
}

ISR(SPI_STC_vect) {
  rx_byte = SPDR;
  SPDR = rx_byte;
  new_data = true;
}

void loop() {
  if (new_data) {
    new_data = false;
    Serial.print("Received: 0x");
    if (rx_byte < 0x10)
      Serial.print("0");
    Serial.println(rx_byte, HEX);
  }
}