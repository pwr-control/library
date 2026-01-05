/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _LINEAR_DOUBLE_INTEGRATOR_OBSVR_SIMULINK_
#define _LINEAR_DOUBLE_INTEGRATOR_OBSVR_SIMULINK_

#include <linear_double_integrator_observer.h>

#define NLIN_DOUBLE_INT_OBSVR_INSTANCES				8

typedef struct phase_shift_flt_output_s {
	float					ts;		        			/* sampling time */
	float					fcut;		        		/* frequency at 90 deg phase shift*/
	float					scaling_factor;				/* correction factor */
	unsigned char			instance;					/* instance */
	unsigned char			reset;						/* reset */
	float 					phase_shift_flt_output; 	/* output filter */
} linear_double_integrator_observer_output_t;

#define LINEAR_DOUBLE_INTEGRATOR_OBSVR_OUTPUT linear_double_integrator_observer_output_t

extern LINEAR_DOUBLE_INTEGRATOR_OBSVR_OUTPUT observer_instances[NLIN_DOUBLE_INT_OBSVR_INSTANCES];
extern unsigned int observer_initialized;

LINEAR_DOUBLE_INTEGRATOR_OBSVR_OUTPUT linear_double_integrator_observer_process_simulink(const float input, const float kx, 
	const float kv, const float ts, const unsigned char reset, const unsigned char instance);

#endif
