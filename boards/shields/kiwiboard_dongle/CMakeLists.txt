# SPDX-License-Identifier: MIT

target_sources_ifdef(CONFIG_ZMK_SPLIT_BATTERY_HID_REPORT app PRIVATE battery_hid.c)
target_sources(app PRIVATE dongle_led_off.c)
