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

#include <mavgflts.h>

void mavgflts_init(volatile MAVGFLTS *f, volatile float ts)
{
	int i;
	f->ts = ts;

	f->pinput = 0.0;
	f->sum_value = 0.0;
	f->cbpointer = 0;
	f->cbsample = 0;
	for (i = 0; i < MAVGFLTS_SIZE_MAX; i++) {
		f->buffer[i] = 0.0;
	}
}

// ------------------------------------------------------------------------------
// Get buffer pointer	
static unsigned int get_buffer_pointer(const unsigned int cbpointer, const unsigned int cnperiod)
{
	if (cnperiod <= cbpointer) {
		return cbpointer - cnperiod;
	}
	else {
		return cbpointer - cnperiod + MAVGFLTS_SIZE_MAX;
	}
}

// ------------------------------------------------------------------------------
static float get_buffer_value(const MAVGFLTS * const f, const unsigned int cnperiod)
{
	const unsigned int current_nperiod = get_buffer_pointer(f->cbpointer, cnperiod);
	return f->buffer[current_nperiod];
}

float mavgflts_process(volatile MAVGFLTS *f, float input, const float period)
{
	if (period > 0.0) {
		
		unsigned int samples_requested = floor(period / f->ts);
		
		if (samples_requested > MAVGFLTS_SIZE_MAX - 1)
		    samples_requested = MAVGFLTS_SIZE_MAX - 1;
		
		const unsigned int cnbuffer = samples_requested + 1;
		
		if (cnbuffer > f->cbsample) {
			f->sum_value += f->pinput;
			f->cbsample++;
		}
		else if (cnbuffer < f->cbsample) {
			const unsigned int decremented_cbsample = f->cbsample - 1;
			const float two_oldest_samples = get_buffer_value((MAVGFLTS*) f, f->cbsample)
												+ get_buffer_value((MAVGFLTS*) f, decremented_cbsample);

			f->sum_value += f->pinput - two_oldest_samples;
					
			f->cbsample = decremented_cbsample;
		}
		else {
			const float oldest_period_sample = get_buffer_value((MAVGFLTS*) f, f->cbsample);
			
			f->sum_value += f->pinput - oldest_period_sample;
		}
		
		f->buffer[f->cbpointer] = input;

		f->cbpointer++;
		
		f->pinput = input;

		if (f->cbpointer == MAVGFLTS_SIZE_MAX) {
			f->cbpointer = 0;
		}

		const float filter_output = f->sum_value / f->cbsample;
		
		return filter_output;
	}
	else {
		return 0.0;
	}
}

