% test_tri_monophase_transformer.m
% Sinusoidal steady-state sanity check of the tri_monophase_transformer
% parameterization. Pure MATLAB (no Simscape needed): rebuilds the same
% equations of tri_monophase_transformer.ssc as a linear descriptor system
% E x' = A x + B u and solves (jw E - A) X = B U for the default parameters.
% Checks: no-load voltage ratio, rated load, short-circuit impedance, both
% primaries in parallel, T-type and single-limb secondary distributions.

clear; clc;

% --- Parameters (defaults of tri_monophase_transformer.ssc) ---
p.Sr = 100e3;  p.V1 = 400;  p.V2 = 400;  p.V3 = 230;  p.fr = 50;
p.r1 = 0.005;  p.l1 = 0.030;
p.r2 = 0.005;  p.l2 = 0.030;
p.r3 = 0.005;  p.l3 = 0.030;
p.lm = 100;    p.lm0 = 0.5;  p.rfe = 500;
p.ws = [1 -1 0];

I3n = p.Sr/p.V3;              % secondary rated current
RLn = p.V3^2/p.Sr;            % rated resistive load
Ib1 = p.Sr/(sqrt(3)*p.V1);    % primary three-phase base current
U1  = balanced_set(p.V1, 0);        % balanced A-B-C set, complex peaks
z1  = p.r1 + 1j*p.l1;  z2 = p.r2 + 1j*p.l2;  z3 = p.r3 + 1j*p.l3;

% --- 1. no load ---
[E, A, B, d] = build(p, 'open', 'float', 'open', 0);
X = (1j*d.wb*E - A) \ (B*[U1; zeros(3,1)]);
r = results(X, U1, d);
fprintf('1) no load:        V3 = %7.2f V /_ %6.2f deg (ref V_AB), I1 = %.3f A\n', ...
    r.V3, r.phi3, r.I1(1));
fprintf('   expected: V3 = %.1f V, I1 = sqrt((Ib1/lm)^2 + (V1/sqrt(3)/(rfe*Zb1))^2) = %.3f A\n', ...
    p.V3, sqrt((Ib1/p.lm)^2 + (p.V1/sqrt(3)/(p.rfe*d.Zb1))^2));

% --- 2. rated resistive load ---
[E, A, B, d] = build(p, 'open', 'float', 'rl', RLn);
X = (1j*d.wb*E - A) \ (B*[U1; zeros(3,1)]);
r = results(X, U1, d);
fprintf('2) rated load:     V3 = %7.2f V, I3 = %6.1f A, lines A %6.1f  B %6.1f  C %6.1f A\n', ...
    r.V3, r.I3, r.I1);
fprintf('   expected: V3 = V3n/|1 + z3 + 2 z1| = %.2f V, I_A = I_B = n3*I3 = %.1f A\n', ...
    p.V3/abs(1 + z3 + 2*z1), d.n3*r.I3);

% --- 3. short circuit ---
[E, A, B, d] = build(p, 'open', 'float', 'short', 0);
X = (1j*d.wb*E - A) \ (B*[U1; zeros(3,1)]);
r = results(X, U1, d);
fprintf('3) short circuit:  z_sc = I3n/I3 = %.4f pu (expected |z3 + 2 z1| = %.4f pu)\n', ...
    I3n/r.I3, abs(z3 + 2*z1));

% --- 4. both primaries in parallel on the same source, short circuit ---
[E, A, B, d] = build(p, 'fed', 'float', 'short', 0);
X = (1j*d.wb*E - A) \ (B*[U1; U1]);
r = results(X, U1, d);
fprintf('4) two primaries:  z_sc = %.4f pu (expected |z3 + 2 z1 z2/(z1+z2)| = %.4f pu)\n', ...
    I3n/r.I3, abs(z3 + 2*z1*z2/(z1+z2)));

% --- 5. T-type distribution ---
pT = p;  pT.ws = [1 -1/2 -1/2];
[E, A, B, d] = build(pT, 'open', 'float', 'rl', RLn);
X = (1j*d.wb*E - A) \ (B*[U1; zeros(3,1)]);
r = results(X, U1, d);
fprintf('5) ws=[1 -1/2 -1/2]: V3 = %7.2f V /_ %6.2f deg, lines A %6.1f  B %6.1f  C %6.1f A (n3 = %.4f)\n', ...
    r.V3, r.phi3, r.I1, d.n3);

% --- 6. single-limb distribution with and without neutral ---
pS = p;  pS.ws = [1 0 0];
[E, A, B, d] = build(pS, 'open', 'float', 'rl', RLn);
X = (1j*d.wb*E - A) \ (B*[U1; zeros(3,1)]);
r = results(X, U1, d);
fprintf('6) ws=[1 0 0] N1 floating: V3 = %7.2f V, psi limbs a %.3f  b %.3f  c %.3f V s\n', ...
    r.V3, r.psi);
