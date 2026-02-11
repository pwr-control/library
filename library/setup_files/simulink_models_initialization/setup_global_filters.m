%% Settings for First Order Low Pass Filters


%% LPF 50Hz in state space (for initialization)
fcut = 50;
fof = 1/(s/(2*pi*fcut)+1);
[nfof, dfof] = tfdata(fof,'v');
[nfofd, dfofd]=tfdata(c2d(fof,ts_afe),'v');
fof_z = tf(nfofd,dfofd,ts_afe,'Variable','z');
[A,B,C,D] = tf2ss(nfofd,dfofd);
LVRT_flt_ss = ss(A,B,C,D,ts_afe);
[A,B,C,D] = tf2ss(nfof,dfof);
LVRT_flt_ss_c = ss(A,B,C,D);

%% LPF 161Hz
fcut_161Hz_flt = 161;
g0_161Hz = fcut_161Hz_flt * ts_afe * 2*pi;
g1_161Hz = 1 - g0_161Hz;

filter_PT1.g0_161Hz = g0_161Hz;
filter_PT1.g1_161Hz = g1_161Hz;

%% LPF 500Hz
fcut_500Hz_flt = 500;
g0_500Hz = fcut_500Hz_flt * ts_afe * 2*pi;
g1_500Hz = 1 - g0_500Hz;

filter_PT1.g0_500Hz = g0_500Hz;
filter_PT1.g1_500Hz = g1_500Hz;

%% LPF 75Hz
fcut_75Hz_flt = 75;
g0_75Hz = fcut_75Hz_flt * ts_afe * 2*pi;
g1_75Hz = 1 - g0_75Hz;

filter_PT1.g0_75Hz = g0_75Hz;
filter_PT1.g1_75Hz = g1_75Hz;

%% LPF 50Hz
fcut_50Hz_flt = 50;
g0_50Hz = fcut_50Hz_flt * ts_afe * 2*pi;
g1_50Hz = 1 - g0_50Hz;

filter_PT1.g0_50Hz = g0_50Hz;
filter_PT1.g1_50Hz = g1_50Hz;

%% LPF 10Hz
fcut_10Hz_flt = 10;
g0_10Hz = fcut_10Hz_flt * ts_afe * 2*pi;
g1_10Hz = 1 - g0_10Hz;

filter_PT1.g0_10Hz = g0_10Hz;
filter_PT1.g1_10Hz = g1_10Hz;

%% LPF 4Hz
fcut_4Hz_flt = 4;
g0_4Hz = fcut_4Hz_flt * ts_afe * 2*pi;
g1_4Hz = 1 - g0_4Hz;

filter_PT1.g0_4Hz = g0_4Hz;
filter_PT1.g1_4Hz = g1_4Hz;

%% LPF 1Hz
fcut_1Hz_flt = 1;
g0_1Hz = fcut_1Hz_flt * ts_afe * 2*pi;
g1_1Hz = 1 - g0_1Hz;

filter_PT1.g0_1Hz = g0_1Hz;
filter_PT1.g1_1Hz = g1_1Hz;

%% LPF 0.2Hz
fcut_0Hz2_flt = 0.2;
g0_0Hz2 = fcut_0Hz2_flt * ts_afe * 2*pi;
g1_0Hz2 = 1 - g0_0Hz2;

filter_PT1.g0_0Hz2 = g0_0Hz2;
filter_PT1.g1_0Hz2 = g1_0Hz2;

%% Speed obserfer filter LPF 10Hz
fcut_10Hz_flt = 10;
omega_flt_g0 = fcut_10Hz_flt * ts_inv * 2*pi;
omega_flt_g1 = 1 - omega_flt_g0;

filter_PT1.omega_flt_g0 = omega_flt_g0;
filter_PT1.omega_flt_g1 = omega_flt_g1;