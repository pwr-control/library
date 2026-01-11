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


#include <single_phase_pll_simulink.h>

SINGLE_PHASE_PLL single_phase_pll_instances[NSINGLE_PHASE_PLL_INSTANCES] = {0};
unsigned int single_phase_pll_initialized = 0;

// ------------------------------------------------------------------------------
static void init_all_single_phase_pll_instances(SINGLE_PHASE_PLL *const filter_list, const unsigned int filter_num, 
	const float ts, const float kp_pll, const float ki1_pll, const float ki2_pll, const float omega_base, 
	const float tau) {
    unsigned int i;
    for (i = 0; i < filter_num; ++i) {
        SINGLE_PHASE_PLL *const filter = &filter_list[i];
		single_phase_pll_init(filter, ts, kp_pll, ki1_pll, ki2_pll, omega_base, tau);
		i++;
	}
}

// ------------------------------------------------------------------------------
SINGLE_PHASE_PLL_OUTPUT single_phase_pll_process_simulink(const float input, volatile float ts, 
	volatile float kp_pll, volatile float ki1_pll, volatile float ki2_pll, volatile float omega_base, 
	volatile float tau, const unsigned char reset, const unsigned char instance) {
	if (!single_phase_pll_initialized){
	    init_all_single_phase_pll_instances(single_phase_pll_instances, NSINGLE_PHASE_PLL_INSTANCES, 
			ts, kp_pll, ki1_pll, ki2_pll, omega_base, tau);
		single_phase_pll_initialized = 1;
	}

	const SINGLE_PHASE_PLL* single_phase_pll_instance = &single_phase_pll_instances[instance];
	if (reset) {
		single_phase_pll_init(single_phase_pll_instance, ts, kp_pll, ki1_pll, ki2_pll, omega_base, tau); 
	}

	const float output_value = single_phase_pll_process(single_phase_pll_instance, input);
	
	const SINGLE_PHASE_PLL_OUTPUT single_phase_pll_output = {
			.ts = single_phase_pll_instance->ts,
			.single_phase_pll_output_alpha = single_phase_pll_instance->u_alpha_out,
			.single_phase_pll_output_beta = single_phase_pll_instance->u_beta_out,
	};
	
	return single_phase_pll_output;
}

