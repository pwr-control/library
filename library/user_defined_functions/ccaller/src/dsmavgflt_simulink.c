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


#include <dsmavgflt.h>
#include <dsmavgflt_simulink.h>

// ------------------------------------------------------------------------------
static void init_alldsmavgflt_instances(DSMAVGFLT *const filter_list, 
	const unsigned int filter_num, const float ts) {
		
    unsigned int i;
    for (i = 0; i < filter_num; ++i) {
        DSMAVGFLT *const filter = &filter_list[i];
		dsmavgflt_init(filter, ts);
		i++;
	}
}

// ------------------------------------------------------------------------------
DSMAVGFLT_OUTPUT dsmavgflt_process_simulink(const float input, const float period, 
	const float ts, unsigned char reset, unsigned char instance) {

	static DSMAVGFLT filter_instances[NDSMAVGFLT_INSTANCES] = {0};
	static unsigned int filter_initialized = 0;

	if (!filter_initialized) {
	    init_alldsmavgflt_instances(filter_instances, NDSMAVGFLT_INSTANCES, ts);
		filter_initialized = 1;
	}

	if (instance < NDSMAVGFLT_INSTANCES) {
		const DSMAVGFLT* filter_instance = &filter_instances[instance];


		if(reset) {
			dsmavgflt_init(filter_instance, ts);
		}

		const float output_value = dsmavgflt_process(filter_instance, input, period);

		const DSMAVGFLT_OUTPUT filter_output = {
			.dsmavg_output = output_value
		};
		return filter_output;
	}
	else {
		const DSMAVGFLT_OUTPUT empty_output = {
			0
		};
		return empty_output;
	}
}

