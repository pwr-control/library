function nfail = test_three_phase_transformer()
%TEST_THREE_PHASE_TRANSFORMER  Steady-state check of transformer_Dd, transformer_Yyn, transformer_Dyn.
%
%   Pure MATLAB (no Simscape needed): the equations of the three .ssc files are
%   rebuilt one to one in the phasor domain (der() -> j*w, rms phasors) and
%   solved together with an ideal three-phase source and a few loads by a small
%   nodal solver. Every result is compared with a closed-form expectation on the
%   per-unit per-phase equivalent circuit (positive sequence) or on the sequence
%   networks of the model (single-phase loads), so the checks also prove that
%   the per-unit bases of the delta coils (3*V^2/Sr) and the vector-group rules
%   (limb and sense of each secondary coil) are consistent:
%
%     1. no load: secondary voltage, phase shift by clock number, no-load current
%     2. three-phase short circuit: short-circuit impedance l1 + l2 (and r1 + r2)
%     3. rated resistive load: voltage regulation, current ratio, power balance
%     4. single-phase load a-n on the Yyn: neutral shift with N floating (three-limb
%        core and bank of single-phase units) and with N grounded
%     5. single-phase load a-n on the Dyn: no neutral shift, load current carried by
%        two primary lines only (circulating current in the delta)
%     6. single-phase load a-b on the Dd: 2/3 - 1/3 split between the coil across
%        the load and the series of the other two, two primary lines loaded
%
%   MATLAB port of check_three_phase_transformer.py (same cases, same expected
%   values, same tolerances). Call it from the folder electrical_machines as
%   three_phase_transformer.test_three_phase_transformer; it returns the number
%   of failed checks (0 when all pass) and prints one line per check.

    global NFAIL
    NFAIL = 0;
    base = struct('Sr', 1e6, 'V1', 690, 'V2', 400, 'fr', 50, 'r1', 0.005, 'l1', 0.025, ...
                  'r2', 0.005, 'l2', 0.025, 'lm', 100, 'lm0', 0.5, 'rfe', 500);
    for clock = [11 1 5 7]
        p = base;  p.clock = clock;  run_kind('Dyn', p);
    end
    for clock = [0 6]
        p = base;  p.clock = clock;  run_kind('Yyn', p);
    end
    for clock = [0 6]
        p = base;  p.clock = clock;  run_kind('Dd', p);
    end
    if NFAIL == 0
        fprintf('\nALL CHECKS PASSED\n');
    else
        fprintf('\n%d CHECK(S) FAILED\n', NFAIL);
    end
    nfail = NFAIL;
end

