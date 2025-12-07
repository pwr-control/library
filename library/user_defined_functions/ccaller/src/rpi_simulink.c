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

#include <rpi.h>
#include <rpi_simulink.h>

unsigned int rpi_ctrl_initialized = 0;
RPI rpi_ctrl;

// ------------------------------------------------------------------------------
rpi_output_t rpi_process_simulink(unsigned char reset, const float i_ref, const float i, 
		const float u_dc, const float ts, const float kp_rpi, const float ki_rpi, 
		const float omega, const float delta, const float u_lim) {

	if (rpi_ctrl_initialized == 0) {
	    rpi_init(&rpi_ctrl, ts, kp_rpi, ki_rpi, omega, delta, u_lim);
		rpi_ctrl_initialized = 1;
	}

	if (reset) {
		rpi_reset(&rpi_ctrl);
	}

	rpi_output_t rpi_output;
	rpi_output.u_out = rpi_process(&rpi_ctrl, i_ref, i, u_dc);
	
	return rpi_output;
}

