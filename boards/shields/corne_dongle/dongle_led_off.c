/*
 * Hold the nice!nano status LED pin (P0.15) low on the dongle.
 * That pin is the MCU-driven LED (often red on clones). The bright
 * blue LED on many clones is wired to USB power and cannot be
 * disabled in firmware — cover it if it stays on.
 */

#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/init.h>

#define STATUS_LED_PIN 15

static int dongle_status_led_off(void) {
    const struct device *gpio0 = DEVICE_DT_GET(DT_NODELABEL(gpio0));
    if (!device_is_ready(gpio0)) {
        return -ENODEV;
    }
    return gpio_pin_configure(gpio0, STATUS_LED_PIN, GPIO_OUTPUT_INACTIVE);
}

SYS_INIT(dongle_status_led_off, APPLICATION, 99);
