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


#include <first_harmonic_tracker.h>
#include <first_harmonic_tracker_simulink.h>

// ------------------------------------------------------------------------------
static void init_allfht_instances(FIRST_HARMONIC_TRACKER *const fht_list, const unsigned int fht_num, 
	const float ts,const float omega_base, const float delta, const float l1, const float l2)
{
   /* issue - instance number in simulink at step of two : 0, 2, 4, 6, 8 - double FHTI_N than expected */
	unsigned int i;
    for (i = 0; i < fht_num; ++i) {
        FIRST_HARMONIC_TRACKER *const fht_i = &fht_list[i];
		first_harmonic_tracker_init(fht_i, ts, omega_base, delta,l1, l2);
		i++;
	}
}

// ------------------------------------------------------------------------------
FIRST_HARMONIC_TRACKER_OUTPUT first_harmonic_tracker_process_simulink(const unsigned char reset, const float u, const float ts, 
	const float omega_base, const float delta, const float l1, const float l2,const unsigned char instance)
{

	static FIRST_HARMONIC_TRACKER fht_i[FIRST_HARMONIC_TRACKER_INSTANCES] = {0};
	static unsigned int fht_init = 0;

	if (!fht_init) {
	    init_allfht_instances(fht_i, FIRST_HARMONIC_TRACKER_INSTANCES, ts, omega_base, delta, l1, l2);
		fht_init = 1;
	}

	const FIRST_HARMONIC_TRACKER* fht_instance = &fht_i[instance];
	
	if (reset) {
		first_harmonic_tracker_ts(fht_instance, ts);
		first_harmonic_tracker_reset(fht_instance);
	}
	
	const float output_value = first_harmonic_tracker_process(fht_instance, u);

	const FIRST_HARMONIC_TRACKER_OUTPUT output = {
		.output_pu_hat_dot = fht_instance->first_harmonic_tracker_state2,
		.output_pu_hat = output_value
	};
	return output;
}

