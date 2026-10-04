/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

/* Twelve pulses rectifier */

#ifndef _TWVPRCTRL_
#define _TWVPRCTRL_

#include <math.h>
#include <math_f.h>
#define PWIDTH_PU  (1.047197551196598f)   /* pulse width [rad], ~60 deg */


typedef struct twvprctrl_s {
    float ramp_d_1;
    float ramp_d_2;
    float ramp_d_3;
    float ramp_d_4;
    float ramp_d_5;
    float ramp_d_6;  
    float ramp_y_1;
    float ramp_y_2;
    float ramp_y_3;
    float ramp_y_4;
    float ramp_y_5;
    float ramp_y_6;  
	int synch_dA1;
	int synch_dA2;
	int synch_dA3;
	int synch_dA4;
	int synch_dA5;
	int synch_dA6;	
	int synch_dB1;
	int synch_dB2;
	int synch_dB3;
	int synch_dB4;
	int synch_dB5;
	int synch_dB6;
	/* pulse-width thresholds [rad]: float, an int truncates alpha + PWIDTH_PU */
	float synch_d1;
	float synch_d2;
	float synch_d3;
	float synch_d4;
	float synch_d5;
	float synch_d6;
	
	int synch_yA1;
	int synch_yA2;
	int synch_yA3;
	int synch_yA4;
	int synch_yA5;
	int synch_yA6;	
	int synch_yB1;
	int synch_yB2;
	int synch_yB3;
	int synch_yB4;
	int synch_yB5;
	int synch_yB6;
	/* pulse-width thresholds [rad]: float, an int truncates alpha + PWIDTH_PU */
	float synch_y1;
	float synch_y2;
	float synch_y3;
	float synch_y4;
	float synch_y5;
	float synch_y6;
} twvprctrl_t;
#define TWVPRCTRL twvprctrl_t

typedef struct twvpr_pd_s {
	int pd_1;
	int pd_2;
	int pd_3;
	int pd_4;
	int pd_5;
	int pd_6;
}  twvpr_pd_t;
#define TWVPR_PD twvpr_pd_t

typedef struct twvpr_py_s {
	int py_1;
	int py_2;
	int py_3;
	int py_4;
	int py_5;
	int py_6;
} twvpr_py_t;
#define TWVPR_PY twvpr_py_t

void twvprProcess(TWVPRCTRL *twvpr, const float wt, const float alpha, 
	const int block, TWVPR_PY *py, TWVPR_PD *pd);

void twvprProcessSimulink(const float wt, const float alpha, const int block, TWVPR_PY *py, TWVPR_PD *pd);

#endif
