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


#include <sv_pwm_simulink.h>
#include <sv_pwm.h>

// ------------------------------------------------------------------------------
SV_PWM_OUTPUT sv_pwm_process_simulink(const float ualpha, const float ubeta, const float ts,
					unsigned int enable)
{
	static SVPWM ctrl = {0};

	ctrl.ualpha = ualpha;
	ctrl.ubeta = ubeta;
	ctrl.ts = ts;
	ctrl.enable = enable;

    sv_pwm_process(&ctrl);

	const SV_PWM_OUTPUT ctrl_out = {
		.da = ctrl.da,
		.db = ctrl.db,
		.dc = ctrl.dc
	};
	return ctrl_out;
}
