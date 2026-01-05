/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _PHASE_SHIFT_FLT_
#define _PHASE_SHIFT_FLT_

typedef struct phase_shift_flt_s {
	float								ts;				/* sampling time */
	float								fcut;			/* frequency at 90 degree phase shit */
	float								a;				/* filter coefficient a */
	float								b;				/* filter coefficient b */
	float								scaling;		/* output */
	float								input_flt_1;	/* input z^-1 */
	float								output_flt_1;	/* output z^-1 */
} phase_shift_flt_t;

#define PHASE_SHIFT_FLT phase_shift_flt_t

void phase_shift_flt_init(volatile PHASE_SHIFT_FLT *flt, volatile float ts, volatile float fcut, volatile float scaling);

float phase_shift_flt_process(volatile PHASE_SHIFT_FLT *flt, float input);

#endif
