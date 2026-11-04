function [p, tb] = afe_uvw_ctrl_test_param()
%AFE_UVW_CTRL_TEST_PARAM  Parameters of the test bench test_afe_uvw_ctrl.slx: p (blocks) and tb (bench).
%
%   [p, tb] = afe_uvw_ctrl_test_param
%
%   p is afe_uvw_ctrl_param_example(ts, 50 Hz) unchanged. tb describes the scenario of the bench (one
%   run, all blocks exercised), read by afe_uvw_ctrl_test_source.m (grid voltage, PLL angle,
%   references) and afe_uvw_ctrl_test_plant.m (RL branches between converter and grid):
%
%     0            start; the sequence averages run from 0.025 s, the Q loops and the current control
%                  from the start, the active current reference steps to -0.85 pu at t_ctrl_on
%     t_enable     the FRT detector is enabled (0.175 s, the settle time of the model)
%     t_react      the positive-sequence reactive current reference steps to 0.1 pu (0.4 s)
%     t_dip        voltage dip 0.75 .. 0.90 s: positive sequence 0.55 pu, negative sequence 0.25 pu
%                  -> frt_vde4110 detects the fault, limits the power and asks for reactive current;
%                  the islanding detector must NOT trip (under-voltage stage 0.8 pu for 2.7 s)
%     t_drift      the grid frequency ramps up at 6 Hz/s from 1.15 s (loss of the grid with a surplus of
%                  active power) until 52.5 Hz -> islanding_detector trips on ROCOF (> 2.5 Hz/s for
%                  100 ms), then over-frequency (> 51.5 Hz)
%     t_end        1.6 s
%
%   The grid voltage has 1.5 % 5th and 2 % 7th harmonic and runs at 50.2 Hz, so that the averaging
%   windows are not an integer number of samples. The plant adds a DC offset u0_dc to the grid voltage
%   of the three branches (not measured): the zero-sequence current controller has to cancel it.
%   The converter voltage of the plant is the controller output plus k_ff times the measured grid
%   voltage: the feed-forward that a modulator adds. With k_ff = 0 the resonant controllers alone have
%   to produce the grid voltage (as in the model, whose outer loops correct the result).
%
%   See also afe_uvw_ctrl_test_run, afe_uvw_ctrl_param_example.

    tb.ts        = 125e-6;              % [s] step of the bench = control period of the blocks
    tb.f_nom     = 50;                  % [Hz]
    tb.omega_nom = 2*pi*tb.f_nom;       % [rad/s]
    tb.t_end     = 1.6;                 % [s]

    p = afe_uvw_ctrl_param_example(tb.ts, tb.f_nom);

    % ---- grid voltage (pu) and PLL angle
    tb.f_pu          = 50.2/tb.f_nom;   % [pu] grid frequency before the drift
    tb.h5            = 0.015;           % [pu] 5th harmonic (negative sequence) and its phase
    tb.h5_phase      = 1.1;             % [rad]
    tb.h7            = 0.02;            % [pu] 7th harmonic (positive sequence) and its phase
    tb.h7_phase      = 0.3;             % [rad]
    tb.t_dip         = [0.75 0.90];     % [s] start and end of the voltage dip
    tb.dip_pos       = 0.55;            % [pu] positive sequence during the dip
    tb.dip_neg       = 0.25;            % [pu] negative sequence during the dip and its angle
    tb.dip_neg_phase = 0.9;             % [rad]
    tb.t_drift       = 1.15;            % [s] start of the frequency ramp (islanding)
    tb.df_pu_dt      = 6/tb.f_nom;      % [pu/s] slope of the ramp (6 Hz/s)
    tb.f_pu_max      = 52.5/tb.f_nom;   % [pu] the ramp stops here

    % ---- references and enables
    tb.t_reset    = 0.025;              % [s] reset of the FRT state machine high before this time
    tb.t_enable   = 0.175;              % [s] FRT detector and islanding detector enabled from here
    tb.t_ctrl_on  = 0.05;               % [s] active current reference applied from here
    tb.i_xi_ref   = -0.85;              % [pu] positive-sequence active stack current reference
    tb.t_react    = 0.4;                % [s] reactive current reference step
    tb.i_react_pos = 0.1;               % [pu] positive-sequence reactive grid current reference
    tb.i_react_neg = 0;                 % [pu] negative-sequence reactive grid current reference

    % ---- plant: three RL branches, pu of the converter bases
    tb.x_l   = 0.1;                     % [pu] inductance (reactance at f_nom)
    tb.r     = 0.01;                    % [pu] resistance
    tb.k_ff  = 1;                       % feed-forward of the measured grid voltage in the converter voltage
    tb.u0_dc = 0.02;                    % [pu] DC offset of the grid voltage of the branches (zero sequence)
end
