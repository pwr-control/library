%% Example
% 
% fpwm = 4e3;
% fpwm_afe = fpwm; % for PWM
% trgo_afe = 1; % double update
% fpwm_inv = 6 * fpwm; % for MPC
% trgo_inv = 0; % double update
% fpwm_single_phase_inv = fpwm;
% trgo_single_phase_inv = 1; % double update
% fpwm_dab = 3 * fpwm;
% trgo_dab = 0; % double update
% fpwm_psfbc = 3 * fpwm;
% trgo_psfbc = 0; % double update
% fpwm_isop_rail = 3 * fpwm;
% trgo_isop_rail = 0; % double update
% fpwm_cllc = 5 * fpwm;
% trgo_cllc = 0; % double update
% t_measure = 0.6;
% tc_factor = 100; % tc is ts_afe / tc_factor
% tc_decimation = 1;
% delay_pwm = 0;
% dead_time_afe = 0;
% dead_time_inv = 0;
% dead_time_single_phase_inv = 0;
% dead_time_dab = 2e-6;
% dead_time_psfbc = 3e-6;
% dead_time_isop_rail = 3e-6;
% dead_time_cllc = 2e-6;
% 
% glb_time = timing_setup(fpwm_afe, trgo_afe, fpwm_inv, trgo_inv, fpwm_single_phase_inv, trgo_single_phase_inv, ...
%                 fpwm_dab, trgo_dab, fpwm_psfbc, trgo_psfbc, fpwm_isop_rail, trgo_isop_rail, fpwm_cllc, trgo_cllc, ...
%                 t_measure, tc_factor, tc_decimation, delay_pwm, dead_time_afe, dead_time_inv, ...
%                 dead_time_single_phase_inv, dead_time_dab, dead_time_psfbc, dead_time_isop_rail, dead_time_cllc);



