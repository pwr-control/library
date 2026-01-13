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

void first_harmonic_tracker_init(volatile FIRST_HARMONIC_TRACKER *f, volatile float ts, const float omega_base, 
	const float delta, const float l1, const float l2) {

	const float a = -omega_base*omega_base;
	const float b = -delta*omega_base;

	f->ts = ts;
	f->first_harmonic_tracker_l1 = l1;
	f->first_harmonic_tracker_l2 = l2;
	f->first_harmonic_tracker_a11 = 1.0f + 0.5f*a*ts*ts;
	f->first_harmonic_tracker_a12 = ts + 0.5f*b*ts*ts;
	f->first_harmonic_tracker_a21 = a*ts + 0.5f*a*b*ts*ts;
	f->first_harmonic_tracker_a22 = 1.0f + b*ts + 0.5f*(a+b*b)*ts*ts;
	f->first_harmonic_tracker_c1 = 1.0f;
	first_harmonic_tracker_reset(f);
}

void first_harmonic_tracker_reset(volatile FIRST_HARMONIC_TRACKER *f)
{
	f->first_harmonic_tracker_error = 0.0f;
	f->first_harmonic_tracker_state1 = 0.0f;
	f->first_harmonic_tracker_state2 = 0.0f;
	f->first_harmonic_tracker_output = 0.0f;
}

void first_harmonic_tracker_ts(volatile FIRST_HARMONIC_TRACKER *f, volatile float ts)
{
	f->ts = ts;
}

float first_harmonic_tracker_process(volatile FIRST_HARMONIC_TRACKER *f, const float u)
{
	const float first_harmonic_tracker_ld1 = f->first_harmonic_tracker_l1;
	const float first_harmonic_tracker_ld2 = f->first_harmonic_tracker_l2;
	const float first_harmonic_tracker_ad11 = f->first_harmonic_tracker_a11;
	const float first_harmonic_tracker_ad12 = f->first_harmonic_tracker_a12;
	const float first_harmonic_tracker_ad21 = f->first_harmonic_tracker_a21;
	const float first_harmonic_tracker_ad22 = f->first_harmonic_tracker_a22;

	const float first_harmonic_tracker_output = f->first_harmonic_tracker_output;
	const float error = u - first_harmonic_tracker_output;
	const float state1 = first_harmonic_tracker_ld1 * error + first_harmonic_tracker_ad11 * 
			f->first_harmonic_tracker_state1 + first_harmonic_tracker_ad12 * 
			f->first_harmonic_tracker_state2;
	const float state2 = first_harmonic_tracker_ld2 * error + first_harmonic_tracker_ad21 * 
			f->first_harmonic_tracker_state1 + first_harmonic_tracker_ad22 * 
			f->first_harmonic_tracker_state2;

	f->first_harmonic_tracker_output = f->first_harmonic_tracker_state1 * f->first_harmonic_tracker_c1;
	f->first_harmonic_tracker_state1 = state1;
	f->first_harmonic_tracker_state2 = state2;

	return f->first_harmonic_tracker_output;
}

