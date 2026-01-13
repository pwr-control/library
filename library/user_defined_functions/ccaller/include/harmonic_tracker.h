/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Davide Bagnara
 */

#ifndef _HARMONIC_TRACKER_
#define _HARMONIC_TRACKER_

//#include <math.h>
#include <math_f.h>

#define HARMONIC_TRACKER_A11		0.0f
#define HARMONIC_TRACKER_A12		1.0f
#define HARMONIC_TRACKER_C1		1.0f


typedef struct harmonic_tracker_s {
	float			ts;		    						/* sampling time */
	float 			harmonic_tracker_l1;			/*  */
	float 			harmonic_tracker_l2;			/*  */
	float 			harmonic_tracker_A11;			/*  */
	float 			harmonic_tracker_A12;			/*  */
	float 			harmonic_tracker_A21;			/*  */
	float 			harmonic_tracker_A22;			/*  */
	float 			harmonic_tracker_C1;			/*  */
	float			harmonic_tracker_error;		/*  */
	float			harmonic_tracker_state1;		/*  */
	float			harmonic_tracker_state2;		/*  */
	float			harmonic_tracker_output;		/*  */
} harmonic_tracker_t;

#define HARMONIC_TRACKER harmonic_tracker_t

void harmonic_tracker_ts(volatile HARMONIC_TRACKER *f, volatile float ts);

void harmonic_tracker_init(volatile HARMONIC_TRACKER *f,const float omega_base, const float delta, const float l1, const float l2);

void harmonic_tracker_reset(volatile HARMONIC_TRACKER *f);

float harmonic_tracker_process(volatile HARMONIC_TRACKER *f, const float u);

#endif