classdef timing_setup
    properties
        fPWM_AFE
        TRGO_AFE_double_update
        tPWM_AFE
        
        fPWM_INV
        TRGO_INV_double_update
        tPWM_INV
        
        fPWM_SINGLE_PHASE_INV
        TRGO_SINGLE_PHASE_INV_double_update
        tPWM_SINGLE_PHASE_INV

        fPWM_DAB
        TRGO_DAB_double_update
        tPWM_DAB
        
        fPWM_PSFBC
        TRGO_PSFBC_double_update
        tPWM_PSFBC

        fPWM_ISOP_RAIL
        TRGO_ISOP_RAIL_double_update
        tPWM_ISOP_RAIL

        fPWM_CLLC
        TRGO_CLLC_double_update
        tPWM_CLLC
        
        ts_afe
        ts_inv
        ts_single_phase_inv
        ts_dab
        ts_psfbc
        ts_isop_rail
        ts_cllc
        tc
        decimation_tc
        z_afe
        z_inv
        z_single_phase_inv
        z_dab
        z_psfbc
        z_isop_rail
        z_cllc

        dead_time_AFE
        dead_time_INV
        dead_time_SINGLE_PHASE_INV
        dead_time_DAB
        dead_time_PSFBC
        dead_time_ISOP_RAIL
        dead_time_CLLC

        minimum_pulse_time_AFE
        minimum_pulse_time_INV
        minimum_pulse_time_SINGLE_PHASE_INV
        minimum_pulse_time_DAB
        minimum_pulse_time_PSFBC
        minimum_pulse_time_ISOP_RAIL
        minimum_pulse_time_CLLC

        delayAFE_modB
        delayINV_modB

        t_measure
        Ns_afe
        Ns_inv
        Ns_single_phase_inv
        Ns_dab
        Ns_psfbc
        Ns_isop_rail
        Ns_cllc
        Nc
    end
    
    methods
        function obj = timing_setup(fpwm_afe, trgo_afe, fpwm_inv, trgo_inv, fpwm_single_phase_inv, trgo_single_phase_inv, fpwm_dab, trgo_dab, ...
                fpwm_psfbc, trgo_psfbc, fpwm_isop_rail, trgo_isop_rail, fpwm_cllc, trgo_cllc, t_measure, tc_factor, tc_decimation, delay_pwm, dead_time_afe, ...
                dead_time_inv, dead_time_single_phase_inv, dead_time_dab, dead_time_psfbc, dead_time_isop_rail, dead_time_cllc)
            if nargin > 0
                
                obj.fPWM_AFE = fpwm_afe;
                obj.tPWM_AFE = 1/obj.fPWM_AFE;
                obj.TRGO_AFE_double_update = trgo_afe;
                if obj.TRGO_AFE_double_update
                    obj.ts_afe = obj.tPWM_AFE/2;
                else
                    obj.ts_afe = obj.tPWM_AFE;
                end
                
                obj.fPWM_INV = fpwm_inv;
                obj.TRGO_INV_double_update = trgo_inv;
                obj.tPWM_INV = 1/obj.fPWM_INV;
                if obj.TRGO_INV_double_update
                    obj.ts_inv = obj.tPWM_INV/2;
                else
                    obj.ts_inv = obj.tPWM_INV;
                end

                obj.fPWM_SINGLE_PHASE_INV = fpwm_single_phase_inv;
                obj.TRGO_SINGLE_PHASE_INV_double_update = trgo_single_phase_inv;
                obj.tPWM_SINGLE_PHASE_INV = 1/obj.fPWM_SINGLE_PHASE_INV;
                if obj.TRGO_SINGLE_PHASE_INV_double_update
                    obj.ts_single_phase_inv = obj.tPWM_SINGLE_PHASE_INV/2;
                else
                    obj.ts_single_phase_inv = obj.tPWM_SINGLE_PHASE_INV;
                end

                obj.fPWM_DAB = fpwm_dab;
                obj.TRGO_DAB_double_update = trgo_dab;
                obj.tPWM_DAB = 1/obj.fPWM_DAB;
                if obj.TRGO_DAB_double_update
                    obj.ts_dab = obj.tPWM_DAB/2;
                else
                    obj.ts_dab = obj.tPWM_DAB;
                end
                
                obj.fPWM_PSFBC = fpwm_psfbc;
                obj.TRGO_PSFBC_double_update = trgo_psfbc;
                obj.tPWM_PSFBC = 1/obj.fPWM_PSFBC;
                if obj.TRGO_PSFBC_double_update
                    obj.ts_psfbc = obj.tPWM_PSFBC/2;
                else
                    obj.ts_psfbc = obj.tPWM_PSFBC;
                end

                obj.fPWM_ISOP_RAIL = fpwm_isop_rail;
                obj.TRGO_ISOP_RAIL_double_update = trgo_isop_rail;
                obj.tPWM_ISOP_RAIL = 1/obj.fPWM_ISOP_RAIL;
                if obj.TRGO_ISOP_RAIL_double_update
                    obj.ts_isop_rail = obj.tPWM_ISOP_RAIL/2;
                else
                    obj.ts_isop_rail = obj.tPWM_ISOP_RAIL;
                end

                obj.fPWM_CLLC = fpwm_cllc;
                obj.TRGO_CLLC_double_update = trgo_cllc;
                obj.tPWM_CLLC = 1/obj.fPWM_CLLC;
                if obj.TRGO_CLLC_double_update
                    obj.ts_cllc = obj.tPWM_CLLC/2;
                else
                    obj.ts_cllc = obj.tPWM_CLLC;
                end
                                
                obj.tc = obj.ts_afe/tc_factor;
                obj.decimation_tc = tc_decimation;

                obj.z_afe = tf('z',obj.ts_afe);
                obj.z_inv = tf('z',obj.ts_inv);
                obj.z_single_phase_inv = tf('z',obj.ts_single_phase_inv);
                obj.z_dab = tf('z',obj.ts_dab);
                obj.z_psfbc = tf('z',obj.ts_psfbc);
                obj.z_isop_rail = tf('z',obj.ts_isop_rail);
                obj.z_cllc = tf('z',obj.ts_cllc);
                
                obj.dead_time_AFE = dead_time_afe;
                obj.dead_time_INV = dead_time_inv;
                obj.dead_time_SINGLE_PHASE_INV = dead_time_single_phase_inv;
                obj.dead_time_DAB = dead_time_dab;
                obj.dead_time_PSFBC = dead_time_psfbc;
                obj.dead_time_ISOP_RAIL = dead_time_isop_rail;
                obj.dead_time_CLLC = dead_time_cllc;
                
                obj.minimum_pulse_time_AFE = 1e-6;
                obj.minimum_pulse_time_INV = 1e-6;
                obj.minimum_pulse_time_SINGLE_PHASE_INV = 1e-6;
                obj.minimum_pulse_time_DAB = 1e-6;
                obj.minimum_pulse_time_PSFBC = 1e-6;
                obj.minimum_pulse_time_ISOP_RAIL = 1e-6;
                obj.minimum_pulse_time_CLLC = 1e-6;
                
                obj.delayAFE_modB = 2*pi*obj.fPWM_AFE*delay_pwm; 
                obj.delayINV_modB = 2*pi*obj.fPWM_INV*delay_pwm;
                              
                obj.t_measure = t_measure;
                obj.Nc = ceil(obj.t_measure/obj.tc/obj.decimation_tc);
                obj.Ns_afe = ceil(obj.t_measure/obj.ts_afe);
                obj.Ns_inv = ceil(obj.t_measure/obj.ts_inv);
                obj.Ns_single_phase_inv = ceil(obj.t_measure/obj.ts_single_phase_inv);
                obj.Ns_dab = ceil(obj.t_measure/obj.ts_dab);
                obj.Ns_psfbc = ceil(obj.t_measure/obj.ts_psfbc);
                obj.Ns_isop_rail = ceil(obj.t_measure/obj.ts_isop_rail);
                obj.Ns_cllc = ceil(obj.t_measure/obj.ts_cllc);

            end
        end
    end
end