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


#include <linear_double_integrator_observer_simulink.h>

LINEAR_DOUBLE_INTEGRATOR_OBSVR observer_instances[NLIN_DOUBLE_INT_OBSVR_INSTANCES] = {0};
unsigned int observer_initialized = 0;

// ------------------------------------------------------------------------------
static void init_all_linear_double_integrator_observer_instances(LINEAR_DOUBLE_INTEGRATOR_OBSVR *const observer_list, const unsigned int observer_num, 
	const float ts, const float kx, const float kv) {
    unsigned int i;
    for (i = 0; i < observer_num; ++i) {
        LINEAR_DOUBLE_INTEGRATOR_OBSVR *const observer = &observer_list[i];
		linear_double_integrator_observer_init(observer, ts, kx, kv);
		i++;
	}
}

// ------------------------------------------------------------------------------
LINEAR_DOUBLE_INTEGRATOR_OBSVR linear_double_integrator_observer_process_simulink(const float input, const float kx, const float kv,
	const float ts, const unsigned char reset, const unsigned char instance) {
	if (!observer_initialized){
	    init_all_linear_double_integrator_observer_instances(observer_instances, NLIN_DOUBLE_INT_OBSVR_INSTANCES, ts, kx, kv);
		observer_initialized = 1;
	}

	const LINEAR_DOUBLE_INTEGRATOR_OBSVR* observer_instance = &observer_instances[instance];
	if (reset) {
		linear_double_integrator_observer_init(observer_instance, ts, kx, kv);
	}

	const float output_value = linear_double_integrator_observer_process(observer_instance, input);
	
	const LINEAR_DOUBLE_INTEGRATOR_OBSVR observer_output = {
			.ts = observer_instance->ts,
			.kx = observer_instance->kx,
			.kv = observer_instance->kv,
			.state_observer_x = observer_instance->state_observer_x,
			.state_observer_v = observer_instance->state_observer_v
	};

	return observer_output;
}

