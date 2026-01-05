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

#include <linear_double_integrator_observer.h>
#include <linear_double_integrator_observer_simulink.h>
#include <math_f.h>

void linear_double_integrator_observer_init(volatile LINEAR_DOUBLE_INTEGRATOR_OBSVR *obsv, volatile float ts, 
	volatile float kx, volatile float kv)
{
	obsv->ts = ts;
	obsv->kx = kx;
	obsv->kv = kv;
	obsv->state_observer_x = 0.0f;
	obsv->state_observer_v = 0.0f;
}

float linear_double_integrator_observer_process(volatile LINEAR_DOUBLE_INTEGRATOR_OBSVR *obsv, float input)
{
	const float x_hat_hat = obsv->state_observer_x + obsv->state_observer_v * obsv->ts + 
					obsv->ts * obsv->kx * (input - obsv->state_observer_x);
	const float v_hat_hat = obsv->state_observer_v +
					obsv->ts * obsv->kv * (input - obsv->state_observer_x);
	
	obsv->state_observer_x = x_hat_hat;
	obsv->state_observer_v = v_hat_hat;
	
	return obsv->state_observer_x;
}

