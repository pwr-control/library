/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef __SINGLE_PHASE_PLL__
#define __SINGLE_PHASE_PLL__

typedef struct single_phase_pll_s {
	float								ts;					/* sampling time */
	float								kp_pll;				/* proportional gain */
	float								ki1_pll;			/* integral gain 1 */
	float								ki2_pll;			/* integral gain 2 */
	float								omega_base;			/* base frequency */
	float								tau;				/* time constant */
	float								gamma_hat;			/* estimated gamma */
	float								omega_hat;			/* estimated omega */
	float								omega_i_hat;		/* estimated omega integral */
	float								u_input;			/* input signal */
	float								u_alpha;			/* alpha component of input */
	float								u_beta;				/* beta component of input */
	float								u_alpha_out;		/* alpha component of output */
	float								u_beta_out;			/* beta component of output */
	float								u_xi;				/* xi component of input */
	float								u_eta;				/* eta component of input */
	float								u_xi_flt;			/* */
	float								u_eta_flt;			/* */
	dlpf_t								dlpf_xi;			/* */
	dlpf_t								dlpf_eta;			/* */
} single_phase_pll_t;

typedef struct dlpf_s {
	float								ts;					/* sampling time */
	float								tau;				/* time constant */
	float								input;				/* input signal */
	float								input_1;			/* previous input signal */
	float								output;				/* output signal */
	float								output_1;			/* previous output signal */
} dlpf_t;

#define SINGLE_PHASE_PLL single_phase_pll_t

void single_phase_pll_init(volatile SINGLE_PHASE_PLL *single_phase_pll, volatile float ts, volatile float kp_pll, 
	volatile float ki1_pll, volatile float ki2_pll, volatile float omega_base, volatile float tau);

void single_phase_pll_reset(volatile SINGLE_PHASE_PLL *single_phase_pll);

float single_phase_pll_process(volatile SINGLE_PHASE_PLL *single_phase_pll, float input);

void dlpf_init(volatile dlpf_t *dlpf, volatile float ts, volatile float tau);

void dlpf_reset(volatile dlpf_t *dlpf);

float dlpf_process(volatile dlpf_t *dlpf, float input);
#endif
