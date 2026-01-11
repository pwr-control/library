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

#include <sogi_flt.h>
#include <sogi_flt_simulink.h>
#include <math_f.h>

void sogi_flt_init(volatile SOGI_FLT *sogi_flt, volatile float ts, 
	volatile float omega, volatile float kepsilon)
{
	sogi_flt->ts = ts;
	sogi_flt->omega = omega;
	sogi_flt->kepsilon = kepsilon;
	sogi_flt_reset(sogi_flt);
}

void sogi_flt_reset(volatile SOGI_FLT *sogi_flt)
{
	sogi_flt->input = 0.0f;
	sogi_flt->alpha = 0.0f;
	sogi_flt->beta = 0.0f;
}

float sogi_flt_process(volatile SOGI_FLT *sogi_flt, float input) {

	const float sogi_output_alpha_dot = (input - sogi_flt->alpha) * sogi_flt->kepsilon - sogi_flt->beta;
	const float sogi_output_alpha = sogi_output_alpha_dot * sogi_flt->ts * sogi_flt->omega + sogi_flt->alpha;

	const float sogi_output_beta_dot = sogi_flt->alpha;
	const float sogi_output_beta = sogi_output_beta_dot * sogi_flt->ts * sogi_flt->omega + sogi_flt->beta;

	sogi_flt->alpha = sogi_output_alpha;
	sogi_flt->beta = sogi_output_beta;

	return sogi_output_alpha;
}


