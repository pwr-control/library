/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 *
 * six_pulse_rect.c
 * Firing pulse generator for a six-pulse thyristor bridge.
 *
 * Phase offsets as in the original code (p1 = offset 5pi/3, ... p6 = offset 0):
 *   p1: wt + pi/6 + 5pi/3
 *   p2: wt + pi/6 + 4pi/3
 *   p3: wt + pi/6 + pi
 *   p4: wt + pi/6 + 2pi/3
 *   p5: wt + pi/6 + pi/3
 *   p6: wt + pi/6
 *
 * Fixes applied vs original:
 *   [1] synch_1..6 now float in the struct (was int — PWIDTH_PU was truncated to 0)
 *   [2] threshold held on non-firing cycles instead of accumulating unboundedly
 *   [3] sprcProcess return type is void (was float with no return statement)
 *   [4] sprcProcessSimulink: removed redundant p_inst copy, writes directly to p
 */

#include "../include/six_pulse_rect.h"

// ------------------------------------------------------------------------------
void sprcProcess(sprc_t *spr, float wt, float alpha, int block, spr_p_t *p)
{
    float phaseshift = 0.0f;

    phaseshift  = wt + MATH_PI_6 + MATH_5PI_3;
    spr->ramp_1 = phaseshift - floorf(phaseshift / MATH_2PI) * MATH_2PI;

    phaseshift  = wt + MATH_PI_6 + MATH_4PI_3;
    spr->ramp_2 = phaseshift - floorf(phaseshift / MATH_2PI) * MATH_2PI;

    phaseshift  = wt + MATH_PI_6 + MATH_PI;
    spr->ramp_3 = phaseshift - floorf(phaseshift / MATH_2PI) * MATH_2PI;

    phaseshift  = wt + MATH_PI_6 + MATH_2PI_3;
    spr->ramp_4 = phaseshift - floorf(phaseshift / MATH_2PI) * MATH_2PI;

    phaseshift  = wt + MATH_PI_6 + MATH_PI_3;
    spr->ramp_5 = phaseshift - floorf(phaseshift / MATH_2PI) * MATH_2PI;

    phaseshift  = wt + MATH_PI_6;
    spr->ramp_6 = phaseshift - floorf(phaseshift / MATH_2PI) * MATH_2PI;

    /* +++++++++++ */

    spr->synch_A1 = (spr->ramp_1 >= alpha) ? 1 : 0;

    /* FIX [2]: threshold latched on firing edge only, not accumulated */
    if (spr->synch_A1)
        spr->synch_1 = alpha + PWIDTH_PU;
    /* else: synch_1 unchanged */

    spr->synch_B1 = (spr->ramp_1 <= spr->synch_1) ? 1 : 0;

    p->p1 = (!block) ? (spr->synch_A1 & spr->synch_B1) : 0;

    /* +++++++++++ */

    spr->synch_A2 = (spr->ramp_2 >= alpha) ? 1 : 0;

    if (spr->synch_A2)
        spr->synch_2 = alpha + PWIDTH_PU;

    spr->synch_B2 = (spr->ramp_2 <= spr->synch_2) ? 1 : 0;

    p->p2 = (!block) ? (spr->synch_A2 & spr->synch_B2) : 0;

    /* +++++++++++ */

    spr->synch_A3 = (spr->ramp_3 >= alpha) ? 1 : 0;

    if (spr->synch_A3)
        spr->synch_3 = alpha + PWIDTH_PU;

    spr->synch_B3 = (spr->ramp_3 <= spr->synch_3) ? 1 : 0;

    p->p3 = (!block) ? (spr->synch_A3 & spr->synch_B3) : 0;

    /* +++++++++++ */

    spr->synch_A4 = (spr->ramp_4 >= alpha) ? 1 : 0;

    if (spr->synch_A4)
        spr->synch_4 = alpha + PWIDTH_PU;

    spr->synch_B4 = (spr->ramp_4 <= spr->synch_4) ? 1 : 0;

    p->p4 = (!block) ? (spr->synch_A4 & spr->synch_B4) : 0;

    /* +++++++++++ */

    spr->synch_A5 = (spr->ramp_5 >= alpha) ? 1 : 0;

    if (spr->synch_A5)
        spr->synch_5 = alpha + PWIDTH_PU;

    spr->synch_B5 = (spr->ramp_5 <= spr->synch_5) ? 1 : 0;

    p->p5 = (!block) ? (spr->synch_A5 & spr->synch_B5) : 0;

    /* +++++++++++ */

    spr->synch_A6 = (spr->ramp_6 >= alpha) ? 1 : 0;

    if (spr->synch_A6)
        spr->synch_6 = alpha + PWIDTH_PU;

    spr->synch_B6 = (spr->ramp_6 <= spr->synch_6) ? 1 : 0;

    p->p6 = (!block) ? (spr->synch_A6 & spr->synch_B6) : 0;
}

// ------------------------------------------------------------------------------
void sprcProcessSimulink(float wt, float alpha, int block, spr_p_t *p)
{
    static sprc_t spr_inst;   /* zero-initialised at startup (C99 §6.7.8) */
    sprcProcess(&spr_inst, wt, alpha, block, p);
}
