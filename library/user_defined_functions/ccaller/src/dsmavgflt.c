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

void dsmavgflt_init(volatile DSMAVGFLT *f, volatile float ts) {
	int i;
	f->ts = ts;

	f->sum_value = 0.0;
	f->idx = 0;
	f->length_period = DSMAVGFLT_SIZE_MAX;
	for (i = 0; i < DSMAVGFLT_SIZE_MAX; i++) {
		f->buffer[i] = 0.0;
	}
}

// ------------------------------------------------------------------------------

float dsmavgflt_process(volatile DSMAVGFLT *f, float input, const float period) {

    f->length_period = floorf(period / f->ts);
    if (f->length_period < 1) f->length_period = DSMAVGFLT_SIZE_MAX;
    if (f->length_period > DSMAVGFLT_SIZE_MAX) f->length_period = DSMAVGFLT_SIZE_MAX;

    unsigned int old_idx = (f->idx + DSMAVGFLT_SIZE_MAX - f->length_period) % DSMAVGFLT_SIZE_MAX;
    float xn = f->buffer[old_idx];

    f->sum_value = f->sum_value - xn + input;
    f->buffer[f->idx] = input;

    float filter_output = f->sum_value / f->length_period;

    f->idx = (f->idx + 1) % DSMAVGFLT_SIZE_MAX;

    return filter_output;
}


