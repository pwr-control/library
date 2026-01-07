% Copyright 2025 Caleb E. Thomas
% 
% Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
% 
% 1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
% 2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
% 3) Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
% IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; 
% OR BUSINESS 

% Create dummy data
x = linspace(0,4*pi, 1201);
y = sin(x) + cos(60*x)/20;

% create figure and plot
f = figure('position', [696 276 960 614]);
ax = axes(f, 'position', [0.1300 0.1100 0.7750 0.8150]);

% plot data
ph = plot(x, y);

% set axis range and labels
ax.XLim = [min(x), max(x)];
ax.XLimMode = 'Manual';
title(ax, ' Sample Signal', 'fontsize', 24);
xlabel(ax, 'Space [m]');
ylabel(ax, 'Amplitude');
grid on

% create first zoomed object
zoomed_region = [0,0,1,1];
zax1  = zoomed_axes(ax, zoomed_region);
zax1.Position   = [0.341, 0.635, 0.174, 0.225];
zax1.ZoomRegion = [1.110, 0.844, 2.049, 1.096];
title(zax1, '(a)');
grid on

% create second zoomed object
zax2 = zoomed_axes(ax, zoomed_region);
zax2.Position = [0.559, 0.178, 0.140, 0.194];
zax2.ZoomRegion = [10.417, -1.104, 11.626, -0.784];
title(zax2, '(b)');
grid on

