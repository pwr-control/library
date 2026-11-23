function [Rc, Cc] = foster2cauer(Rf, tauf)
%FOSTER2CAUER  Foster thermal network -> equivalent Cauer ladder.
%
%   [Rc, Cc] = foster2cauer(Rf, tauf)
%
%   Rf   : Foster resistances R_i [K/W] of Zth(t) = sum R_i*(1 - exp(-t/tau_i))
%   tauf : Foster time constants tau_i [s]
%   Rc   : Cauer series resistances [K/W], junction -> case (row vector)
%   Cc   : Cauer capacitances to the thermal reference [J/K] (row vector)
%
%   The Cauer ladder
%
%     Tj o--+--[Rc(1)]--+--[Rc(2)]-- ... --+--[Rc(n)]--o case
%           |           |                  |
%         Cc(1)       Cc(2)              Cc(n)
%           |           |                  |
%          ===         ===                ===
%
%   has the same Zth(j-c) as the Foster network when the case is held at
%   constant temperature: the thermal admittance Y(s) = 1/Z(s) is expanded
%   in continued fraction (Cauer I form)
%       Y(s) = s*C1 + 1/(R1 + 1/(s*C2 + 1/(R2 + ...)))
%   with s normalised by max(tauf) to keep the polynomial coefficients in
%   range. Unlike the Foster network, whose nodes have no physical meaning,
%   the ladder can be coupled to a heat sink or a thermal mass: use it for
%   the Rth, Cth parameters of diode_rr_th and thyristor_rr_th (library
%   foundation/semiconductors), and put the case-to-heat-sink resistance
%   in Rch, not in the ladder.
%
%   The result is checked against the Foster Zth(t) (step response of the
%   ladder, 60 times from tau_min/100 to 10*tau_max): a warning is issued if
%   the error is above 1e-6 of Rth or an element is not positive (this can
%   happen with many terms of nearly equal time constants, where the
%   polynomial expansion loses accuracy).
%
%   Example (Hitachi Energy 5STP 42U6500, Zth(j-c) double side cooled):
%     [Rc, Cc] = foster2cauer([2.736 0.813 0.338 0.113]*1e-3, ...
%                             [0.9484 0.1155 0.0131 0.0036])
%     % Rc = [0.4189 0.4102 1.2590 1.9118]*1e-3 K/W
%     % Cc = [14.90 30.19 80.83 343.43] J/K

Rf = Rf(:).';  tauf = tauf(:).';
n = numel(Rf);
assert(n >= 1 && numel(tauf) == n, 'foster2cauer: Rf and tauf must have the same length.');
assert(all(Rf > 0) && all(tauf > 0), 'foster2cauer: Rf and tauf must be positive.');

% Z(s) = sum Rf_i/(1 + s*tauf_i) = N(s)/D(s), s normalised by ts
ts = max(tauf);
tn = tauf/ts;
D = 1;
for i = 1:n
    D = conv(D, [tn(i) 1]);
end
N = zeros(1, n);
for i = 1:n
    P = Rf(i);
    for j = [1:i-1, i+1:n]
        P = conv(P, [tn(j) 1]);
    end
    N = N + P;
end

% continued fraction of Y = D/N: deg(num) = deg(den) + 1 at each C step
num = D;  den = N;
Rc = zeros(1, n);  Cc = zeros(1, n);
for k = 1:n
    C = num(1)/den(1);                      % s*C term
    r = num - conv([C 0], den);
    r = r(2:end);                           % leading coefficient cancels
    R = den(1)/r(1);                        % series R term
    Cc(k) = C*ts;
    Rc(k) = R;
    if k == n, break; end
    nd = den - R*r;
    num = r;
    den = nd(2:end);                        % leading coefficient cancels
end

% check: step response of the ladder against the Foster Zth(t)
A = zeros(n);
B = zeros(n, 1);  B(1) = 1/Cc(1);
for k = 1:n
    g_up = 0;
    if k > 1, g_up = 1/Rc(k-1); end
    g_dn = 1/Rc(k);                         % the last one goes to the case
    A(k, k) = -(g_up + g_dn)/Cc(k);
    if k > 1, A(k, k-1) = g_up/Cc(k); end
    if k < n, A(k, k+1) = g_dn/Cc(k); end
end
t = logspace(log10(min(tauf)/100), log10(10*max(tauf)), 60);
zc = zeros(size(t));
for m = 1:numel(t)
    x = A\((expm(A*t(m)) - eye(n))*B);
    zc(m) = x(1);
end
zf = sum(Rf(:).*(1 - exp(-t./tauf(:))), 1);
err = max(abs(zc - zf))/sum(Rf);
if err > 1e-6 || any(Rc <= 0) || any(Cc <= 0)
    warning('foster2cauer:check', ...
        'Cauer ladder: max |Zc - Zf| = %.3g of Rth, min Rc = %.3g K/W, min Cc = %.3g J/K.', ...
        err, min(Rc), min(Cc));
end
end
