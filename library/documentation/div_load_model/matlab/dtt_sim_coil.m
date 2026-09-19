function [i, x] = dtt_sim_coil(t, e, L0, R0, Lm, tau, k_e, i0, v)
%DTT_SIM_COIL  Fixed-step (trapezoidal) MATLAB replica of the dtt.div_coil equations.
%   i = dtt_sim_coil(t, e, L0, R0, Lm, tau, k_e, i0, v)
%   Solves  v = R0 i + L0 di/dt + sum_k Lm(k) dx_k/dt + k_e e ,
%           tau(k) dx_k/dt + x_k + tau(k) di/dt = 0
%   for a given terminal voltage v(t) (default 0 = ideal crowbar). Lm, tau may be empty.
%   Used to check the CSV data and parameter sets without Simulink (dtt_validate_ode.m).
if nargin < 9 || isempty(v), v = zeros(size(t)); end
if nargin < 8 || isempty(i0), i0 = 0; end
if nargin < 7 || isempty(k_e), k_e = 1; end
t = t(:); e = e(:); v = v(:); Lm = Lm(:)'; tau = tau(:)'; N = numel(Lm);
M = zeros(N+1); Rm = zeros(N+1); B = zeros(N+1, 2);
M(1,1) = L0; M(1,2:end) = Lm; Rm(1,1) = R0; B(1,:) = [-k_e 1];
for k = 1:N
    M(k+1,1) = tau(k); M(k+1,k+1) = tau(k); Rm(k+1,k+1) = 1;
end
dt = t(2) - t(1);
A1 = M/dt + Rm/2; A0 = M/dt - Rm/2;
X = zeros(N+1, numel(t)); X(1,1) = i0;
u = [e v]';
for k = 1:numel(t)-1
    X(:,k+1) = A1 \ (A0*X(:,k) + B*(u(:,k+1) + u(:,k))/2);
end
i = X(1,:)'; x = X(2:end,:)';
end
