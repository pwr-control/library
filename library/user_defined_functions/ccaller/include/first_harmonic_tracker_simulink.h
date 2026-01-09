/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _FIRST_HARMONIC_TRACKER_SIMULINK_
#define _FIRST_HARMONIC_TRACKER_SIMULINK_

#define FIRST_HARMONIC_TRACKER_INSTANCES 16

typedef struct first_harmonic_tracker_output_s {
	float	output_pu_hat;		/* output pu hat */
} first_harmonic_tracker_output_t;
#define FIRST_HARMONIC_TRACKER_OUTPUT first_harmonic_tracker_output_t

// extern FIRST_HARMONIC_TRACKER fht_i[FHTI];
// extern unsigned int fht_init;

FIRST_HARMONIC_TRACKER_OUTPUT first_harmonic_tracker_process_simulink(const unsigned char reset, const float u, const float ts,
const float omega_base, const float delta, const float l1, const float l2, const unsigned char instance);
#endif
