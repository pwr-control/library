/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _SOGI_FLT_SIMULINK_
#define _SOGI_FLT_SIMULINK_

#include <sogi_flt.h>

#define NSOGI_FLT_INSTANCES				8

typedef struct sogi_flt_output_s {
	float					ts;		        			/* sampling time */
	float					fcut;		        		/* frequency at 90 deg phase shift */
	unsigned char			instance;					/* instance */
	unsigned char			reset;						/* reset */
	float 					sogi_flt_output_alpha; 		/* output filter alpha */
	float 					sogi_flt_output_beta; 		/* output filter beta */
} sogi_flt_output_t;

#define SOGI_FLT_OUTPUT sogi_flt_output_t

extern SOGI_FLT sogi_flt_instances[NSOGI_FLT_INSTANCES];
extern unsigned int sogi_flt_initialized;

SOGI_FLT_OUTPUT sogi_flt_process_simulink(const float input, const float fcut, 
	const float ts, const unsigned char reset, const unsigned char instance);

#endif
