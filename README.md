# USB to Microsoft Serial Mouse Converter

## Project Overview

This project implements a USB to Microsoft Serial Mouse protocol converter using a Raspberry Pi Pico microcontroller. It allows modern USB mice to be used with vintage computers or FPGAs that expect the classic Microsoft Serial Mouse protocol.

## Key Features

- Converts USB mouse HID inputs to Microsoft Serial Mouse protocol
- Outputs formatted data at 1200 baud, 7N1 format
- Handles mouse movement (X and Y) and button states (left and right)
- Compatible with the Raspberry Pi Pico SDK environment

## Technical Details

### Microsoft Serial Mouse Protocol

The Microsoft mouse protocol uses:
- 1200 baud rate
- 7 data bits, 1 stop bit, no parity (7N1)
- 3-byte packet format:
  - Byte 1: `01MRYYXX` - Marker (bit 6 always 1), Left/Right buttons, Y/X movement signs and overflow
  - Byte 2: `0XXXXXXX` - X movement (6 bits)
  - Byte 3: `0YYYYYYY` - Y movement (6 bits)
  
### Hardware Requirements

- Raspberry Pi Pico
- USB mouse (HID-compatible)
- Optional: External power supply for the USB mouse
- Connection to target system (FPGA, vintage computer, etc.)

### Software Dependencies

- Raspberry Pi Pico SDK
- TinyUSB library (included in Pico SDK)

## Implementation Details

### Main Components

1. **USB HID Mouse Input Processing** (`usb_hid.c`):
   - Handles USB host functionality using TinyUSB
   - Processes mouse movement and button state changes
   - Forwards data to the serial converter

2. **Microsoft Serial Mouse Protocol Conversion** (`main.c`):
   - Formats mouse data according to Microsoft Serial Mouse protocol
   - Manages UART output (1200 baud, 7N1)
   - Handles mouse movement limits and button states

3. **System Initialization and Configuration**:
   - Sets up USB host functionality
   - Configures UART for mouse protocol output
   - Manages system timing and main loop

### Core Function: Mouse Processing

The key function that handles conversion of USB mouse data to the Microsoft Serial Mouse protocol:

```c
void process_mouse(int8_t dx, int8_t dy, int8_t dw, bool left, bool right, bool middle) {
  static int8_t last_dx    = 0;
  static int8_t last_dy    = 0;
  static bool   last_left  = false;
  static bool   last_right = false;
  uint8_t byte0, byte1, byte2;

  // Microsoft mice use 1200 baud rate 7N1
  static bool uart_initialized = false;
  if (!uart_initialized) {
    uart_init(UART_ID, BAUD_RATE);  
    uart_set_format(UART_ID, 7, 1, UART_PARITY_NONE);  
    uart_initialized = true;
  }

  // Microsoft mouses have Y inverted
  dy = -dy;
  
  if ((dx == last_dx) && (dy == last_dy) && (left == last_left) && (right == last_right)) 
    return;  
  last_dx    = dx;
  last_dy    = dy;
  last_left  = left;
  last_right = right;

  // Byte 1: 01MRYYXX
  byte0 = 0x40;                            // bit 6 first byte mark
  byte0 |= (left)         ? 0x20 : 0x00;   // bit 5 left button
  byte0 |= (right)        ? 0x10 : 0x00;   // bit 4 right button
  byte0 |= (dy < 0)       ? 0x08 : 0x00;   // bit 3 y sign
  byte0 |= (abs(dy) > 64) ? 0x04 : 0x00;   // bit 3 y 6th bit
  byte0 |= (dx < 0)       ? 0x02 : 0x00;   // bit 2 x sign
  byte0 |= (abs(dx) > 64) ? 0x01 : 0x00;   // bit 3 x 6th bit

  // Byte 2: 0XXXXXXX (X movement)
  byte1 = (abs(dx) % 64) & 0x3F;           // 6 bits of x

  // Byte 3: 0YYYYYYY (Y movement)
  byte2 = (abs(dy) % 64) & 0x3F;           // 6 bits of y

  uart_write_blocking(UART_ID, &byte0, 1);
  uart_write_blocking(UART_ID, &byte1, 1);
  uart_write_blocking(UART_ID, &byte2, 1);
}
```

## Building and Installation

### Build Instructions

1. Set up the Pico SDK environment:
   ```bash
   export PICO_SDK_PATH=/path/to/pico-sdk
   ```

2. Clone this repository and navigate to the project directory:
   ```bash
   git clone <repository-url>
   cd usb-to-serial-mouse
   ```

3. Generate the build files:
   ```bash
   cmake .
   ```

4. Build the project:
   ```bash
   make
   ```

5. Flash the generated `.uf2` file to your Pico by:
   - Holding the BOOTSEL button while connecting the Pico to your computer
   - Copying the `usb-to-serial-mouse.uf2` file to the mounted RPI-RP2 drive

### Configuration Options

#### UART Pins

By default, the project uses UART0 with the following pins:
- TX: GPIO 0
- RX: GPIO 1

If you need to use different pins, modify the following in `main.c`:
```c
#define UART_TX_PIN 0  // Change to your preferred TX pin
#define UART_RX_PIN 1  // Change to your preferred RX pin
```

#### Additional Configuration

Parameters can be adjusted in the source code:
- Baud rate: Default is 1200 baud for Microsoft Serial Mouse protocol
- Hardware configuration: USB host port settings

## Additional Notes

### Power Supply Considerations

The USB mouse typically requires more power than what's available through signal lines. Consider:
- Using a powered USB hub
- Adding an external power supply for the mouse
- Using a low-power mouse designed for mobile devices

### Reset Functionality

For full Microsoft mouse compatibility, implement:
- Reset detection when DTR is held low for 100ms (not implemented in current version)
- This allows the host system to initialize the mouse

### Extending to Other Mouse Formats

The project can be extended to support other vintage mouse protocols:
- PS/2 mouse protocol
- Quadrature mouse (Amiga, C64, Thomson TO8D)
- Analog mouse (Tandy CoCo 3)

To implement another format, modify the `process_mouse()` function to output the appropriate protocol and timing.

### VHDL Components (For FPGA Integration)

The project includes optional VHDL files for FPGA integration:
- `mouse_receiver.vhd`: Receives serial data at 1200 baud, 7N1
- `mouse_decoder.vhd`: Decodes Microsoft mouse packets into X/Y movements and button states
- `mouse_capture.vhd`: Debug utility to display mouse movements and button states
- `serial_write.vhd`: Utility used by `mouse_capture.vhd` for debug output

## Troubleshooting

- **USB Mouse Not Detected**: Ensure the mouse is compatible with USB HID standards
- **No Serial Output**: Check UART connections and ensure baud rate settings match
- **Erratic Movement**: Adjust movement sensitivity or fix overflow handling
- **Power Issues**: Use an external power supply if the mouse is not functioning properly

## Future Enhancements

Possible improvements to consider:
- Support for more mouse buttons (middle button, scroll wheel)
- Configuration options via USB connection
- Support for additional mouse protocols
- Hardware flow control implementation
- Mouse acceleration configuration# usb-to-serial-mouse
usb mouse to microsoft serial mouse adapter
