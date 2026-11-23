/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Davide Bagnara
 */

#ifndef _SV_PWM_CM_SIMULINK_
#define _SV_PWM_CM_SIMULINK_

typedef struct sv_pwm_cm_output_s {
	float	da;
	float	db;
	float	dc;
} sv_pwm_cm_output_t;
#define SV_PWM_CM_OUTPUT sv_pwm_cm_output_t

SV_PWM_CM_OUTPUT sv_pwm_cm_process_simulink(const float ualpha, const float ubeta, 
	const float ugamma, const float ts, unsigned int enable);

#endif