/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _PHASE_SHIFT_FLT_
#define _PHASE_SHIFT_FLT_

typedef struct phase_shift_flt_s {
	float								ts;				/* sampling time */
	float								a;				/* filter coefficient a */
	float								b;				/* filter coefficient b */
	float								scaling;		/* output */
} phase_shift_flt_t;

#define PHASE_SHIFT_FLT phase_shift_flt_t

void phase_shift_flt_init(volatile PHASE_SHIFT_FLT *flt, volatile float ts, volatile float fcut, volatile float scaling);

float phase_shift_flt_process(volatile PHASE_SHIFT_FLT *flt, float input);

#endif
