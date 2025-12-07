/*
Copyright (c) 2025 Davide Bagnara

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


#include <dqpll_thyr.h>
#include <dqpll_thyr_simulink.h>

DQPLL_THYR dqpll_thyr_ctrl = {0.0f};
unsigned int dqpll_thyr_ctrl_initialized = 0;

// ------------------------------------------------------------------------------
DQPLL_THYR_OUTPUT dqpll_thyr_process_simulink(unsigned char reset, const float u_phase_r, const float u_phase_s, 
		const float u_phase_t, const float ts) {

	if (!dqpll_thyr_ctrl_initialized) {
	    dqpll_thyr_init(&dqpll_thyr_ctrl);
		dqpll_thyr_ctrl_initialized = 1;
	}

	dqpll_thyr_ts(&dqpll_thyr_ctrl, ts);

	if (reset) {
		dqpll_thyr_reset(&dqpll_thyr_ctrl);
	}
	
	const float output_value = dqpll_thyr_process(&dqpll_thyr_ctrl, u_phase_r, u_phase_s, u_phase_t);

	const DQPLL_THYR_OUTPUT dqpll_thyr_ctrl_output = {
		.omega_pu_hat = dqpll_thyr_ctrl.omega_hat,
		.gamma_hat = dqpll_thyr_ctrl.gamma_hat,
		.u_thyr_xi = dqpll_thyr_ctrl.u_xi,
		.u_thyr_eta = dqpll_thyr_ctrl.u_eta,
		.dqpll_pll_state = dqpll_thyr_ctrl.dqpll_state
	};
	return dqpll_thyr_ctrl_output;
}

