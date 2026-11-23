% =========================================================
%  video_plot_grid_quantities.m
%  Finestra sinistra:  subplot 1 → tensioni trifase
%                      subplot 2 → correnti trifase
%  Finestra destra:    subplot 2x2 → P1p, P1n, Q1p, Q1n
%  Author: Claude
% =========================================================

load ..\sim_results_icc20inom_3.mat;

font_size_legend = 12;
font_size_labels = 12;
font_size_title = 12;

tc_eq = glb_time.tc*glb_time.decimation_tc;
tc = tc_eq;
t1 = 1.95;
t2 = 3.00;
N1 = floor(t1/tc);
N2 = floor(t2/tc);
N = N2-N1;

ig_u = ig_abc_sim(N1:N2,1);
ig_v = ig_abc_sim(N1:N2,2);
ig_w = ig_abc_sim(N1:N2,3);

vg_u = ug_abc_sim(N1:N2,1);
vg_v = ug_abc_sim(N1:N2,2);
vg_w = ug_abc_sim(N1:N2,3);

P1p = P1p_global_sim(N1:N2);
Q1p = Q1p_global_sim(N1:N2);
P1n = P1n_global_sim(N1:N2);
Q1n = Q1n_global_sim(N1:N2);

time = t_tc_sim(N1:N2);

%% Parametri
sim_duration   = t2-t1;
video_duration = 20.0;
fps            = 30;
% output_file    = 'video_plot_icc3inom_details_2.mp4';
output_file    = 'reactive_setpoints.mp4';

%% Colori
col_u  = [0.25  0.72  1.00];
col_v  = [1.00  0.55  0.10];
col_w  = [0.20  0.85  0.45];
col_P1p = [1.00  0.85  0.20];
col_P1n = [1.00  0.45  0.20];
col_Q1p = [0.75  0.30  1.00];
col_Q1n = [0.30  0.85  0.85];

%% Limiti assi (precalcolati)
lim = @(x) deal(min(x)*1.15, max(x)*1.15);
[yi_min, yi_max] = lim([ig_u; ig_v; ig_w]);
[yv_min, yv_max] = lim([vg_u; vg_v; vg_w]);
% [yP1p_min, yP1p_max] = lim(P1p);
yP1p_min = 0.75e6;
yP1p_max = 1.15e6;
[yP1n_min, yP1n_max] = lim(P1n);
[yQ1p_min, yQ1p_max] = lim(Q1p);
[yQ1n_min, yQ1n_max] = lim(Q1n);

fix = @(a,b) deal(a-(a==b), b+(a==b));
[yi_min,   yi_max  ] = fix(yi_min,   yi_max  );
[yv_min,   yv_max  ] = fix(yv_min,   yv_max  );
[yP1p_min, yP1p_max] = fix(yP1p_min, yP1p_max);
[yP1n_min, yP1n_max] = fix(yP1n_min, yP1n_max);
[yQ1p_min, yQ1p_max] = fix(yQ1p_min, yQ1p_max);
[yQ1n_min, yQ1n_max] = fix(yQ1n_min, yQ1n_max);

n_frames = round(fps * video_duration);

%% Video writer
vw = VideoWriter(output_file, 'MPEG-4');
vw.FrameRate = fps;
vw.Quality   = 95;
open(vw);

%% ---- Figura SINISTRA: tensioni + correnti ----
W = 900;  H = 720;          % dimensioni di ciascuna finestra
fig_L = figure('Color','k', 'Position',[50,  100, W, H], ...
               'MenuBar','none','ToolBar','none');

ax_v = subplot(2,1,1,'Parent',fig_L);
setup_ax(ax_v);
hl_vu = plot(ax_v,NaN,NaN,'Color',col_u,'LineWidth',1.5);
hl_vv = plot(ax_v,NaN,NaN,'Color',col_v,'LineWidth',1.5);
hl_vw = plot(ax_v,NaN,NaN,'Color',col_w,'LineWidth',1.5);
hc_v  = xline(ax_v,0,'r--','LineWidth',0.8,'Alpha',0.7);
legend(ax_v,{'v_{g,u}','v_{g,v}','v_{g,w}'},'TextColor','w', ...
       'Color','none','EdgeColor',[0.4 0.4 0.4],'Location','northeast','FontSize',font_size_legend);
