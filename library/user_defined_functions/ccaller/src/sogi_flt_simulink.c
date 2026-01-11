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


#include <sogi_flt_simulink.h>

SOGI_FLT sogi_flt_instances[NSOGI_FLT_INSTANCES] = {0};
unsigned int sogi_flt_initialized = 0;

// ------------------------------------------------------------------------------
static void init_all_sogi_flt_instances(SOGI_FLT *const filter_list, const unsigned int filter_num, 
	const float ts, const float omega, const float kepsilon) {
    unsigned int i;
    for (i = 0; i < filter_num; ++i) {
        SOGI_FLT *const filter = &filter_list[i];
		sogi_flt_init(filter, ts, omega, kepsilon);
		i++;
	}
}

// ------------------------------------------------------------------------------
SOGI_FLT_OUTPUT sogi_flt_process_simulink(const float input, const float ts, const float omega, const float kepsilon, 
		const unsigned char reset, const unsigned char instance) {
	if (!sogi_flt_initialized){
	    init_all_sogi_flt_instances(sogi_flt_instances, NSOGI_FLT_INSTANCES, ts, omega, kepsilon);
		sogi_flt_initialized = 1;
	}

	const SOGI_FLT* sogi_flt_instance = &sogi_flt_instances[instance];
	if (reset) {
		sogi_flt_init(sogi_flt_instance, ts, omega, kepsilon);
	}

	const float output_value = sogi_flt_process(sogi_flt_instance, input);
	
	const SOGI_FLT_OUTPUT sogi_flt_output = {
			.ts = sogi_flt_instance->ts,
			.omega = sogi_flt_instance->omega,
			.instance = instance,
			.reset = reset,
			.sogi_flt_output_alpha = sogi_flt_instance->alpha,
			.sogi_flt_output_beta = sogi_flt_instance->beta
	};
	
	return sogi_flt_output;
}

