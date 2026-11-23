clear;
close all;
clc;

load voltage_dip_reference.mat;
tc_eq = glb_time.tc*glb_time.decimation_tc;
tc = tc_eq;
t1 = 0.65;
t2 = 1.75;
N1 = floor(t1/tc);
N2 = floor(t2/tc);
N = N2-N1;

uline_u = u_abc_line_sim(N1:N2,1);
uline_v = u_abc_line_sim(N1:N2,2);
uline_w = u_abc_line_sim(N1:N2,3);

ug_u = ug_abc_sim(N1:N2,1);
ug_v = ug_abc_sim(N1:N2,2);
ug_w = ug_abc_sim(N1:N2,3);

time = t_tc_sim(N1:N2);

tratto1 = 2;
tratto2 = 2;
tratto3 = 4;
colore1 = [0.25 0.25 0.25];
colore2 = [0.50 0.50 0.50];
colore3 = [0.75 0.75 0.75];

fontsize_title = 14;
fontsize_legend = 14;
fontsize_axis = 12;

figure(1);
subplot 211
plot(time,uline_u,'-','LineWidth',tratto2,'Color',colore1);
hold on
plot(time,uline_v,'-','LineWidth',tratto2,'Color',colore2);
hold on
plot(time,uline_w,'-','LineWidth',tratto2,'Color',colore3);
hold off
title('Line Voltages','Interpreter','latex','FontSize',fontsize_title);
legend('$u_{\mathrm{line}}^{\mathrm{u}}$','$u_{\mathrm{line}}^{\mathrm{v}}$',...
    '$u_{\mathrm{line}}^{\mathrm{w}}$','Location','northeastoutside',...
    'Interpreter','latex','FontSize',fontsize_legend);
% xlabel('Time - [s]','Interpreter','latex','FontSize', fontsize_axis);
ylabel('Voltage - [V]','Interpreter','latex','FontSize', fontsize_axis);
set(gca,'ylim',[-750 750]);
set(gca,'xlim',[t1 t2]);
grid on
chH = get(gca,'Children');
set(gca,'Children',[chH(1); chH(2); chH(3)]);
subplot 212
plot(time,ug_u,'-','LineWidth',tratto2,'Color',colore1);
hold on
plot(time,ug_v,'-','LineWidth',tratto2,'Color',colore2);
hold on
plot(time,ug_w,'-','LineWidth',tratto2,'Color',colore3);
hold off
title('Grid Voltages','Interpreter','latex','FontSize',fontsize_title);
legend('$u_{\mathrm{grid}}^{\mathrm{u}}$','$u_{\mathrm{grid}}^{\mathrm{v}}$',...
    '$u_{\mathrm{grid}}^{\mathrm{w}}$','Location','northeastoutside',...
    'Interpreter','latex','FontSize',fontsize_legend);
xlabel('Time - [s]','Interpreter','latex','FontSize', fontsize_axis);
ylabel('Voltage - [V]','Interpreter','latex','FontSize', fontsize_axis);
set(gca,'ylim',[-750 750]);
set(gca,'xlim',[t1 t2]);
grid on
chH = get(gca,'Children');
set(gca,'Children',[chH(1); chH(2); chH(3)]);
grid on
h=gcf;
set(h,'PaperOrientation','landscape');
set(h,'PaperUnits','normalized');
set(h,'PaperPosition', [0 0 1 1]);
print('voltage_dip_reference','-depsc');
movefile('voltage_dip_reference.eps', 'figures');

t1 = 1.1;
t2 = 1.14;
N1 = floor(t1/tc);
N2 = floor(t2/tc);
N = N2-N1;

uline_u = u_abc_line_sim(N1:N2,1);
uline_v = u_abc_line_sim(N1:N2,2);
uline_w = u_abc_line_sim(N1:N2,3);

ug_u = ug_abc_sim(N1:N2,1);
ug_v = ug_abc_sim(N1:N2,2);
ug_w = ug_abc_sim(N1:N2,3);

time = t_tc_sim(N1:N2);


figure(2);
subplot 211
plot(time,uline_u,'-','LineWidth',tratto3,'Color',colore1);
hold on
plot(time,uline_v,'-','LineWidth',tratto3,'Color',colore2);
hold on
plot(time,uline_w,'-','LineWidth',tratto3,'Color',colore3);
hold off
title('Line Voltages','Interpreter','latex','FontSize',fontsize_title);
legend('$u_{\mathrm{line}}^{\mathrm{u}}$','$u_{\mathrm{line}}^{\mathrm{v}}$',...
    '$u_{\mathrm{line}}^{\mathrm{w}}$','Location','northeastoutside',...
    'Interpreter','latex','FontSize',fontsize_legend);
% xlabel('Time - [s]','Interpreter','latex','FontSize', fontsize_axis);
ylabel('Voltage - [V]','Interpreter','latex','FontSize', fontsize_axis);
set(gca,'ylim',[-750 750]);
set(gca,'xlim',[t1 t2]);
grid on
subplot 212
plot(time,ug_u,'-','LineWidth',tratto3,'Color',colore1);
hold on
plot(time,ug_v,'-','LineWidth',tratto3,'Color',colore2);
hold on
plot(time,ug_w,'-','LineWidth',tratto3,'Color',colore3);
hold off
title('Grid Voltages','Interpreter','latex','FontSize',fontsize_title);
legend('$u_{\mathrm{grid}}^{\mathrm{u}}$','$u_{\mathrm{grid}}^{\mathrm{v}}$',...
    '$u_{\mathrm{grid}}^{\mathrm{w}}$','Location','northeastoutside',...
    'Interpreter','latex','FontSize',fontsize_legend);
xlabel('Time - [s]','Interpreter','latex','FontSize', fontsize_axis);
ylabel('Voltage - [V]','Interpreter','latex','FontSize', fontsize_axis);
set(gca,'ylim',[-750 750]);
set(gca,'xlim',[t1 t2]);
grid on
h=gcf;
set(h,'PaperOrientation','landscape');
set(h,'PaperUnits','normalized');
set(h,'PaperPosition', [0 0 1 1]);
print('voltage_dip_reference_with_zoom','-depsc');
movefile('voltage_dip_reference_with_zoom.eps', 'figures');