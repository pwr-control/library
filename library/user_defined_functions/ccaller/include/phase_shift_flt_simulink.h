/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _PHASE_SHIFT_FLT_SIMULINK_
#define _PHASE_SHIFT_FLT_SIMULINK_

#include <phase_shift_flt.h>

#define NPHASE_SHIFT_FLT_INSTANCES				8

typedef struct phase_shift_flt_output_s {
	float					ts;		        			/* sampling time */
	float					fcut;		        		/* frequency at 90 deg phase shift*/
	float					scaling_factor;				/* correction factor */
	unsigned char			instance;					/* instance */
	unsigned char			reset;						/* reset */
	float 					phase_shift_flt_output; 	/* output filter */
} phase_shift_flt_output_t;

#define PHASE_SHIFT_FLT_OUTPUT phase_shift_flt_output_t

extern PHASE_SHIFT_FLT filter_instances[NPHASE_SHIFT_FLT_INSTANCES];
extern unsigned int filter_initialized;

PHASE_SHIFT_FLT_OUTPUT phase_shift_flt_process_simulink(const float input, const float fcut, 
	const float ts, const float scaling, const unsigned char reset, const unsigned char instance);

#endif