% ======================================================================= cases
function run_kind(kind, p)
    w = 2*pi*p.fr;
    Sr = p.Sr;  V1 = p.V1;  V2 = p.V2;
    Ib1 = Sr/(sqrt(3)*V1);
    Ib2 = Sr/(sqrt(3)*V2);
    Vph2 = V2/sqrt(3);
    Zb2s = V2^2/Sr;
    [z1, z2, zm, zm0] = pu_equivalent(p);
    a = exp(1j*2*pi/3);
    t = 'T.';
    nodes = struct('A', 'A', 'B', 'B', 'C', 'C', 'a', 'a', 'b', 'b', 'c', 'c');
    if strcmp(kind, 'Yyn'), nodes.N = 'N'; end
    if any(strcmp(kind, {'Yyn', 'Dyn'})), nodes.n = 'n'; end
    switch kind
        case 'Dyn', i1names = {'T.iAB', 'T.iBC', 'T.iCA'};  i2names = {'T.i2a', 'T.i2b', 'T.i2c'};
        case 'Yyn', i1names = {'T.i1a', 'T.i1b', 'T.i1c'};  i2names = {'T.i2a', 'T.i2b', 'T.i2c'};
        case 'Dd',  i1names = {'T.iAB', 'T.iBC', 'T.iCA'};  i2names = {'T.i2ab', 'T.i2bc', 'T.i2ca'};
    end
    shift_exp = wrap(-30*p.clock);          % secondary lags the primary by clock*30 deg
    floating = strcmp(kind, 'Dd');

    fprintf('\n=== transformer_%s, clock %d: Sr = %g kVA, %g/%g V, %g Hz ===\n', ...
        kind, p.clock, Sr/1e3, V1, V2, p.fr);

    % ---- 1. no load ------------------------------------------------------
    [ck, d] = build_case(kind, p, w, nodes, t, true, false, floating);
    sol = ck_solve(ck);
    Vab = sol('V:a') - sol('V:b');
    VAB = sol('V:A') - sol('V:B');
    I1 = src_currents(sol);
    fprintf('1) no load\n');
    voc = zm/(z1 + zm);                       % pu open-circuit voltage
    check('|u_ab| / V2', abs(Vab)/V2, abs(voc), 1e-9);
    check('phase(u_ab) - phase(u_AB) [deg]', wrap(deg(Vab) - deg(VAB)), shift_exp, 1e-9, 360);
    check('I_A / Ib1 (no-load current, pu)', abs(I1(1))/Ib1, abs(1/(z1 + zm)), 1e-9);
    check('phase(I_A) - phase(u_AN) [deg]', wrap(deg(I1(1)) - deg(sol('V:A'))), deg(1/(z1 + zm)), 1e-9, 360);
    check('sum of line currents [A]', abs(sum(I1)), 0, 1e-9, Ib1);
    if isfield(nodes, 'n')
        check('neutral current n [A]', abs(sol('In')), 0, 1e-9, Ib2);
    end
    [pcu, pfe] = p_losses(sol, d, w, t, i1names, i2names);
    check('power balance P_src - P_cu - P_fe [W]', p_source(sol) - pcu - pfe, 0, 1e-9, Sr);
    check('P_fe / Sr (pu)', pfe/Sr, abs(voc)^2/p.rfe, 1e-9);

    % ---- 2. short circuit ------------------------------------------------
    [ck, d] = build_case(kind, p, w, nodes, t, true, false, floating);
    ck = ck_vsource(ck, 'Iscab', 'a', 'b', 0);
    ck = ck_vsource(ck, 'Iscbc', 'b', 'c', 0);
    sol = ck_solve(ck);
    I1 = src_currents(sol);
    zsc = z1 + 1/(1/zm + 1/z2);
    fprintf('2) three-phase short circuit at the secondary\n');
    check('Ib1 / I_A = |z_sc| (pu)', Ib1/abs(I1(1)), abs(zsc), 1e-9);
    check('   ~ |(r1 + r2) + j (l1 + l2)|', abs(zsc), abs(z1 + z2), 2e-2);
    check('phase of z_sc [deg]', wrap(deg(sol('V:A')) - deg(I1(1))), deg(zsc), 1e-9, 360);
    if strcmp(kind, 'Dd')
        I2a = sol('T.i2ab') - sol('T.i2ca');      % line current out of a
    else
        I2a = sol('T.i2a');
    end
    check('secondary line current I_a / Ib2', abs(I2a)/Ib2, abs(1/zsc*zm/(zm + z2)), 1e-9);
    [pcu, pfe] = p_losses(sol, d, w, t, i1names, i2names);
    check('power balance [W]', p_source(sol) - pcu - pfe, 0, 1e-9, Sr);

    % ---- 3. rated balanced resistive load ---------------------------------
    [ck, d] = build_case(kind, p, w, nodes, t, true, false, false);
    R = Zb2s;                                 % 1 pu per phase, star
    for x = 'abc'
        ck = ck_impedance(ck, ['IL' x], x, 'G', R);
    end
    sol = ck_solve(ck);
    I1 = src_currents(sol);
    Ia = sol('ILa');
    zin = z1 + 1/(1/zm + 1/(z2 + 1));
    i1 = 1/zin;
    v2 = i1*(1/(1/zm + 1/(z2 + 1)))*1/(z2 + 1);   % pu load voltage
    fprintf('3) rated resistive load (1 pu per phase, star, neutral to ground)\n');
    check('V_a / (V2/sqrt3) (regulation)', abs(sol('V:a'))/Vph2, abs(v2), 1e-9);
    check('phase(V_a) - phase(V_A) [deg]', wrap(deg(sol('V:a')) - deg(sol('V:A'))), wrap(shift_exp + deg(v2)), 1e-9, 360);
    check('I_A / Ib1', abs(I1(1))/Ib1, abs(i1), 1e-9);
    check('I_a / Ib2', abs(Ia)/Ib2, abs(v2), 1e-9);
    check('line current ratio I_A/I_a = V2/V1', abs(I1(1))/abs(Ia), V2/V1*abs(i1)/abs(v2), 1e-9);
    Pload = 3*R*abs(Ia)^2;
    [pcu, pfe] = p_losses(sol, d, w, t, i1names, i2names);
    check('power balance P_src - P_load - P_cu - P_fe [W]', p_source(sol) - Pload - pcu - pfe, 0, 1e-9, Sr);
    check('P_cu / Sr ~ (r1 + r2) at ~1 pu current', pcu/Sr, p.r1*abs(i1)^2 + p.r2*abs(v2)^2, 1e-9);
    fprintf('   efficiency %.4f %%, P_cu %.0f W, P_fe %.0f W\n', 100*Pload/p_source(sol), pcu, pfe);

    % ---- 4. Yyn: single-phase load a-n ------------------------------------
    if strcmp(kind, 'Yyn')
        cases = {p.lm0, false, sprintf('three-limb core (lm0 = %g), N floating', p.lm0); ...
                 p.lm,  false, sprintf('bank of single-phase units (lm0 = lm = %g), N floating', p.lm); ...
                 p.lm0, true,  'three-limb core, N grounded (YNyn)'};
        for r = 1:size(cases, 1)
            q = p;  q.lm0 = cases{r, 1};  gnd_N = cases{r, 2};  label = cases{r, 3};
            [z1, z2, zm, zm0] = pu_equivalent(q);
            [ck, d] = build_case(kind, q, w, nodes, t, true, gnd_N, false);
            R = Zb2s;
            ck = ck_impedance(ck, 'ILa', 'a', 'G', R);
            sol = ck_solve(ck);
            % sequence networks seen from the secondary (pu, star base)
            Z1 = z2 + 1/(1/z1 + 1/zm);
            if gnd_N
                Z0 = z2 + 1/(1/z1 + 1/zm0);
            else
                Z0 = z2 + zm0;
            end
            voc = zm/(z1 + zm)*exp(1j*deg2rad(shift_exp));
            I0 = voc/(2*Z1 + Z0 + 3*1.0);
            Vb_exp = a^2*(voc - I0*Z1) + a*(-I0*Z1) - I0*Z0;
            Vc_exp = a*(voc - I0*Z1) + a^2*(-I0*Z1) - I0*Z0;
            fprintf('4) single-phase load 1 pu a-n, %s\n', label);
            Ia = sol('ILa');
            V0 = (sol('V:a') + sol('V:b') + sol('V:c'))/3;
            check('I_a / Ib2', abs(Ia)/Ib2, abs(3*I0), 1e-9);
            check('zero-sequence voltage V0 / Vph2 (neutral shift)', abs(V0)/Vph2, abs(I0*Z0), 1e-9);
            check('|V_bn| / Vph2', abs(sol('V:b'))/Vph2, abs(Vb_exp), 1e-9);
            check('|V_cn| / Vph2', abs(sol('V:c'))/Vph2, abs(Vc_exp), 1e-9);
            check('neutral current In = I_a', abs(sol('In')), abs(Ia), 1e-9);
            I1 = src_currents(sol);
            if ~gnd_N
                check('sum of primary line currents (N floating) [A]', abs(sum(I1)), 0, 1e-9, Ib1);
                fprintf('   primary star point shift |V_N| / Vph1 = %.4f, secondary V0 / Vph2 = %.4f\n', ...
                    abs(sol('V:N'))/(V1/sqrt(3)), abs(V0)/Vph2);
            else
                check('primary neutral current IN = I_a*V2/V1 (zero seq. in the primary)', ...
                    abs(sol('IN')), abs(3*I0)*Ib2*V2/V1*abs(1/(1/z1 + 1/zm0)/z1), 1e-9);
            end
            fprintf('   |V_an| = %.4f, |V_bn| = %.4f, |V_cn| = %.4f pu; I_A, I_B, I_C = %.3f, %.3f, %.3f pu\n', ...
                abs(sol('V:a'))/Vph2, abs(sol('V:b'))/Vph2, abs(sol('V:c'))/Vph2, abs(I1)/Ib1);
            [pcu, pfe] = p_losses(sol, d, w, t, i1names, i2names);
            check('power balance [W]', p_source(sol) - R*abs(Ia)^2 - pcu - pfe, 0, 1e-9, Sr);
        end
    end

    % ---- 5. Dyn: single-phase load a-n ------------------------------------
    if strcmp(kind, 'Dyn')
        [ck, d] = build_case(kind, p, w, nodes, t, true, false, false);
        R = Zb2s;
        ck = ck_impedance(ck, 'ILa', 'a', 'G', R);
        sol = ck_solve(ck);
        Z1 = z2 + 1/(1/z1 + 1/zm);
        Z0 = z2 + 1/(1/z1 + 1/zm0);           % the delta closes the zero-sequence path
        voc = zm/(z1 + zm)*exp(1j*deg2rad(shift_exp));
        I0 = voc/(2*Z1 + Z0 + 3*1.0);
        Ia = sol('ILa');
        V0 = (sol('V:a') + sol('V:b') + sol('V:c'))/3;
        I1 = src_currents(sol);
        fprintf('5) single-phase load 1 pu a-n (delta carries the zero sequence)\n');
        check('I_a / Ib2', abs(Ia)/Ib2, abs(3*I0), 1e-9);
        check('zero-sequence voltage V0 / Vph2 (small: ~ |I0 (z1+z2)|)', abs(V0)/Vph2, abs(I0*Z0), 1e-9);
        check('   ~ |I0 (z1 + z2)| (within 5 %)', abs(V0)/Vph2, abs(I0*(z1 + z2)), 5e-2);
        % which primary lines carry the load: the coil of the limb of secondary coil a
        if any(p.clock == [11 5]), lines = 'ABC'; else, lines = 'CAB'; end   % coil across the first two
        idx = struct('A', 1, 'B', 2, 'C', 3);
        Iref = d.n21*abs(Ia);
        ck0 = build_case(kind, p, w, nodes, t, true, false, false);   % no-load (magnetizing) currents
        I10 = src_currents(ck_solve(ck0));
        dI = I1 - I10;
        check(sprintf('|I_%s - I_%s,noload| / (n21 |I_a|)', lines(1), lines(1)), abs(dI(idx.(lines(1))))/Iref, 1, 2e-2);
        check(sprintf('|I_%s - I_%s,noload| / (n21 |I_a|)', lines(2), lines(2)), abs(dI(idx.(lines(2))))/Iref, 1, 2e-2);
        check(sprintf('|I_%s - I_%s,noload| / (n21 |I_a|) (idle line)', lines(3), lines(3)), abs(dI(idx.(lines(3))))/Iref, 0, 2e-2, 1);
        check('sum of primary line currents [A]', abs(sum(I1)), 0, 1e-9, Ib1);
        check('neutral current In = I_a', abs(sol('In')), abs(Ia), 1e-9);
        icirc = (sol('T.iAB') + sol('T.iBC') + sol('T.iCA'))/3;
        fprintf('   circulating (zero-sequence) current in the delta: %.4f of n21*I_a; |V_an|, |V_bn|, |V_cn| = %.4f, %.4f, %.4f pu\n', ...
            abs(icirc)/Iref, abs(sol('V:a'))/Vph2, abs(sol('V:b'))/Vph2, abs(sol('V:c'))/Vph2);
        check('circulating current / (n21 I_a /3)', abs(icirc)/(Iref/3), abs(1/(1/z1 + 1/zm0)/z1), 1e-9);
        [pcu, pfe] = p_losses(sol, d, w, t, i1names, i2names);
        check('power balance [W]', p_source(sol) - R*abs(Ia)^2 - pcu - pfe, 0, 1e-9, Sr);
    end

    % ---- 6. Dd: single-phase load a-b -------------------------------------
    if strcmp(kind, 'Dd')
        [ck, d] = build_case(kind, p, w, nodes, t, true, false, true);
        R = 3*Zb2s;                           % rated coil current in the loaded coil at no drop
        ck = ck_impedance(ck, 'ILab', 'a', 'b', R);
        sol = ck_solve(ck);
        Iab = sol('ILab');
        Z1 = z2 + 1/(1/z1 + 1/zm);
        vocll = sqrt(3)*zm/(z1 + zm)*exp(1j*deg2rad(30 + shift_exp));   % u_ab / Vph2
        Iab_exp = vocll/(2*Z1 + 3.0);         % pu of Ib2
        fprintf('6) single-phase load a-b (R = 3 pu star base)\n');
        check('I_ab / Ib2', abs(Iab)/Ib2, abs(Iab_exp), 1e-9);
        check('coil a-b current / I_ab (2/3)', abs(sol('T.i2ab'))/abs(Iab), 2/3, 1e-9);
        check('coil b-c current / I_ab (1/3, series path)', abs(sol('T.i2bc'))/abs(Iab), 1/3, 1e-9);
        check('coil c-a current / I_ab (1/3, series path)', abs(sol('T.i2ca'))/abs(Iab), 1/3, 1e-9);
        check('I_c = i2ca - i2bc = 0 (idle terminal)', abs(sol('T.i2ca') - sol('T.i2bc')), 0, 1e-9, Ib2);
        I1 = src_currents(sol);
        ck0 = build_case(kind, p, w, nodes, t, true, false, true);
        I10 = src_currents(ck_solve(ck0));
        dI = I1 - I10;
        Iref = d.n21*abs(Iab);
        check('|I_A - I_A,noload| / (n21 |I_ab|)', abs(dI(1))/Iref, 1, 2e-2);
        check('|I_B - I_B,noload| / (n21 |I_ab|)', abs(dI(2))/Iref, 1, 2e-2);
        check('|I_C - I_C,noload| / (n21 |I_ab|) (idle line)', abs(dI(3))/Iref, 0, 2e-2, 1);
        psi0 = sol('T.psia') + sol('T.psib') + sol('T.psic');
        check('zero-sequence flux psi_a + psi_b + psi_c [V*s]', abs(psi0), 0, 1e-9, abs(sol('T.psia')));
        [pcu, pfe] = p_losses(sol, d, w, t, i1names, i2names);
        check('power balance [W]', p_source(sol) - R*abs(Iab)^2 - pcu - pfe, 0, 1e-9, Sr);
    end