title(ax_v,'Grid Voltages (Icc = 20 Inom)','Color','w','FontSize',font_size_title,'FontWeight','normal');
ylabel(ax_v,'v_g  [V]','Color','w','FontSize',font_size_labels);
xlim(ax_v,[t1,t2]); ylim(ax_v,[yv_min,yv_max]);
set(ax_v,'XTickLabel',{});
ht_v = make_text(ax_v,'w');

ax_i = subplot(2,1,2,'Parent',fig_L);
setup_ax(ax_i);
hl_iu = plot(ax_i,NaN,NaN,'Color',col_u,'LineWidth',1.5);
hl_iv = plot(ax_i,NaN,NaN,'Color',col_v,'LineWidth',1.5);
hl_iw = plot(ax_i,NaN,NaN,'Color',col_w,'LineWidth',1.5);
hc_i  = xline(ax_i,0,'r--','LineWidth',0.8,'Alpha',0.7);
legend(ax_i,{'i_{g,u}','i_{g,v}','i_{g,w}'},'TextColor','w', ...
       'Color','none','EdgeColor',[0.4 0.4 0.4],'Location','northeast','FontSize',font_size_legend);
title(ax_i,'Grid Currents (Icc = 20 Inom)','Color','w','FontSize',font_size_title,'FontWeight','normal');
ylabel(ax_i,'i_g  [A]','Color','w','FontSize',font_size_labels);
xlabel(ax_i,'Time  [s]','Color','w','FontSize',font_size_labels);
xlim(ax_i,[t1,t2]); ylim(ax_i,[yi_min,yi_max]);
ht_i = make_text(ax_i,'w');

%% ---- Figura DESTRA: P1p P1n Q1p Q1n (2x2) ----
fig_R = figure('Color','k', 'Position',[50+W+10, 100, W, H], ...
               'MenuBar','none','ToolBar','none');

% specs = { 'P_{1}^{+}', col_P1p, [yP1p_min, yP1p_max], 'P_{1}^{+}  [W]'  ;
%           'P_{1}^{-}', col_P1n, [yP1n_min, yP1n_max], 'P_{1}^{-}  [W]'  ;
%           'Q_{1}^{+}', col_Q1p, [yQ1p_min, yQ1p_max], 'Q_{1}^{+}  [VAr]';
%           'Q_{1}^{-}', col_Q1n, [yQ1n_min, yQ1n_max], 'Q_{1}^{-}  [VAr]'};
specs = { 'P_{1p} (Icc = 20 Inom)', col_P1p, [yP1p_min, yP1p_max], 'P_{1p}  [W]'  ;
            'P_{1n} (Icc = 20 Inom)', col_P1n, [yP1n_min, yP1n_max], 'P_{1n}  [W]'  ;
            'Q_{1p} (Icc = 20 Inom)', col_Q1p, [yQ1p_min, yQ1p_max], 'Q_{1p}  [VAr]';
            'Q_{1n} (Icc = 20 Inom)', col_Q1n, [yQ1n_min, yQ1n_max], 'Q_{1n}  [VAr]'};
sigs_R = {P1p, P1n, Q1p, Q1n};
pos    = [1 2 3 4];   % posizione nel layout 2x2

ax_R  = gobjects(4,1);
hl_R  = gobjects(4,1);
hc_R  = gobjects(4,1);
ht_R  = gobjects(4,1);

tl = tiledlayout(fig_R, 2, 2, 'TileSpacing','compact','Padding','compact');

