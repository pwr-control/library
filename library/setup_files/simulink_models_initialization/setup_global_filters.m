function filters = setup_global_filters(ts_afe, ts_inv, ts_dab, tc)

filters.afe.ts_afe = ts_afe;
filters.afe.ts_inv = ts_inv;
filters.afe.ts_dab = ts_dab;
filters.afe.tc = tc;

s=tf('s');

    %% LPF 50Hz in state space (for initialization)
    fcut = 50;
    
    % continous time
    fof = 1/(s/(2*pi*fcut)+1);
    [nfof, dfof] = tfdata(fof,'v');
    [A,B,C,D] = tf2ss(nfof,dfof);
    LVRT_flt_ss_c = ss(A,B,C,D);
    filters.afe.LVRT_flt_ss_c = LVRT_flt_ss_c;
    PT1_flt_50Hz_ss_c = ss(A,B,C,D);
    filters.inv.PT1_flt_50Hz_ss_c = PT1_flt_50Hz_ss_c;

    % afe discrete time
    [nfofd, dfofd] = tfdata(c2d(fof,ts_afe),'v');
    [A,B,C,D] = tf2ss(nfofd,dfofd);
    LVRT_flt_ss = ss(A,B,C,D,ts_afe);
    filters.afe.LVRT_flt_ss = LVRT_flt_ss;
    
    % afe discrete time  
    [nfofd, dfofd] = tfdata(c2d(fof,ts_inv),'v');
    [A,B,C,D] = tf2ss(nfofd,dfofd);
    PT1_flt_50Hz_ss = ss(A,B,C,D,ts_inv);
    filters.inv.PT1_flt_50Hz_ss = PT1_flt_50Hz_ss;

    %% SOF 50Hz in state space (for initialization)
    fcut = 50;
    
    % continous time
    sof = 1/(s/(2*pi*fcut)+1)^2;
    [nsof, dsof] = tfdata(sof,'v');
    [A,B,C,D] = tf2ss(nsof,dsof);
    SOF_50Hz_ss_c = ss(A,B,C,D);
    filters.afe.SOF_50Hz_ss_c = SOF_50Hz_ss_c;
    filters.inv.SOF_50Hz_ss_c = SOF_50Hz_ss_c;

    % afe discrete time
    [nsofd, dsofd] = tfdata(c2d(sof,ts_afe),'v');
    [A,B,C,D] = tf2ss(nsofd,dsofd);
    SOF_50Hz_ss = ss(A,B,C,D,ts_afe);
    filters.afe.SOF_50Hz_ss = SOF_50Hz_ss;
    
    % afe discrete time  
    [nsofd, dsofd] = tfdata(c2d(sof,ts_inv),'v');
    [A,B,C,D] = tf2ss(nsofd,dsofd);
    SOF_50Hz_ss = ss(A,B,C,D,ts_inv);
    filters.inv.SOF_50Hz_ss = SOF_50Hz_ss;

    %% LPF 161Hz
    fcut_161Hz_flt = 161;
    g0_161Hz = fcut_161Hz_flt * ts_afe * 2*pi;
    g1_161Hz = 1 - g0_161Hz;
    
    filters.afe.g0_161Hz = g0_161Hz;
    filters.afe.g1_161Hz = g1_161Hz;

    g0_161Hz = fcut_161Hz_flt * ts_inv * 2*pi;
    g1_161Hz = 1 - g0_161Hz;
    
    filters.inv.g0_161Hz = g0_161Hz;
    filters.inv.g1_161Hz = g1_161Hz;
    %% LPF 500Hz
    fcut_500Hz_flt = 500;
    g0_500Hz = fcut_500Hz_flt * ts_afe * 2*pi;
    g1_500Hz = 1 - g0_500Hz;
    
    filters.afe.g0_500Hz = g0_500Hz;
    filters.afe.g1_500Hz = g1_500Hz;
    
    g0_500Hz = fcut_500Hz_flt * ts_inv * 2*pi;
    g1_500Hz = 1 - g0_500Hz;
    
    filters.inv.g0_500Hz = g0_500Hz;
    filters.inv.g1_500Hz = g1_500Hz;

    %% LPF 75Hz
    fcut_75Hz_flt = 75;
    g0_75Hz = fcut_75Hz_flt * ts_afe * 2*pi;
    g1_75Hz = 1 - g0_75Hz;
    
    filters.afe.g0_75Hz = g0_75Hz;
    filters.afe.g1_75Hz = g1_75Hz;
    
    %% LPF 50Hz
    fcut_50Hz_flt = 50;
    g0_50Hz = fcut_50Hz_flt * ts_afe * 2*pi;
    g1_50Hz = 1 - g0_50Hz;
    
    filters.afe.g0_50Hz = g0_50Hz;
    filters.afe.g1_50Hz = g1_50Hz;
    
    %% LPF 10Hz
    fcut_10Hz_flt = 10;
    g0_10Hz = fcut_10Hz_flt * ts_afe * 2*pi;
    g1_10Hz = 1 - g0_10Hz;
    
    filters.afe.g0_10Hz = g0_10Hz;
    filters.afe.g1_10Hz = g1_10Hz;

    g0_10Hz = fcut_10Hz_flt * ts_inv * 2*pi;
    g1_10Hz = 1 - g0_10Hz;
    
    filters.inv.g0_10Hz = g0_10Hz;
    filters.inv.g1_10Hz = g1_10Hz;
    
    %% LPF 4Hz
    fcut_4Hz_flt = 4;
    g0_4Hz = fcut_4Hz_flt * ts_afe * 2*pi;
    g1_4Hz = 1 - g0_4Hz;
    
    filters.afe.g0_4Hz = g0_4Hz;
    filters.afe.g1_4Hz = g1_4Hz;
 
    g0_4Hz = fcut_4Hz_flt * ts_inv * 2*pi;
    g1_4Hz = 1 - g0_4Hz;
    
    filters.inv.g0_4Hz = g0_4Hz;
    filters.inv.g1_4Hz = g1_4Hz;
    %% LPF 1Hz
    fcut_1Hz_flt = 1;
    g0_1Hz = fcut_1Hz_flt * ts_afe * 2*pi;
    g1_1Hz = 1 - g0_1Hz;
    
    filters.afe.g0_1Hz = g0_1Hz;
    filters.afe.g1_1Hz = g1_1Hz;
    
    g0_1Hz = fcut_1Hz_flt * ts_inv * 2*pi;
    g1_1Hz = 1 - g0_1Hz;
    
    filters.inv.g0_1Hz = g0_1Hz;
    filters.inv.g1_1Hz = g1_1Hz;
    
    %% LPF 0.2Hz
    fcut_0Hz2_flt = 0.2;
    g0_0Hz2 = fcut_0Hz2_flt * ts_afe * 2*pi;
    g1_0Hz2 = 1 - g0_0Hz2;
    
    filters.afe.g0_0Hz2 = g0_0Hz2;
    filters.afe.g1_0Hz2 = g1_0Hz2;
    
    %% Speed obserfer filter LPF 10Hz
    fcut_10Hz_flt = 10;
    omega_flt_g0_10Hz = fcut_10Hz_flt * ts_inv * 2*pi;
    omega_flt_g1_10Hz = 1 - omega_flt_g0_10Hz;
    
    filters.inv.omega_flt_g0_10Hz = omega_flt_g0_10Hz;
    filters.inv.omega_flt_g1_10Hz = omega_flt_g1_10Hz;

end