end

function [ck, d] = build_case(kind, p, w, nodes, t, ground_n, ground_N, ref_c)
% Ideal source + transformer + neutral connections; ref_c grounds the corner c
% of a delta secondary that would otherwise float (a Simscape model needs a
% reference in that network as well).
    ck = ck_new();
    ck = add_source(ck, p.V1);
    fn = fieldnames(nodes);
    for k = 1:numel(fn)
        ck = ck_node(ck, nodes.(fn{k}));
    end
    switch kind
        case 'Dyn', [ck, d] = add_Dyn(ck, p, nodes, w, t);
        case 'Yyn', [ck, d] = add_Yyn(ck, p, nodes, w, t);
        case 'Dd',  [ck, d] = add_Dd(ck, p, nodes, w, t);
    end
    if isfield(nodes, 'n') && ground_n
        ck = ck_vsource(ck, 'In', 'n', 'G', 0);    % In = current n -> G
    end
    if isfield(nodes, 'N') && ground_N
        ck = ck_vsource(ck, 'IN', 'N', 'G', 0);
    end
    if ref_c
        ck = ck_vsource(ck, 'Iref', 'c', 'G', 0);
    end
end

% ========================================================= transformer models
function d = derived(p, kind)
% Private parameters of the .ssc components (same formulas).
    d.wb = 2*pi*p.fr;
    switch kind
        case 'Dyn'
            d.Zb1 = 3*p.V1^2/p.Sr;  d.Zb2 = p.V2^2/p.Sr;    d.n21 = p.V2/(sqrt(3)*p.V1);
        case 'Yyn'
            d.Zb1 = p.V1^2/p.Sr;    d.Zb2 = p.V2^2/p.Sr;    d.n21 = p.V2/p.V1;  d.s2 = 1 - p.clock/3;
        case 'Dd'
            d.Zb1 = 3*p.V1^2/p.Sr;  d.Zb2 = 3*p.V2^2/p.Sr;  d.n21 = p.V2/p.V1;  d.s2 = 1 - p.clock/3;
        otherwise
            error('unknown kind %s', kind);
    end
    d.R1  = p.r1*d.Zb1;
    d.L1  = p.l1*d.Zb1/d.wb;
    d.R2  = p.r2*d.Zb2;
    d.L2  = p.l2*d.Zb2/d.wb;
    d.Lm  = p.lm*d.Zb1/d.wb;
    d.Lm0 = p.lm0*d.Zb1/d.wb;
    d.Lc  = (d.Lm - d.Lm0)/3;
    d.Rfe = p.rfe*d.Zb1;
