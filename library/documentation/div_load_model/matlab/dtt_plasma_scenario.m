function S = dtt_plasma_scenario(p, t, t0)
%DTT_PLASMA_SCENARIO  Plasma current and plasma-coil mutual inductance trajectories
%   S = dtt_plasma_scenario(p, t)      p = par.plasma.div3 (see dtt_div_params), t time vector [s]
%   S = dtt_plasma_scenario(p, t, t0)  disruption shifted to start at t0
%   Returns S.Ip [A], S.Mcp [H], S.Psi = Mcp*Ip [Wb], S.e (analytic e.m.f., same
%   equations as dtt.emf_analytic, discrete first-order filter) and timeseries
%   S.ts_Ip, S.ts_Mcp for "From Workspace" -> Simulink-PS Converter -> dtt.plasma_emf.
%   Model: flat top Ip = Ip0, Mcp = Psi_a/Ip0; VDE: Mcp grows so that
%   Psi = Psi_a + dPsi_v (exp(g(tt-tq)) - exp(-g tq))/(1 - exp(-g tq)); quench: Ip
%   ramps linearly to 0 in tcq with Mcp frozen at (Psi_a + dPsi_v)/Ip0.
if nargin < 3, t0 = 0; end
t = t(:); tt = t - t0;
Psi0 = p.Psi_a + p.dPsi_v; kk = 1/(1 - exp(-p.g*p.tq));
Psi = zeros(size(t)); dPsi = zeros(size(t));
m0 = tt <= 0; m1 = tt > 0 & tt <= p.tq; m2 = tt > p.tq & tt < p.tq + p.tcq;
Psi(m0)  = p.Psi_a;
Psi(m1)  = p.Psi_a + p.dPsi_v*(exp(p.g*(tt(m1)-p.tq)) - exp(-p.g*p.tq))*kk;
dPsi(m1) = p.dPsi_v*p.g*exp(p.g*(tt(m1)-p.tq))*kk;
Psi(m2)  = Psi0*(1 - (tt(m2)-p.tq)/p.tcq);
dPsi(m2) = -Psi0/p.tcq;
Ip = p.Ip0*ones(size(t)); Ip(m2) = p.Ip0*(1 - (tt(m2)-p.tq)/p.tcq); Ip(tt >= p.tq + p.tcq) = 0;
Mcp = Psi/p.Ip0; Mcp(tt >= p.tq) = Psi0/p.Ip0;     % frozen during/after the quench
% analytic e.m.f. with the passive-structure delay (discrete first-order filter)
dt = t(2) - t(1); a = exp(-dt/p.tau_v); x = filter(1-a, [1 -a], dPsi);
e = (1 - p.gam)*dPsi + p.gam*x;
S = struct('t',t,'Ip',Ip,'Mcp',Mcp,'Psi',Psi,'dPsi',dPsi,'e',e);
S.ts_Ip  = timeseries(Ip, t, 'Name','Ip [A]');
S.ts_Mcp = timeseries(Mcp, t, 'Name','Mcp [H]');
end
