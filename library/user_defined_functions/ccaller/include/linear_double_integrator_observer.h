/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef _LINEAR_DOUBLE_INTEGRATOR_OBSVR_
#define _LINEAR_DOUBLE_INTEGRATOR_OBSVR_

typedef struct linear_double_integrator_observer_s {
	float					ts;						/* sampling time */
	float					kx;						/* filter coefficient a */
	float					kv;						/* filter coefficient b */
	float					state_observer_x;		/* input z^-1 */
	float					state_observer_v;		/* output z^-1 */
} linear_double_integrator_observer_t;

#define LINEAR_DOUBLE_INTEGRATOR_OBSVR linear_double_integrator_observer_t
void linear_double_integrator_observer_init(volatile LINEAR_DOUBLE_INTEGRATOR_OBSVR *observer, volatile float ts, volatile float kx, volatile float kv);

float linear_double_integrator_observer_process(volatile LINEAR_DOUBLE_INTEGRATOR_OBSVR *observer, float input);

#endif
