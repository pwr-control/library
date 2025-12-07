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



#include <dqvector_pi.h>
#include <dqvector_pi_simulink.h>

unsigned int dqpi_ctrl_initialized = 0;
DQVECTOR_PI dqpi_ctrl = {0.0};

// ------------------------------------------------------------------------------
DQVECTOR_PI_OUTPUT dqvector_pi_process_simulink(unsigned char reset, const float id_ref, const float id, 
		const float iq_ref, const float iq, const float u_dc, const float ts, 
		const float kp_id, const float ki_id, const float kp_iq, const float ki_iq, 
		const float u_lim)
{

	if (dqpi_ctrl_initialized == 0) {
	    dqvector_pi_init(&dqpi_ctrl, kp_id, ki_id, kp_iq, ki_iq, u_lim);
		dqpi_ctrl_initialized = 1;
	}

	dqvector_pi_ts(&dqpi_ctrl, ts);

	if (reset) {
		dqvector_pi_reset(&dqpi_ctrl);
	}
	
	VECTORDQ udq_out = dqvector_pi_process(&dqpi_ctrl, id_ref, id, iq_ref, iq, u_dc);

	const DQVECTOR_PI_OUTPUT dqvector_pi_output = {
		.ud = udq_out.d,
		.uq = udq_out.q
	};
	
	return dqvector_pi_output;
}

