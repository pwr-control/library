/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _PHASE_SHIFT_FLT_SIMULINK_
#define _PHASE_SHIFT_FLT_SIMULINK_

#define NPHASE_SHIFT_FLT_INSTANCES				31

typedef struct phase_shift_flt_output_s {
	float								ts;		        // sampling time
} phase_shift_flt_output_t;
#define PHASE_SHIFT_FLT_OUTPUT phase_shift_flt_output_t

PHASE_SHIFT_FLT_OUTPUT phase_shift_flt_process_simulink(const float input, const float period, const float ts, unsigned char reset, unsigned char instance);

#endif
