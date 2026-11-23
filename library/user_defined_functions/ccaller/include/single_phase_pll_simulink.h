/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _SINGLE_PHASE_PLL_SIMULINK_
#define _SINGLE_PHASE_PLL_SIMULINK_

#include <single_phase_pll.h>

#define NSINGLE_PHASE_PLL_INSTANCES				31

typedef struct single_phase_pll_output_s {
	float					ts;		        					/* sampling time */
	float 					single_phase_pll_output_alpha; 		/* output filter alpha */
	float 					single_phase_pll_output_beta; 		/* output filter beta */
} single_phase_pll_output_t;

#define SINGLE_PHASE_PLL_OUTPUT single_phase_pll_output_t

extern SINGLE_PHASE_PLL single_phase_pll_instances[NSINGLE_PHASE_PLL_INSTANCES];
extern unsigned int single_phase_pll_initialized;

SINGLE_PHASE_PLL_OUTPUT single_phase_pll_process_simulink(const float input, const float fcut, 
	const float ts, const unsigned char reset, const unsigned char instance);

#endif
