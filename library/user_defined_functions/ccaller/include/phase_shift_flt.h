/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _PHASE_SHIFT_FLT_
#define _PHASE_SHIFT_FLT_

#define PHASE_SHIFT_FLT_SIZE_MAX	1600

typedef struct phase_shift_flt_s {
	float								ts;						    /* Filter time base. */
} phase_shift_flt_t;
#define PHASE_SHIFT_FLT phase_shift_flt_t

void phase_shift_flt_init(volatile PHASE_SHIFT_FLT *f);

void phase_shift_flt_ts(volatile PHASE_SHIFT_FLT *f, volatile float ts);
void phase_shift_flt_reset(volatile PHASE_SHIFT_FLT *f);

float phase_shift_flt_process(volatile PHASE_SHIFT_FLT *f, float input, const float period);

#endif
