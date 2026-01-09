/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef __SOGI_FLT__
#define __SOGI_FLT__


#define B1_ALPHA		0.000785057533863491f
#define B2_ALPHA		-0.000785057533863491f
#define B1_BETA			0.00000616676136360153f
#define B2_BETA			0.00000616514710729735f
#define A1				-1.998968272011592f
#define A2				0.999214910181010f

/*
#define B1_ALPHA		0.006247015559053f
#define B2_ALPHA		-0.006247015559053f
#define B1_BETA			0.000393440700289255f
#define B2_BETA			0.000392617109480794f
#define A1				-1.978015356429377f
#define A2				0.993736512624778f
*/

typedef struct sogi_flt_s {
	float								ts;					/* sampling time */
	float								fcut;				/* frequency at 90 degree phase shit */
	float								b1_alpha;			/* filter coefficient b1 alpha */
	float								b2_alpha;			/* filter coefficient b2 alpha */
	float								b1_beta;			/* filter coefficient b1 beta */
	float								b2_beta;			/* filter coefficient b2 beta */
	float								a1;					/* filter coefficient a1 */
	float								a2;					/* filter coefficient a2 */
	float								input;				/* input z^-1 */
	float								input_1;			/* input z^-1 */
	float								input_2;			/* input z^-2 */
	float								output_alpha;		/* output alpha */
	float								output_alpha_1;		/* output alpha z^-1 */
	float								output_alpha_2;		/* output alpha z^-2 */
	float								output_beta;		/* output beta */
	float								output_beta_1;		/* output beta z^-1 */
	float								output_beta_2;		/* output beta z^-2 */
} sogi_flt_t;

#define SOGI_FLT sogi_flt_t

void sogi_flt_init(volatile SOGI_FLT *flt, volatile float ts, volatile float fcut);

void sogi_flt_reset(volatile SOGI_FLT *flt);

float sogi_flt_process(volatile SOGI_FLT *flt, float input);

#endif
