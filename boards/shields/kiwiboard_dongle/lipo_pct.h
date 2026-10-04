/*
 * Remap ZMK's linear battery % to a LiPo discharge curve.
 *
 * Halves report lithium_ion_mv_to_pct(): a straight line from 3450 mV (0%)
 * to 4200 mV (100%), which overstates the drop near full and hides it near
 * empty. Undo that line back to mV, then interpolate a typical resting
 * LiPo curve. 0 (disconnected) and >100 (0xFF unknown) pass through.
 */

#pragma once

#include <stdint.h>

static inline uint8_t kiwi_lipo_pct(uint8_t linear) {
    static const struct {
        int16_t mv;
        uint8_t pct;
    } curve[] = {
        {4200, 100}, {4150, 95}, {4110, 90}, {4080, 85}, {4020, 80}, {3980, 75},
        {3950, 70},  {3910, 65}, {3870, 60}, {3850, 55}, {3840, 50}, {3820, 45},
        {3800, 40},  {3790, 35}, {3770, 30}, {3750, 25}, {3730, 20}, {3710, 15},
        {3690, 10},  {3610, 5},  {3270, 0},
    };

    /* 100 means ">= 4200 mV"; the inverse below would land at 4192. */
    if (linear == 0 || linear >= 100) {
        return linear;
    }

    /* Inverse of ZMK's `mv * 2 / 15 - 459`. */
    int mv = (linear + 459) * 15 / 2;

    if (mv >= curve[0].mv) {
        return 100;
    }
    for (int i = 1; i < sizeof(curve) / sizeof(curve[0]); i++) {
        if (mv >= curve[i].mv) {
            int dmv = curve[i - 1].mv - curve[i].mv;
            int dpct = curve[i - 1].pct - curve[i].pct;
            int pct = curve[i].pct + (mv - curve[i].mv) * dpct / dmv;
            /* Still connected: never report 0 (that means disconnected). */
            return pct > 0 ? pct : 1;
        }
    }
    return 1;
}
