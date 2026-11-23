/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 *
 * six_pulse_rect.h
 * Firing pulse generator for a six-pulse thyristor bridge.
 */

#ifndef SIX_PULSE_RECT_H
#define SIX_PULSE_RECT_H

#include <math.h>
#include "math_f.h"

// #define PWIDTH_PU  (1.047197551196598f)   /* pulse width [rad], ~60 deg */
#define PWIDTH_PU  (1.9f)   /* pulse width [rad], ~60 deg */

typedef struct sprc_s {

    /* Sawtooth ramps [0, 2pi), one per thyristor */
    float ramp_1;  float ramp_2;  float ramp_3;
    float ramp_4;  float ramp_5;  float ramp_6;

    /* Level-detector outputs: 1 when ramp >= alpha */
    int synch_A1;  int synch_A2;  int synch_A3;
    int synch_A4;  int synch_A5;  int synch_A6;

    /* Pulse-width limiter outputs: 1 when ramp <= threshold */
    int synch_B1;  int synch_B2;  int synch_B3;
    int synch_B4;  int synch_B5;  int synch_B6;

    /* Pulse-width thresholds — FLOAT (was int: truncation bug fixed) */
    float synch_1;  float synch_2;  float synch_3;
    float synch_4;  float synch_5;  float synch_6;

} sprc_t;

typedef struct spr_p_s {
    int p1;  int p2;  int p3;
    int p4;  int p5;  int p6;
} spr_p_t;

/* void return (was float with no return statement) */
void sprcProcess(sprc_t *spr, float wt, float alpha, int block, spr_p_t *p);

void sprcProcessSimulink(float wt, float alpha, int block, spr_p_t *p);

#endif /* SIX_PULSE_RECT_H */