end

function f2 = f2_empty()
    e = struct('vars', {{}}, 'coeffs', []);
    f2 = struct('a', e, 'b', e, 'c', e);
end

function ck = add_core(ck, t, d, w, i1, f2)
% Common part of the three components: mmf balance and three-limb core.
% i1.(k): name of the primary coil current of limb k; f2.(k): vars/coeffs of
% the demagnetizing mmf of the secondary coil(s) on limb k (primary turns).
    limbs = 'abc';
    for k = 1:3
        L = limbs(k);
        % im_k == i1_k - f2_k - der(psi_k)/Rfe
        vars = [{[t 'im' L], i1.(L), [t 'psi' L]}, f2.(L).vars];
        coeffs = [1, -1, 1j*w/d.Rfe, f2.(L).coeffs];
        ck = ck_eq(ck, vars, coeffs, 0);
        % psi_k == Lm*im_k - Lc*(ima + imb + imc)
        vars = {[t 'psi' L], [t 'ima'], [t 'imb'], [t 'imc']};
        coeffs = [1, d.Lc, d.Lc, d.Lc];
        coeffs(1 + k) = coeffs(1 + k) - d.Lm;
        ck = ck_eq(ck, vars, coeffs, 0);
    end
end

function [ck, d] = add_Dyn(ck, p, nodes, w, t)
% transformer_Dyn: nodes with fields A, B, C, a, b, c, n.
    d = derived(p, 'Dyn');
    n21 = d.n21;
    z1 = d.R1 + 1j*w*d.L1;
    z2 = d.R2 + 1j*w*d.L2;
    i1 = struct('a', [t 'iAB'], 'b', [t 'iBC'], 'c', [t 'iCA']);
    ck = ck_branch(ck, i1.a, nodes.A, nodes.B);
    ck = ck_branch(ck, i1.b, nodes.B, nodes.C);
    ck = ck_branch(ck, i1.c, nodes.C, nodes.A);
    for x = 'abc'
        ck = ck_branch(ck, [t 'i2' x], nodes.n, nodes.(x));
    end
    % primary delta coils: A.v - B.v == R1*iAB + L1*der(iAB) + der(psia) ...
    PQ = {'A', 'B', 'a'; 'B', 'C', 'b'; 'C', 'A', 'c'};
    for r = 1:3
        P = PQ{r, 1};  Q = PQ{r, 2};  k = PQ{r, 3};
        ck = ck_eq(ck, {['V:' nodes.(P)], ['V:' nodes.(Q)], i1.(k), [t 'psi' k]}, [1, -1, -z1, -1j*w], 0);
    end
    % vector group: limb and sense of each secondary coil, as in the ssc
    switch p.clock
        case 11, limb = struct('a', 'a', 'b', 'b', 'c', 'c');  sense = struct('a', 1, 'b', 1, 'c', 1);
        case 5,  limb = struct('a', 'a', 'b', 'b', 'c', 'c');  sense = struct('a', -1, 'b', -1, 'c', -1);
        case 1,  limb = struct('a', 'c', 'b', 'a', 'c', 'b');  sense = struct('a', -1, 'b', -1, 'c', -1);
        case 7,  limb = struct('a', 'c', 'b', 'a', 'c', 'b');  sense = struct('a', 1, 'b', 1, 'c', 1);
        otherwise, error('Dyn clock must be 1, 5, 7 or 11');
    end
    f2 = f2_empty();
    for x = 'abc'
        L = limb.(x);  s = sense.(x);
        % a.v - n.v == e2a - R2*i2a - L2*der(i2a), e2a = s*n21*um_limb, um = der(psi)
        ck = ck_eq(ck, {['V:' nodes.(x)], ['V:' nodes.n], [t 'psi' L], [t 'i2' x]}, [1, -1, -s*n21*1j*w, z2], 0);
        f2.(L).vars{end+1} = [t 'i2' x];
        f2.(L).coeffs(end+1) = s*n21;
    end
    ck = add_core(ck, t, d, w, i1, f2);