[E, A, B, d] = build(pS, 'open', 'ground', 'rl', RLn);
X = (1j*d.wb*E - A) \ (B*[U1; zeros(3,1)]);
r = results(X, U1, d);
fprintf('   ws=[1 0 0] N1 grounded: V3 = %7.2f V (expected V3n/|1 + z3 + 3 z1| = %.2f V), I_A = %.1f A\n', ...
    r.V3, p.V3/abs(1 + z3 + 3*z1), r.I1(1));

% ------------------------------------------------------------------------
function U = balanced_set(Vll, phase_deg)
% balanced three-phase set of phase-to-ground voltages, complex peaks
a  = exp(1j*2*pi/3);
Vp = sqrt(2)*Vll/sqrt(3)*exp(1j*phase_deg*pi/180);
U  = [Vp; Vp/a; Vp/a^2];
end

function [E, A, B, d] = build(p, prim2, neutral1, load, RL)
% descriptor system E x' = A x + B u of the component equations
% x = [i1a i1b i1c i2a i2b i2c i3 psia psib psic vn1 vn2], u = [vA1 vB1 vC1 vA2 vB2 vC2]
w     = p.ws;
d.wb  = 2*pi*p.fr;
d.Zb1 = p.V1^2/p.Sr;  d.Zb2 = p.V2^2/p.Sr;  d.Zb3 = p.V3^2/p.Sr;
d.gw  = sqrt((w(1) - (w(2)+w(3))/2)^2 + 3/4*(w(3)-w(2))^2);
d.n2  = p.V2/p.V1;
d.n3  = sqrt(3)*p.V3/(d.gw*p.V1);
d.R1  = p.r1*d.Zb1;  d.L1 = p.l1*d.Zb1/d.wb;
d.R2  = p.r2*d.Zb2;  d.L2 = p.l2*d.Zb2/d.wb;
d.R3  = p.r3*d.Zb3;  d.L3 = p.l3*d.Zb3/d.wb;
d.Lm  = p.lm*d.Zb1/d.wb;  d.Lm0 = p.lm0*d.Zb1/d.wb;
d.Lc  = (d.Lm - d.Lm0)/3;
d.Rfe = p.rfe*d.Zb1;
d.w   = w;
i1 = 1:3;  i2 = 4:6;  i3 = 7;  ps = 8:10;  vn1 = 11;  vn2 = 12;
E = zeros(12);  A = zeros(12);  B = zeros(12, 6);
for k = 1:3                                   % primary 1 coils
    E(k, i1(k)) = d.L1;  E(k, ps(k)) = 1;
    A(k, i1(k)) = -d.R1;  A(k, vn1) = -1;  B(k, k) = 1;
end
for k = 1:3                                   % primary 2 coils
    r = 3 + k;
    if strcmp(prim2, 'fed')
        E(r, i2(k)) = d.L2;  E(r, ps(k)) = d.n2;
        A(r, i2(k)) = -d.R2;  A(r, vn2) = -1;  B(r, 3 + k) = 1;
    else
        A(r, i2(k)) = 1;                      % open: i2k = 0
    end
end
if strcmp(load, 'open')                       % secondary
    A(i3, i3) = 1;
else
    if strcmp(load, 'short'), RL = 0; end
    E(i3, i3) = d.L3;  E(i3, ps) = -d.n3*w;
    A(i3, i3) = -(d.R3 + RL);
end
for k = 1:3                                   % magnetizing: psi = Lm im - Lc sum(im)
    r = 7 + k;
    E(r, ps(k)) = E(r, ps(k)) + d.Lm/d.Rfe;
    A(r, ps(k)) = -1;
    A(r, i1(k)) = A(r, i1(k)) + d.Lm;
    A(r, i2(k)) = A(r, i2(k)) + d.Lm*d.n2;
    A(r, i3)    = A(r, i3) - d.Lm*d.n3*w(k);
    for j = 1:3
        E(r, ps(j)) = E(r, ps(j)) - d.Lc/d.Rfe;
        A(r, i1(j)) = A(r, i1(j)) - d.Lc;
        A(r, i2(j)) = A(r, i2(j)) - d.Lc*d.n2;
        A(r, i3)    = A(r, i3) + d.Lc*d.n3*w(j);
    end
end
if strcmp(neutral1, 'float'), A(vn1, i1) = 1; else, A(vn1, vn1) = 1; end
if strcmp(prim2, 'fed'),      A(vn2, i2) = 1; else, A(vn2, vn2) = 1; end
end

function r = results(X, U1, d)
% rms values and phase of the secondary voltage with respect to V_AB
i1  = X(1:3);  i3 = X(7);  psi = X(8:10);
e3  = d.n3*(1j*d.wb)*(d.w*psi);
v3  = e3 - (d.R3 + 1j*d.wb*d.L3)*i3;
r.V3   = abs(v3)/sqrt(2);
r.phi3 = angle(v3/(U1(1) - U1(2)))*180/pi;
r.I3   = abs(i3)/sqrt(2);
r.I1   = abs(i1).'/sqrt(2);
r.psi  = abs(psi).'/sqrt(2);
end
