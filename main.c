#include <stdio.h>
#include "pico/stdlib.h"
#include <stdlib.h>
#include <string.h>
#include "hardware/timer.h"
#include "hardware/uart.h"
#include "bsp/board.h"
#include "tusb.h"

#define UART_ID   uart0
#define BAUD_RATE 1200

#define UART_TX_PIN 0
#define UART_RX_PIN 1


bool debug = false;
bool hid_debug = true;

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

  // microsoft mouses have Y inverted
  dy = -dy;
  
  if ((dx == last_dx)  && (dy == last_dy) && (left  == last_left) && (right == last_right)) 
    return;  
  last_dx    = dx;
  last_dy    = dy;
  last_left  = left;
  last_right = right;

  // Byte 1: 01MRYYXX
  byte0 = 0x40;                            // bit 6  first byte mark
  byte0 |= (left)         ? 0x20 : 0x00;   // bit 5  left button
  byte0 |= (right)        ? 0x10 : 0x00;   // bit 4  right button
  byte0 |= (dy < 0)       ? 0x08 : 0x00;   // bit 3  y sign
  byte0 |= (abs(dy) > 64) ? 0x04 : 0x00;   // bit 3  y 6th bit
  byte0 |= (dx < 0)       ? 0x02 : 0x00;   // bit 2  x sign
  byte0 |= (abs(dx) > 64) ? 0x01 : 0x00;   // bit 3  x 6th bit

  // Byte 2: 0XXXXXXX (X movement)
  byte1 = (abs(dx) % 64) & 0x3F;           // 6 bits of x

  // Byte 3: 0YYYYYYY (Y movement)
  byte2 = (abs(dy) % 64) & 0x3F;      // 6 bits of y

  uart_write_blocking(UART_ID, &byte0, 1);
  uart_write_blocking(UART_ID, &byte1, 1);
  uart_write_blocking(UART_ID, &byte2, 1);
}

bool led_service (repeating_timer_t *rt) {
  static bool led_state = false;

  board_led_write(led_state);
  led_state = !led_state;
  return true;
}


/*===========================================================================
 * start here
 * ========================================================================*/
int main (void) {
  //  static struct repeating_timer timer_tuh;
  static struct repeating_timer timer_led;

  gpio_set_function(PICO_DEFAULT_UART_RX_PIN, GPIO_FUNC_UART);
  gpio_set_function(PICO_DEFAULT_UART_TX_PIN, GPIO_FUNC_UART);
  board_init();
  tusb_init();
  add_repeating_timer_ms(1000/2, led_service, NULL, &timer_led);
  while (1) {
    tuh_task();
  }
}


