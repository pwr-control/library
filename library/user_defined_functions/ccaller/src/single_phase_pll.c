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

void sogi_flt_init(volatile SOGI_FLT *flt, volatile float ts, 
	volatile float fcut)
{
	flt->ts = ts;
	flt->fcut = fcut;
	flt->a1 = A1;
	flt->a2 = A2;
	flt->b1_alpha = B1_ALPHA;
	flt->b2_alpha = B2_ALPHA;
	flt->b1_beta = B1_BETA;
	flt->b2_beta = B2_BETA;
	sogi_flt_reset(flt);
}

void sogi_flt_reset(volatile SOGI_FLT *flt)
{
	flt->input = 0.0f;
	flt->input_1 = 0.0f;	
	flt->input_2 = 0.0f;
	flt->output_alpha = 0.0f;
	flt->output_alpha_1 = 0.0f;
	flt->output_alpha_2 = 0.0f;
	flt->output_beta = 0.0f;
	flt->output_beta_1 = 0.0f;
	flt->output_beta_2 = 0.0f;
}
float sogi_flt_process(volatile SOGI_FLT *flt, float input) {

	const float sogi_output_alpha = flt->b1_alpha * flt->input_1 + 
		flt->b2_alpha * flt->input_2 - flt->a1 * flt->output_alpha_1 - 
		flt->a2 * flt->output_alpha_2;

	const float sogi_output_beta = flt->b1_beta * flt->input_1 + 
		flt->b2_beta * flt->input_2 - flt->a1 * flt->output_beta_1 - 
		flt->a2 * flt->output_beta_2;

	flt->input_2 = flt->input_1;
	flt->input_1 = input;
	flt->output_alpha_2 = flt->output_alpha_1;
	flt->output_alpha_1 = sogi_output_alpha;
	flt->output_beta_2 = flt->output_beta_1;
	flt->output_beta_1 = sogi_output_beta;

	flt->output_alpha = sogi_output_alpha;
	flt->output_beta = sogi_output_beta;

	return sogi_output_alpha;
}