for p = 1:4
    ax_R(p) = nexttile(tl, pos(p));
    setup_ax(ax_R(p));
    hl_R(p) = plot(ax_R(p), NaN, NaN, 'Color', specs{p,2}, 'LineWidth', 3);
    hc_R(p) = xline(ax_R(p), 0, 'r--', 'LineWidth', 0.8, 'Alpha', 0.7);
    title(ax_R(p), specs{p,1}, 'Color', specs{p,2}, 'FontSize', font_size_title, 'FontWeight','normal');
    ylabel(ax_R(p), specs{p,4}, 'Color','w','FontSize',font_size_labels);
    xlim(ax_R(p), [t1, t2]);
    ylim(ax_R(p), specs{p,3});
    if p < 3
        set(ax_R(p),'XTickLabel',{});
    else
        xlabel(ax_R(p),'Time  [s]','Color','w','FontSize',9);
    end
    ht_R(p) = make_text(ax_R(p), specs{p,2});
end

%% ---- Render ----
fprintf('Rendering %d frames...  ', n_frames);
t_prog = tic;

for k = 1:n_frames
    t_now = (k/n_frames) * sim_duration;
    idx   = min(round(t_now/tc)+1, N);
    t_str = sprintf('t = %.4f s', time(idx));

    % --- aggiorna figura sinistra ---
    set(hl_vu,'XData',time(1:idx),'YData',vg_u(1:idx));
    set(hl_vv,'XData',time(1:idx),'YData',vg_v(1:idx));
    set(hl_vw,'XData',time(1:idx),'YData',vg_w(1:idx));
    set(hc_v, 'Value',time(idx)); set(ht_v,'String',t_str);

    set(hl_iu,'XData',time(1:idx),'YData',ig_u(1:idx));
    set(hl_iv,'XData',time(1:idx),'YData',ig_v(1:idx));
    set(hl_iw,'XData',time(1:idx),'YData',ig_w(1:idx));
    set(hc_i, 'Value',time(idx)); set(ht_i,'String',t_str);

    % --- aggiorna figura destra ---
    data_R = {P1p, P1n, Q1p, Q1n};
    labels_R = {sprintf('P1p = %.2f kW',  P1p(idx)*1e-3), ...
                sprintf('P1n = %.2f kW',  P1n(idx)*1e-3), ...
                sprintf('Q1p = %.2f kVAr',Q1p(idx)*1e-3), ...
                sprintf('Q1n = %.2f kVAr',Q1n(idx)*1e-3)};
    for p = 1:4
        set(hl_R(p),'XData',time(1:idx),'YData',data_R{p}(1:idx));
        set(hc_R(p),'Value',time(idx));
        set(ht_R(p),'String',labels_R{p});
    end

    % --- cattura e affianca i due frame ---
    fr_L = getframe(fig_L);
    fr_R = getframe(fig_R);

    % Ridimensiona alla stessa altezza se necessario
    hL = size(fr_L.cdata,1);
    hR = size(fr_R.cdata,1);
    if hL ~= hR
        fr_R.cdata = imresize(fr_R.cdata, [hL, size(fr_R.cdata,2)]);
    end

    combined = [fr_L.cdata, fr_R.cdata];   % affianca orizzontalmente
    writeVideo(vw, combined);

    if mod(k, round(n_frames/20)) == 0
        fprintf('%.0f%%  ', 100*k/n_frames);
    end
end

fprintf('\nDone in %.1f s\n', toc(t_prog));
close(vw);
close(fig_L); close(fig_R);
fprintf('Video salvato: %s\n', output_file);

%% ---- Funzioni locali ----
function setup_ax(ax)
    set(ax, 'Color','k','XColor','w','YColor','w', ...
            'GridColor','w','GridAlpha',0.15, ...
            'XGrid','on','YGrid','on','FontSize',12);
    hold(ax,'on');
end

function h = make_text(ax, col)
    h = text(ax, 0.02, 0.93, '', ...
             'Units','normalized','Color',col, ...
             'FontSize',12,'FontName','Consolas', ...
             'VerticalAlignment','top');
end