end

function [ck, d] = add_Yyn(ck, p, nodes, w, t)
% transformer_Yyn: nodes with fields A, B, C, N, a, b, c, n.
    d = derived(p, 'Yyn');
    n21 = d.n21;  s2 = d.s2;
    z1 = d.R1 + 1j*w*d.L1;
    z2 = d.R2 + 1j*w*d.L2;
    i1 = struct('a', [t 'i1a'], 'b', [t 'i1b'], 'c', [t 'i1c']);
    f2 = f2_empty();
    X = 'ABC';  x = 'abc';
    for k = 1:3
        ck = ck_branch(ck, i1.(x(k)), nodes.(X(k)), nodes.N);
        ck = ck_branch(ck, [t 'i2' x(k)], nodes.n, nodes.(x(k)));
        % A.v - N.v == R1*i1a + L1*der(i1a) + der(psia)
        ck = ck_eq(ck, {['V:' nodes.(X(k))], ['V:' nodes.N], i1.(x(k)), [t 'psi' x(k)]}, [1, -1, -z1, -1j*w], 0);
        % a.v - n.v == s2*n21*der(psia) - R2*i2a - L2*der(i2a)
        ck = ck_eq(ck, {['V:' nodes.(x(k))], ['V:' nodes.n], [t 'psi' x(k)], [t 'i2' x(k)]}, [1, -1, -s2*n21*1j*w, z2], 0);
        f2.(x(k)).vars{end+1} = [t 'i2' x(k)];
        f2.(x(k)).coeffs(end+1) = s2*n21;
    end
    ck = add_core(ck, t, d, w, i1, f2);
