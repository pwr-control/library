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

void phase_shift_flt_init(volatile PHASE_SHIFT_FLT *f)
{
	f->ts = 0.0;
	phase_shift_flt_reset(f);
}

void phase_shift_flt_ts(volatile PHASE_SHIFT_FLT *f, volatile float ts)
{
	f->ts = ts;
}

void phase_shift_flt_reset(volatile PHASE_SHIFT_FLT *f)
{
	int i;

}

float phase_shift_flt_process(volatile PHASE_SHIFT_FLT *f, float input, const float period)
{
	if (period > 0.0) {
		
		
		return filter_output;
	}
	else {
		return 0.0;
	}
}

