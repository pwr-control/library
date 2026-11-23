
%% Extended Kalman Filter for PSM Observer

        %% example of application
        % psm_ctrl.ekf = ekf_pmsm_setup(psm.Rs_norm, psm.Ls_norm, psm.Jm_norm, glb_time.ts_inv);

classdef ekf_pmsm_setup
    properties
        A_tilde_ekf
        A1_tilde_ekf
        A2_tilde_ekf
        A3_tilde_ekf
        A4_tilde_ekf
        A5_tilde_ekf
        A6_tilde_ekf
        B_tilde_ekf
        C_ekf
        Bd_ekf
        Qkalman
        Rkalman
        k_kalman
        k_dc
        k_sw
        
        Rs_norm_ekf
        Lalpha_norm_ekf
        Lbeta_norm_ekf
        ts
    end
    
    methods
        function obj = ekf_pmsm_setup(rs, ls, jm, ts)
            if nargin > 0
                obj.Rs_norm_ekf = rs;
                obj.Lalpha_norm_ekf = ls;
                obj.Lbeta_norm_ekf = ls;
                obj.ts = ts;
                
                
                obj.A1_tilde_ekf = [-rs/ls 0 0 0 0 0; ...
                                    0 -rs/ls 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 0 -1/jm; ...
                                    0 0 0 0 0 0];
                
                obj.A2_tilde_ekf = [0 0 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 -1/jm 0 0; ...
                                    0 0 0 0 0 0];
                
                obj.A3_tilde_ekf = [0 0 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 1/jm 0 0 0; ...
                                    0 0 0 0 0 0];

                obj.A4_tilde_ekf = [0 0 0 0 0 0; ...
                                    0 0 0 0 -1/ls 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 1 0; ...
                                    0 1/jm 0 0 0 0; ...
                                    0 0 0 0 0 0];
                
                obj.A5_tilde_ekf = [0 0 0 0 1/ls 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 -1 0; ...
                                    0 0 0 0 0 0; ...
                                    -1/jm 0 0 0 0 0; ...
                                    0 0 0 0 0 0];

                obj.A6_tilde_ekf = [0 0 0 1/ls 0 0; ...
                                    0 0 -1/ls 0 0 0; ...
                                    0 0 0 -1 0 0; ...
                                    0 0 1 0 0 0; ...
                                    0 0 0 0 0 0; ...
                                    0 0 0 0 0 0];

                obj.B_tilde_ekf = [1/ls 0; 0 1/ls; 0 0; 0 0; 0 0; 0 0];
                
                obj.C_ekf = [1 0 0 0 0 0; 0 1 0 0 0 0];
                obj.Bd_ekf = obj.B_tilde_ekf * obj.ts;
                
                obj.A_tilde_ekf = obj.A1_tilde_ekf + obj.A2_tilde_ekf + obj.A3_tilde_ekf + obj.A4_tilde_ekf + obj.A5_tilde_ekf + obj.A6_tilde_ekf;
               
                %% Kalman init
                    %% these parameters work pretty nice both generator and driver
                            % Qkalman = [ts^2 0 0 0 0 0; ...
                            %            0 ts^2 0 0 0 0; ...
                            %            0 0 ts 0 0 0;...
                            %            0 0 0 ts 0 0;...
                            %            0 0 0 0 1 0;...
                            %            0 0 0 0 0 1];
                            % obj.Qkalman = obj.ts/10 * Qkalman;
                            % obj.Rkalman = obj.ts * [1 0; 0 1];

                Qkalman = [ts^2 0 0 0 0 0; ...
                               0 ts^2 0 0 0 0; ...
                               0 0 1/2 0 0 0;...
                               0 0 0 1/2 0 0;...
                               0 0 0 0 1 0;...
                               0 0 0 0 0 1];

                obj.Qkalman = obj.ts/10 * Qkalman;
                obj.Rkalman = obj.ts * [1 0; 0 1];

                Co = ctrb(obj.A_tilde_ekf, obj.Qkalman);
                if rank(Co) == size(obj.A_tilde_ekf,1)
                    disp('PSM EKF Fully controllable');
                else
                    disp('PSM EKF Not fully controllable');
                end

                [P, L, G, report] = idare(obj.A_tilde_ekf', obj.C_ekf', obj.Qkalman, obj.Rkalman); 

                if report.Report == 0
                    disp('PSM EKF is stable.');
                end
                obj.k_kalman = 1;
                obj.k_dc = 0;
                obj.k_sw = 0;
            end
        end
    end
end