end

function [ck, d] = add_Dd(ck, p, nodes, w, t)
% transformer_Dd: nodes with fields A, B, C, a, b, c.
    d = derived(p, 'Dd');
    n21 = d.n21;  s2 = d.s2;
    z1 = d.R1 + 1j*w*d.L1;
    z2 = d.R2 + 1j*w*d.L2;
    i1 = struct('a', [t 'iAB'], 'b', [t 'iBC'], 'c', [t 'iCA']);
    i2 = struct('a', [t 'i2ab'], 'b', [t 'i2bc'], 'c', [t 'i2ca']);
    f2 = f2_empty();
    PQ = {'A', 'B', 'a'; 'B', 'C', 'b'; 'C', 'A', 'c'};
    for r = 1:3
        P = PQ{r, 1};  Q = PQ{r, 2};  k = PQ{r, 3};
        pl = lower(P);  ql = lower(Q);
        ck = ck_branch(ck, i1.(k), nodes.(P), nodes.(Q));        % iAB : A.i -> B.i
        ck = ck_branch(ck, i2.(k), nodes.(ql), nodes.(pl));      % i2ab : b.i -> a.i
        % A.v - B.v == R1*iAB + L1*der(iAB) + der(psia)
        ck = ck_eq(ck, {['V:' nodes.(P)], ['V:' nodes.(Q)], i1.(k), [t 'psi' k]}, [1, -1, -z1, -1j*w], 0);
        % a.v - b.v == s2*n21*der(psia) - R2*i2ab - L2*der(i2ab)
        ck = ck_eq(ck, {['V:' nodes.(pl)], ['V:' nodes.(ql)], [t 'psi' k], i2.(k)}, [1, -1, -s2*n21*1j*w, z2], 0);
        f2.(k).vars{end+1} = i2.(k);
        f2.(k).coeffs(end+1) = s2*n21;
    end
    ck = add_core(ck, t, d, w, i1, f2);
