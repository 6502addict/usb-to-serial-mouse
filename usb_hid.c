#include <stdio.h>
#include "pico/stdlib.h"
#include <stdlib.h>
#include <string.h>
#include "bsp/board.h"
#include "tusb.h"

#define HOTSPOT __inline__ __attribute__ ((always_inline, hot))

extern void process_mouse(int8_t, int8_t, int8_t, bool, bool, bool);

void tuh_hid_mount_cb (uint8_t dev_addr, uint8_t instance, uint8_t const* desc_report, uint16_t desc_len) {
  uint8_t const itf_protocol = tuh_hid_interface_protocol(dev_addr, instance);
  static bool initialized = false;
  static uint8_t leds;
  uint16_t vid, pid;
  
  if (itf_protocol == HID_ITF_PROTOCOL_MOUSE) {
    tuh_hid_receive_report (dev_addr, instance);
  }
}

void tuh_hid_report_received_cb  (uint8_t dev_addr, uint8_t instance, uint8_t const* report, uint16_t len) {
  hid_mouse_report_t *mouse_report;
  uint8_t button_mask;
  //  uint8_t i;
  (void) instance; (void) len;
  bool left, right, middle;
  //  static uint8_t leds = 0, last_leds = 0;
  
  switch (tuh_hid_interface_protocol (dev_addr, instance)) {
  case HID_ITF_PROTOCOL_MOUSE:
    mouse_report = (hid_mouse_report_t *) report;
    left   = mouse_report->buttons & MOUSE_BUTTON_LEFT   ? true : false;
    right  = mouse_report->buttons & MOUSE_BUTTON_RIGHT  ? true : false;
    middle = mouse_report->buttons & MOUSE_BUTTON_MIDDLE ? true : false;
    process_mouse(mouse_report->x, mouse_report->y, mouse_report->wheel, left, right, middle);
    break;
  }
  tuh_hid_receive_report (dev_addr, instance);
}

void tuh_hid_umount_cb (uint8_t dev_addr, uint8_t instance)  {
  uint8_t const itf_protocol = tuh_hid_interface_protocol(dev_addr, instance);
  uint16_t vid, pid;

  tuh_vid_pid_get(dev_addr, &vid, &pid);
  if (itf_protocol == HID_ITF_PROTOCOL_MOUSE) {
    //
  }  
}

