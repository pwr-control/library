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


#include <sv_pwm_cm.h>

void sv_pwm_cm_process(SVPWM_CM *c)
{
	float t1 = MATH_NULL;
	float t2 = MATH_NULL;
	float t0 = MATH_NULL;
	float angle = MATH_NULL;
	
	const float tbpwm = MATH_1;

    // Calcolo dell'offset per il controllo di modo comune
    // k_offset = 0.5 (SVPWM standard), 0.0 (solo V0), 1.0 (solo V7)
    float k_offset = (c->ugamma + MATH_1) * MATH_HALF;
    float common_offset = 0; 

	if (c->enable)
	{
    	angle = atan2f(c->ubeta,c->ualpha);

	    if ((angle >= MATH_NULL) && (angle <= MATH_PI_3)) {
	    	/* sector1 (counterclockwise) */
	    	t2 = c->ubeta * MATH_2_SQRT3; // v2
			t1 = c->ualpha - c->ubeta * MATH_1_SQRT3; // v1
			t0 = MATH_1 - t2 - t1;
			/* management of the overmudulation */
			if (t0 < 0) {
                /* Invece di t0 * MATH_HALF, usiamo il k_offset di controllo */
                common_offset = t0 * k_offset; 
                c->da = common_offset;            // Inizio del primo vettore attivo
                c->db = t1 * tbpwm + c->da;       // Fine del primo / Inizio del secondo
                c->dc = t2 * tbpwm + c->db;       // Fine del secondo
				}
        	else {
				c->da = t0 * tbpwm * k_offset;
				c->db = t1 * tbpwm + c->da;
				c->dc = t2 * tbpwm + c->db;
			}

		}

	    else if ((angle >= MATH_PI_3) && (angle <= MATH_2PI_3)) {
	        /* sector2 (clockwise) */
	        t1 = -c->ualpha + c->ubeta * MATH_1_SQRT3; // v3
	        t2 = c->ualpha + c->ubeta * MATH_1_SQRT3; // v2
	        t0 = MATH_1 - t2 - t1;
			/* management of the overmudulation */
			if (t0 < 0) {
                /* Invece di t0 * MATH_HALF, usiamo il k_offset di controllo */
                common_offset = t0 * k_offset; 
                c->db = common_offset;            // Inizio del primo vettore attivo
                c->da = t1 * tbpwm + c->db;       // Fine del primo / Inizio del secondo
                c->dc = t2 * tbpwm + c->da;       // Fine del secondo
				}
        	else {
				c->db = t0 * tbpwm * k_offset;
				c->da = t1 * tbpwm + c->db;
				c->dc = t2 * tbpwm + c->da;
			}
	    }

	    else if ((angle >= MATH_2PI_3) && (angle <= MATH_PI)) {
	        /* sector3 (counterclockwise) */
	        t2 = -c->ubeta * MATH_1_SQRT3 - c->ualpha; // v4
	        t1 = c->ubeta * MATH_2_SQRT3; //v3
	        t0 = MATH_1 - t2 - t1;
			/* management of the overmudulation */
			if (t0 < 0) {
                /* Invece di t0 * MATH_HALF, usiamo il k_offset di controllo */
                common_offset = t0 * k_offset; 
                c->db = common_offset;            // Inizio del primo vettore attivo
                c->dc = t1 * tbpwm + c->db;       // Fine del primo / Inizio del secondo
                c->da = t2 * tbpwm + c->dc;       // Fine del secondo
				}
        	else {
				c->db = t0 * tbpwm * k_offset;
				c->dc = t1 * tbpwm + c->db;
				c->da = t2 * tbpwm + c->dc;
			}
	    }

	    else if ((angle >= -MATH_PI) && (angle <= -MATH_2PI_3)) {
	        /* sector4 (clockwise) */
	        t1 = -MATH_2_SQRT3 * c->ubeta; //v5
	        t2 = c->ubeta * MATH_1_SQRT3 - c->ualpha; //v4
	        t0 = MATH_1 - t2 - t1;
			/* management of the overmudulation */
			if (t0 < 0) {
                /* Invece di t0 * MATH_HALF, usiamo il k_offset di controllo */
                common_offset = t0 * k_offset; 
                c->dc = common_offset;            // Inizio del primo vettore attivo
                c->db = t1 * tbpwm + c->dc;       // Fine del primo / Inizio del secondo
                c->da = t2 * tbpwm + c->db;       // Fine del secondo
				}
        	else {
				c->dc = t0 * tbpwm * k_offset;
				c->db = t1 * tbpwm + c->dc;
				c->da = t2 * tbpwm + c->db;
			}
	    }

	    else if ((angle >= -MATH_2PI_3) && (angle <= -MATH_PI_3)) {
	        /* sector5 (counterclockwise) */
	        t2 = c->ualpha - c->ubeta * MATH_1_SQRT3; 	// v6
	        t1 = -c->ualpha - c->ubeta * MATH_1_SQRT3; 	// v5
	        t0 = MATH_1 - t2 - t1;
			/* management of the overmudulation */
			if (t0 < 0) {
                /* Invece di t0 * MATH_HALF, usiamo il k_offset di controllo */
                common_offset = t0 * k_offset; 
                c->dc = common_offset;            // Inizio del primo vettore attivo
                c->da = t1 * tbpwm + c->dc;       // Fine del primo / Inizio del secondo
                c->db = t2 * tbpwm + c->da;       // Fine del secondo
				}
        	else {
				c->dc = t0 * tbpwm * k_offset;
				c->da = t1 * tbpwm + c->dc;
				c->db = t2 * tbpwm + c->da;
			}
	    }

	    /* else ((angle >= -MATH_PI_3) && (angle <= MATH_NULL)) { */
	    else  {
	        /* sector6 (clockwise) */
	        t1 = c->ualpha + c->ubeta * MATH_1_SQRT3; // v1
	        t2 = -c->ubeta * MATH_2_SQRT3; // v6
	        t0 = MATH_1 - t2 - t1;
			/* management of the overmudulation */
			if (t0 < 0) {
                /* Invece di t0 * MATH_HALF, usiamo il k_offset di controllo */
                common_offset = t0 * k_offset; 
                c->da = common_offset;            // Inizio del primo vettore attivo
                c->dc = t1 * tbpwm + c->da;       // Fine del primo / Inizio del secondo
                c->db = t2 * tbpwm + c->dc;       // Fine del secondo
				}
        	else {
				c->da = t0 * tbpwm * k_offset;
				c->dc = t1 * tbpwm + c->da;
				c->db = t2 * tbpwm + c->dc;
			}
	    }
	}
	else
	{
		c->da = MATH_HALF * tbpwm;
		c->db = MATH_HALF * tbpwm;
		c->dc = MATH_HALF * tbpwm;
	}

}

	