end

% ================================================================== helpers
function ck = add_source(ck, V_ll)
% Ideal balanced star source, rms line-to-line V_ll, neutral node G grounded.
    ck = ck_ground(ck, 'G');
    E = V_ll/sqrt(3);
    a = exp(1j*2*pi/3);
    rot = [1, a^2, a];
    X = 'ABC';
    for k = 1:3
        ck = ck_vsource(ck, ['IS' X(k)], X(k), 'G', E*rot(k));
    end
end

function I = src_currents(sol)
% Currents delivered by the source into lines A, B, C: the source branch
% current IS flows X -> G inside the source, so the line current is -IS.
    I = -[sol('ISA'); sol('ISB'); sol('ISC')];
end

function P = p_source(sol)
    P = 0;
    X = 'ABC';
    for k = 1:3
        P = P + real(sol(['V:' X(k)])*conj(-sol(['IS' X(k)])));
    end
end

function [pcu, pfe] = p_losses(sol, d, w, t, i1names, i2names)
    pcu = 0;
    for k = 1:3
        pcu = pcu + d.R1*abs(sol(i1names{k}))^2 + d.R2*abs(sol(i2names{k}))^2;
    end
    pfe = 0;
    for L = 'abc'
        pfe = pfe + abs(1j*w*sol([t 'psi' L]))^2/d.Rfe;
    end
end

function [z1, z2, zm, zm0] = pu_equivalent(p)
% Per-phase per-unit quantities, star base on both sides (positive sequence).
    z1 = p.r1 + 1j*p.l1;
    z2 = p.r2 + 1j*p.l2;
    zm = 1/(1/(1j*p.lm) + 1/p.rfe);
    zm0 = 1/(1/(1j*p.lm0) + 1/p.rfe);
end

function x = deg(z)
    x = rad2deg(angle(z));
end

