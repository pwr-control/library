/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Davide Bagnara
 */

#ifndef _HARMONIC_TRACKER_SIMULINK_
#define _HARMONIC_TRACKER_SIMULINK_

#define HARMONIC_TRACKER_INSTANCES 31

typedef struct harmonic_tracker_output_s {
	float	output_pu_hat;		/* output pu hat */
	float	output_pu_hat_dot;	/* output pu dot hat */
} harmonic_tracker_output_t;

#define HARMONIC_TRACKER_OUTPUT harmonic_tracker_output_t

// extern HARMONIC_TRACKER ht_i[HTI];
// extern unsigned int ht_init;

HARMONIC_TRACKER_OUTPUT harmonic_tracker_process_simulink(const unsigned char reset, const float u, const float ts,
const float omega_base, const float delta, const float l1, const float l2, const unsigned char instance);
#endif
