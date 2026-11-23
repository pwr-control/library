/*
Copyright (c) 2026 Davide Bagnara

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <single_phase_pll.h>
#include <single_phase_pll_simulink.h>
#include <math_f.h>

void single_phase_pll_init(volatile SINGLE_PHASE_PLL *single_phase_pll, volatile float ts, 
	volatile float kp_pll, volatile float ki1_pll, volatile float ki2_pll, volatile float omega_base, 
	volatile float tau)
{
	single_phase_pll->ts = ts;
	single_phase_pll->kp_pll = kp_pll;
	single_phase_pll->ki1_pll = ki1_pll;
	single_phase_pll->ki2_pll = ki2_pll;
	single_phase_pll->omega_base = omega_base;
	single_phase_pll->tau = tau;

	single_phase_pll_reset(single_phase_pll);
}

void single_phase_pll_reset(volatile SINGLE_PHASE_PLL *single_phase_pll)
{
	single_phase_pll->gamma_hat = 0.0f;
	single_phase_pll->omega_hat = 0.0f;
	single_phase_pll->omega_i_hat = 0.0f;
	single_phase_pll->u_input = 0.0f;
	single_phase_pll->u_alpha = 0.0f;
	single_phase_pll->u_input = 0.0f;
	single_phase_pll->u_alpha_out = 0.0f;
	single_phase_pll->u_beta_out = 0.0f;
	single_phase_pll->u_xi = 0.0f;
	single_phase_pll->u_eta = 0.0f;
	single_phase_pll->u_xi_flt = 0.0f;
	single_phase_pll->u_eta_flt = 0.0f;
}
float single_phase_pll_process(volatile SINGLE_PHASE_PLL *single_phase_pll, float input) {

	const float single_phase_pll_alpha = single_phase_pll->u_input;
	const float single_phase_pll_beta = single_phase_pll->u_beta;

	const float x_tilde = 0;
	const float ts = single_phase_pll->ts;
	const float kp_pll = single_phase_pll->kp_pll;
	const float ki1_pll = single_phase_pll->ki1_pll;
	const float ki2_pll = single_phase_pll->ki2_pll;

	const float omega_i_hat = single_phase_pll->omega_i_hat;
	const float gamma_hat = single_phase_pll->gamma_hat;

	const float th_sin = sinf(gamma_hat);
	const float th_cos = cosf(gamma_hat);
	
	single_phase_pll->omega_i_hat = x_tilde * ki1_pll * ts + omega_i_hat;
	single_phase_pll->omega_hat = x_tilde * kp_pll + single_phase_pll->omega_i_hat + 1.0f;
	single_phase_pll->gamma_hat = single_phase_pll->omega_hat * ki2_pll * ts + gamma_hat;
	single_phase_pll->gamma_hat = fmodf(single_phase_pll->gamma_hat + MATH_3PI, MATH_2PI) - MATH_PI;

	return single_phase_pll_alpha;
}