function x = wrap(a)
    x = mod(a + 180, 360) - 180;
end

function check(label, got, expected, tol, scale)
% Relative check |got - expected| <= tol*max(|expected|, scale).
    global NFAIL
    if nargin < 5, scale = 0; end
    ref = max([abs(expected), scale, 1e-300]);
    err = abs(got - expected)/ref;
    ok = err <= tol;
    NFAIL = NFAIL + ~ok;
    if ok
        status = 'OK';
    else
        status = sprintf('FAIL (err %.2e)', err);
    end
    fprintf('   %-52s %-40s %s\n', label, sprintf('got %.6g, expected %.6g', got, expected), status);
end

% ============================================================ nodal solver
% Linear phasor circuit: unknown node voltages 'V:<node>' and element currents.
% Through-variable convention of Simscape: a branch 'i : X -> Y' carries i from
% terminal X to terminal Y through the element, so i leaves node X and enters
% node Y. KCL of a node: sum of the currents leaving it into elements = 0.
function ck = ck_new()
    ck.index = containers.Map('KeyType', 'char', 'ValueType', 'double');
    ck.eqs = {};        % each {vars, coeffs, rhs}
    ck.kcl = {};        % each {node, var, coeff}: coeff*var leaves node
    ck.nodes = {};
    ck.grounds = {};
end

function ck = ck_var(ck, name)
    if ~isKey(ck.index, name)
        ck.index(name) = ck.index.Count + 1;
    end
end

function ck = ck_node(ck, name)
    ck = ck_var(ck, ['V:' name]);
    if ~any(strcmp(ck.nodes, name))
        ck.nodes{end+1} = name;
    end
end

function ck = ck_ground(ck, name)
    ck = ck_node(ck, name);
    ck.grounds{end+1} = name;
end

function ck = ck_eq(ck, vars, coeffs, rhs)
    for k = 1:numel(vars)
        ck = ck_var(ck, vars{k});
    end
    ck.eqs{end+1} = {vars, coeffs, rhs};
end

function ck = ck_branch(ck, ivar, nfrom, nto)
% Register the through variable ivar flowing nfrom -> nto through an element.
    ck = ck_var(ck, ivar);
    ck = ck_node(ck, nfrom);
    ck = ck_node(ck, nto);
    ck.kcl{end+1} = {nfrom, ivar, 1};
    ck.kcl{end+1} = {nto, ivar, -1};
end

function ck = ck_vsource(ck, name, npos, nneg, E)
% Ideal source: V(npos) - V(nneg) = E; current name flows npos -> nneg inside.
    ck = ck_branch(ck, name, npos, nneg);
    ck = ck_eq(ck, {['V:' npos], ['V:' nneg]}, [1, -1], E);
end

function ck = ck_impedance(ck, name, npos, nneg, Z)
% Impedance Z: current name flows npos -> nneg through it.
    ck = ck_branch(ck, name, npos, nneg);
    ck = ck_eq(ck, {['V:' npos], ['V:' nneg], name}, [1, -1, -Z], 0);
end

function sol = ck_solve(ck)
    n = ck.index.Count;
    rows = ck.eqs;
    for k = 1:numel(ck.nodes)
        node = ck.nodes{k};
        if any(strcmp(ck.grounds, node))
            rows{end+1} = {{['V:' node]}, 1, 0}; %#ok<AGROW>
        else
            vars = {};  coeffs = [];
            for m = 1:numel(ck.kcl)
                if strcmp(ck.kcl{m}{1}, node)
                    vars{end+1} = ck.kcl{m}{2}; %#ok<AGROW>
                    coeffs(end+1) = ck.kcl{m}{3}; %#ok<AGROW>
                end
            end
            rows{end+1} = {vars, coeffs, 0}; %#ok<AGROW>
        end
    end
    if numel(rows) ~= n
        error('system is %d x %d', numel(rows), n);
    end
    M = zeros(n, n);
    b = zeros(n, 1);
    for r = 1:n
        vars = rows{r}{1};  coeffs = rows{r}{2};
        for k = 1:numel(vars)
            c = ck.index(vars{k});
            M(r, c) = M(r, c) + coeffs(k);
        end
        b(r) = rows{r}{3};
    end
    x = M \ b;
    sol = containers.Map('KeyType', 'char', 'ValueType', 'any');
    names = keys(ck.index);
    for k = 1:numel(names)
        sol(names{k}) = x(ck.index(names{k}));
    end
end
