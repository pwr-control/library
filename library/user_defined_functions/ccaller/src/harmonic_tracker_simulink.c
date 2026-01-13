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


#include <harmonic_tracker.h>
#include <harmonic_tracker_simulink.h>

// ------------------------------------------------------------------------------
static void init_allht_instances(HARMONIC_TRACKER *const ht_list, const unsigned int ht_num, 
	const float omega_base, const float delta, const float l1, const float l2)
{
   /* issue - instance number in simulink at step of two : 0, 2, 4, 6, 8 - double HTI_N than expected */
	unsigned int i;
    for (i = 0; i < ht_num; ++i) {
        HARMONIC_TRACKER *const ht_i = &ht_list[i];
		harmonic_tracker_init(ht_i, omega_base, delta,l1, l2);
		i++;
	}
}

// ------------------------------------------------------------------------------
HARMONIC_TRACKER_OUTPUT harmonic_tracker_process_simulink(const unsigned char reset, const float u, const float ts, 
	const float omega_base, const float delta, const float l1, const float l2,const unsigned char instance)
{

	static HARMONIC_TRACKER ht_i[HARMONIC_TRACKER_INSTANCES] = {0};
	static unsigned int ht_init = 0;

	if (!ht_init) {
	    init_allht_instances(ht_i, HARMONIC_TRACKER_INSTANCES, omega_base, delta, l1, l2);
		ht_init = 1;
	}

	const HARMONIC_TRACKER* ht_instance = &ht_i[instance];
	
	if (reset) {
		harmonic_tracker_ts(ht_instance, ts);
		harmonic_tracker_reset(ht_instance);
	}

	const float output_value = harmonic_tracker_process(ht_instance, u);

	const HARMONIC_TRACKER_OUTPUT output = {
		.output_pu_hat_dot = ht_instance->harmonic_tracker_state2,
		.output_pu_hat = output_value
	};
	return output;
}

