/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) 2025 Davide Bagnara
 */

#ifndef __SOGI_FLT__
#define __SOGI_FLT__

typedef struct sogi_flt_s {
	float								ts;					/* sampling time */
	float								kepsilon;			/* gain */
	float								omega;				/* omega */
	float								input;				/* input z^-1 */
	float								alpha;				/* alpha */
	float								beta;				/* beta */
} sogi_flt_t;

#define SOGI_FLT sogi_flt_t

void sogi_flt_init(volatile SOGI_FLT *sogi_flt, volatile float ts, volatile float omega, volatile float kepsilon);

void sogi_flt_reset(volatile SOGI_FLT *sogi_flt);

float sogi_flt_process(volatile SOGI_FLT *sogi_flt, float input);

#endif
