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


#include <adv_speed_ctrl_pisfle.h>
#include <adv_speed_ctrl_pisfle_simulink.h>

ADV_SPEED_CTRL_PISFLE    adv_speed_ctrl_pisfle             = {0.0F};
unsigned int      adv_speed_ctrl_pisfle_initialized      = 0;

// ------------------------------------------------------------------------------
ADV_SPEED_CTRL_PISFLE_OUTPUT adv_speed_ctrl_pisfle_process_simulink(
    unsigned char   reset,
    const float     ts, 
	const float     omega_m_pu_ref, 
    const float     omega_m_pu, 
    const float     torque_m_pu, 
    const float     torque_nom, 
    const float     omega_nom, 
    const float     inertia_m, 
    const float     inertia_l, 
    const float     young_module_rope, 
    const float     viscosity_m, 
    const float     viscosity_l, 
    const float     viscosity_theta,
    const float     torque_m_pu_lim, 
    const float     kp,
    const float     ki,
    const float     k_isf_1,
    const float     k_isf_2,
    const float     k_isf_3,
    const float     k_isf_4,
    const float     l_sobs_1,
    const float     l_sobs_2,
    const float     l_sobs_3,
    const float     l_sobs_4
)
{

	if (!adv_speed_ctrl_pisfle_initialized) {
		adv_speed_ctrl_pisfle_init(&adv_speed_ctrl_pisfle, ts, omega_nom, torque_nom, inertia_m, inertia_l, 
			young_module_rope, viscosity_m, viscosity_l, viscosity_theta, torque_m_pu_lim, kp, ki, k_isf_1, k_isf_2, 
			k_isf_3, k_isf_4, l_sobs_1, l_sobs_2, l_sobs_3, l_sobs_4
		);
		adv_speed_ctrl_pisfle_initialized = 1;
	}

	adv_speed_ctrl_pisfle_ts(&adv_speed_ctrl_pisfle, ts);

	if (reset) {
		adv_speed_ctrl_pisfle_init(&adv_speed_ctrl_pisfle, ts, omega_nom, torque_nom, inertia_m, inertia_l, 
			young_module_rope, viscosity_m, viscosity_l, viscosity_theta, torque_m_pu_lim, kp, ki, k_isf_1, k_isf_2, 
			k_isf_3, k_isf_4, l_sobs_1, l_sobs_2, l_sobs_3, l_sobs_4
		);
		adv_speed_ctrl_pisfle_ts(&adv_speed_ctrl_pisfle, ts);
		adv_speed_ctrl_pisfle_reset(&adv_speed_ctrl_pisfle);
	}
	const float torque_output_ref_pu = adv_speed_ctrl_pisfle_process(&adv_speed_ctrl_pisfle, omega_m_pu_ref, omega_m_pu);
	
	const ADV_SPEED_CTRL_PISFLE_OUTPUT advanced_speed_ctrl_pisfle_output = {
				.torque_output_ref_pu = adv_speed_ctrl_pisfle.torque_output_ctrl_pu,
				.omega_m_pu_hat = adv_speed_ctrl_pisfle.omega_m_pu_hat,
				.omega_l_pu_hat = adv_speed_ctrl_pisfle.omega_l_pu_hat,
				.torque_theta_pu_hat = adv_speed_ctrl_pisfle.torque_theta_pu_hat,
				.torque_l_pu_hat = adv_speed_ctrl_pisfle.torque_l_pu_hat
	};

	return advanced_speed_ctrl_pisfle_output;
}

