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

void harmonic_tracker_init(volatile HARMONIC_TRACKER *f,const float omega_base, const float delta, const float l1, const float l2)
{
	f->ts = 0.0F;
	f->harmonic_tracker_l1 = l1;
	f->harmonic_tracker_l2 = l2;
	f->harmonic_tracker_A11 = HARMONIC_TRACKER_A11;
	f->harmonic_tracker_A12 = HARMONIC_TRACKER_A12;
	f->harmonic_tracker_A21 = -omega_base*omega_base;
	f->harmonic_tracker_A22 = -delta*omega_base;
	f->harmonic_tracker_C1 = HARMONIC_TRACKER_C1;
	harmonic_tracker_reset(f);
}

void harmonic_tracker_reset(volatile HARMONIC_TRACKER *f)
{
	f->harmonic_tracker_error = 0.0f;
	f->harmonic_tracker_state1 = 0.0f;
	f->harmonic_tracker_state2 = 0.0f;
	f->harmonic_tracker_output = 0.0f;
}

void harmonic_tracker_ts(volatile HARMONIC_TRACKER *f, volatile float ts)
{
	f->ts = ts;
}

float harmonic_tracker_process(volatile HARMONIC_TRACKER *f, const float u)
{
	const float harmonic_tracker_ld1 = f->harmonic_tracker_l1;
	const float harmonic_tracker_ld2 = f->harmonic_tracker_l2;
	const float harmonic_tracker_Ad11 = 1.0F + f->harmonic_tracker_A11 * f->ts;
	const float harmonic_tracker_Ad12 = f->harmonic_tracker_A12 * f->ts;
	const float harmonic_tracker_Ad21 = f->harmonic_tracker_A21 * f->ts;
	const float harmonic_tracker_Ad22 = 1.0F + f->harmonic_tracker_A22 * f->ts;

	const float harmonic_tracker_output = f->harmonic_tracker_output;
	const float error = u - harmonic_tracker_output;
	const float stat1 = harmonic_tracker_ld1 * error + harmonic_tracker_Ad11 * f->harmonic_tracker_state1 + harmonic_tracker_Ad12 * f->harmonic_tracker_state2;
	const float stat2 = harmonic_tracker_ld2 * error + harmonic_tracker_Ad21 * f->harmonic_tracker_state1 + harmonic_tracker_Ad22 * f->harmonic_tracker_state2;

	f->harmonic_tracker_output = f->harmonic_tracker_state1 * f->harmonic_tracker_C1;
	f->harmonic_tracker_state1 = stat1;
	f->harmonic_tracker_state2 = stat2;

	return f->harmonic_tracker_output;
}

