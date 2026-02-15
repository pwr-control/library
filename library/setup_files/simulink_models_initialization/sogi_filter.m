function sogi = sogi_filter(omega, delta, ts)
    options = bodeoptions;
    options.FreqUnits = 'Hz';
    s = tf('s')';

    sogi.flt.alpha = delta*omega*s/(s^2 + delta*omega*s + omega^2);
    sogi.flt.beta = delta*omega^2/(s^2 + delta*omega*s + omega^2);
    
    sogi.fltd.alpha = c2d(sogi.flt.alpha, ts);
    sogi.fltd.beta = c2d(sogi.flt.beta, ts);


    % 1. Define frequency range in Hz (10 Hz to 10 kHz)
    freq_Hz = logspace(1, 3, 1000); 

    % 2. Convert Hz to Rad/s for the bode function
    w_rad = 2 * pi * freq_Hz; 

    % 3. Calculate Bode data (Note: No 'options' argument here)
    [mag_alpha, phase_alpha] = bode(sogi.fltd.alpha, w_rad); 
    [mag_beta, phase_beta] = bode(sogi.fltd.beta, w_rad); 

    % 4. Clean up dimensions (bode returns 3D arrays)
    mag_alpha = squeeze(mag_alpha); 
    mag_beta = squeeze(mag_beta); 
    phase_alpha = squeeze(phase_alpha);
    phase_beta = squeeze(phase_beta);

    % 5. (Optional) Convert Magnitude to dB if needed
    mag_alpha_dB = 20 * log10(mag_alpha);
    mag_beta_dB = 20 * log10(mag_beta);

    % 3. Plot Magnitude (Top Subplot)
    figure('Color', 'w'); % Create white background figure
    subplot 211;
    semilogx(freq_Hz, mag_alpha_dB, 'Color', [0.25 0.25 0.25], ...
    'LineWidth', 2, 'LineStyle', '-');
    hold on
    semilogx(freq_Hz, mag_beta_dB, 'Color', [0.5 0.5 0.5], ...
    'LineWidth', 2, 'LineStyle', '-');
    hold off
    title('Bode Magnitude Sogi Alpha/Beta');
    ylabel('A/dB');
    grid on;
    set(gca, 'FontSize', 12); % Adjust font size for axes
    set(gca, 'xlim', [freq_Hz(1) freq_Hz(end)]);
    
    % 4. Plot Phase (Bottom Subplot)
    subplot 212;
    semilogx(freq_Hz, phase_alpha, ...
        'Color', [0.25 0.25 0.25],'LineWidth', 2, 'LineStyle', '-');
    hold on
    semilogx(freq_Hz, phase_beta, ...
    'Color', [0.5 0.5 0.5],'LineWidth', 2, 'LineStyle', '-');
    hold off
    title('Bode Phase Sogi Alpha/Beta');
    xlabel('f/Hz');
    ylabel('Phase (deg)');
    grid on;
    set(gca, 'FontSize', 12);
    set(gca, 'xlim', [freq_Hz(1) freq_Hz(end)]);

end