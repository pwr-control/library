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


#include <phase_shift_flt.h>
#include <phase_shift_flt_simulink.h>

// ------------------------------------------------------------------------------
static void init_allphase_shift_flt_instances(PHASE_SHIFT_FLT *const filter_list, const unsigned int filter_num)
{
    unsigned int i;
    for (i = 0; i < filter_num; ++i) {
        PHASE_SHIFT_FLT *const filter = &filter_list[i];
		phase_shift_flt_init(filter);
		i++;
	}
}

// ------------------------------------------------------------------------------
PHASE_SHIFT_FLT_OUTPUT phase_shift_flt_process_simulink(const float input, const float period, const float ts, 
		unsigned char reset, unsigned char instance)
{
	static PHASE_SHIFT_FLT filter_instances[NPHASE_SHIFT_FLT_INSTANCES] = {0};
	static unsigned int filter_initialized = 0;

	if (!filter_initialized){
	    init_allphase_shift_flt_instances(filter_instances, NPHASE_SHIFT_FLT_INSTANCES);
		filter_initialized = 1;
	}

	if (instance < NPHASE_SHIFT_FLT_INSTANCES) {
		const PHASE_SHIFT_FLT* filter_instance = &filter_instances[instance];

		phase_shift_flt_ts(filter_instance, ts);
		
		if(reset)
		{
		    phase_shift_flt_reset(filter_instance);
		}

		const float output_value = phase_shift_flt_process(filter_instance, input, period);

		const PHASE_SHIFT_FLT_OUTPUT filter_output = {
			.phase_shift_flt_output = output_value
		};
		return filter_output;
	}
	else{
		const PHASE_SHIFT_FLT_OUTPUT empty_output = {
			0
		};
		return empty_output;
	}
}

