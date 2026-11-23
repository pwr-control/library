/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Davide Bagnara
 */

#ifndef _SV_PWM_CM_
#define _SV_PWM_CM_

#include <math.h>
#include <math_f.h>

typedef struct sv_pwm_cm_s
{
	float	ts;
	float	ualpha; /* u_alpha */
	float 	ubeta;  /* u_beta */
	float 	ugamma;  /* u_beta */
	float	da;
	float	db;
	float	dc;
	unsigned int enable;
} sv_pwm_cm_t;

#define SVPWM_CM sv_pwm_cm_t

void sv_pwm_cm_process(SVPWM_CM *c);

#endif