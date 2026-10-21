%RUNALL Two-HAP Svalbard link simulation: 5G NR vs custom narrowband OFDM.
%   Requires 5G Toolbox and Communications Toolbox. Set quick = false for
%   the full run (slow); quick = true is a smoke test.

clear; close all;
quick = true;

v = ver;
assert(any(strcmp({v.Name}, '5G Toolbox')) && any(strcmp({v.Name}, 'Communications Toolbox')), ...
    'runAll needs 5G Toolbox and Communications Toolbox (install via Add-On Explorer).');

p = hapParams();
xVec  = [0 3.9 7.8 11.7 15.6]*1e3;     % bear positions (Tab. 4)
fdVec = p.fd;                           % walking / sprinting Doppler
K     = p.K_dB;
if quick
    nSlots = 20;  nFrames = 4;   snrVec = 0:4:20;
else
    nSlots = 300; nFrames = 40;  snrVec = -2:2:20;
end

% Systems: name, direction, simulator
sys = { ...
    'NR DL, both HAPs',     "DL", @(x,s,fd) nrDownlinkSim(p, x, s, fd, K, nSlots, "both");
    'NR DL, single HAP',    "DL", @(x,s,fd) nrDownlinkSim(p, x, s, fd, K, nSlots, "single");
    'Custom DL, both HAPs', "DL", @(x,s,fd) customOfdmSim(p, "DL", x, s, fd, K, nFrames, "both");
    'NR UL, MRC',           "UL", @(x,s,fd) nrUplinkSim(p, x, s, fd, K, nSlots, "both");
    'Custom UL, MRC',       "UL", @(x,s,fd) customOfdmSim(p, "UL", x, s, fd, K, nFrames, "both")};
nSys = size(sys, 1);
nX = numel(xVec); nS = numel(snrVec); nF = numel(fdVec);

bler   = zeros(nSys, nX, nS, nF);
peak   = zeros(nSys, 1);
tputOp = zeros(nSys, nX, nF);
snrOp  = zeros(nSys, nX);

for iSys = 1:nSys
    for ix = 1:nX
        lb = linkBudget(p, xVec(ix), sys{iSys,2});
        snrOp(iSys, ix) = lb.SNRmax;
        for ifd = 1:nF
            fprintf('%-22s x = %4.1f km, fd = %2d Hz\n', sys{iSys,1}, xVec(ix)/1e3, fdVec(ifd));
            r = sys{iSys,3}(xVec(ix), snrVec, fdVec(ifd));
            bler(iSys, ix, :, ifd) = r.bler;
            peak(iSys) = r.peak;
            rOp = sys{iSys,3}(xVec(ix), snrOp(iSys, ix), fdVec(ifd));
            tputOp(iSys, ix, ifd) = rOp.tput;
        end
    end
end
save('runAllResults.mat', 'p', 'xVec', 'fdVec', 'snrVec', 'sys', 'bler', 'peak', 'tputOp', 'snrOp');

fprintf('\nPeak rates:\n');
for iSys = 1:nSys
    fprintf('  %-22s %.2f Mbit/s\n', sys{iSys,1}, peak(iSys)/1e6);
end

% Figure 1: BLER vs SNR per bear position
cols = lines(nSys);
figure('Name', 'BLER vs SNR', 'Position', [50 50 1500 450]);
tl = tiledlayout(1, nX, 'TileSpacing', 'compact');
for ix = 1:nX
    nexttile; hold on;
    for iSys = 1:nSys
        for ifd = 1:nF
            b = max(squeeze(bler(iSys, ix, :, ifd)), 1e-3);
            ls = '-'; if ifd == 2, ls = '--'; end
            h = semilogy(snrVec, b, ls, 'Color', cols(iSys,:), 'LineWidth', 1.3);
            if ifd == 1, h.DisplayName = sys{iSys,1}; else, h.HandleVisibility = 'off'; end
        end
    end
    set(gca, 'YScale', 'log'); ylim([1e-3 1]); grid on;
    title(sprintf('x = %.1f km', xVec(ix)/1e3));
    xlabel('SNR of strongest HAP path [dB]');
    if ix == 1, ylabel('BLER'); end
end
legend('Location', 'southwest');
title(tl, sprintf('BLER, solid f_D = %d Hz, dashed f_D = %d Hz, K = %d dB', fdVec(1), fdVec(2), K));

% Figure 2: throughput at the link-budget operating SNR
figure('Name', 'Throughput at operating point');
hold on;
for iSys = 1:nSys
    plot(xVec/1e3, squeeze(tputOp(iSys, :, 1))/1e6, '-o', 'Color', cols(iSys,:), ...
        'LineWidth', 1.3, 'DisplayName', sys{iSys,1});
    plot(xVec/1e3, squeeze(tputOp(iSys, :, 2))/1e6, '--x', 'Color', cols(iSys,:), ...
        'LineWidth', 1.3, 'HandleVisibility', 'off');
end
yline(p.Rtarget/1e6, 'k:', '2 Mbit/s target', 'HandleVisibility', 'off');
grid on; xlabel('Bear position x [km] (HAP A at 0, midpoint at 15.6)');
ylabel('Throughput [Mbit/s]'); legend('Location', 'southwest');
title('Throughput at the link-budget SNR (solid: walking, dashed: sprinting)');

% Figure 3: bear transmit power needed for BLER <= 10 % (uplink)
ulSys = find([sys{:,2}] == "UL");
figure('Name', 'Required bear transmit power');
hold on;
for iSys = ulSys
    for ifd = 1:nF
        PtReq = nan(1, nX);
        for ix = 1:nX
            snrReq = requiredSnr(snrVec, squeeze(bler(iSys, ix, :, ifd)), 0.1);
            PtReq(ix) = p.PtBear_dBm + snrReq - snrOp(iSys, ix);
        end
        ls = '-o'; if ifd == 2, ls = '--x'; end
        h = semilogy(xVec/1e3, 10.^(PtReq/10), ls, 'Color', cols(iSys,:), 'LineWidth', 1.3);
        h.DisplayName = sprintf('%s, f_D = %d Hz', sys{iSys,1}, fdVec(ifd));
    end
end
lbU = linkBudget(p, xVec, "UL");
snrShannon = 10*log10(2^(p.Rtarget/p.B) - 1);
semilogy(xVec/1e3, 10.^((p.PtBear_dBm + snrShannon - lbU.SNRcomb)/10), 'k-', ...
    'LineWidth', 1.5, 'DisplayName', 'Shannon, 2 Mbit/s (MRC SNR)');
yline(67.46, 'k:', 'Notes: 67.46 mW', 'HandleVisibility', 'off');
yline(10^(p.PtBear_dBm/10), 'k-.', '120 mW', 'HandleVisibility', 'off');
set(gca, 'YScale', 'log'); grid on;
xlabel('Bear position x [km]'); ylabel('Required bear P_t [mW]');
legend('Location', 'best'); title('Bear transmit power for BLER \leq 10 %');

% Figure 4: two-path downlink frequency response
figure('Name', 'Downlink two-path frequency response');
f = linspace(-50e3, 50e3, 4001);
lbD = linkBudget(p, xVec, "DL");
hold on;
for ix = 1:nX-1
    a = 10^(-lbD.dL(ix)/20);
    H = abs(1 + a*exp(-1j*2*pi*f*lbD.g.dtau(ix))).^2;
    plot(f/1e3, 10*log10(H), 'LineWidth', 1.2, 'DisplayName', ...
        sprintf('x = %.1f km, \\Delta\\tau = %.0f \\mus, notch spacing %.1f kHz', ...
        xVec(ix)/1e3, lbD.g.dtau(ix)*1e6, 1e-3/lbD.g.dtau(ix)));
end
xline(-45:15:45, ':', 'HandleVisibility', 'off');
grid on; xlabel('Frequency offset [kHz] (dotted: NR 15 kHz subcarrier grid)');
ylabel('|H(f)|^2 [dB]'); legend('Location', 'southoutside');
title('Downlink channel with both HAPs transmitting (LOS only)');

% Save the figures for the README
if ~exist('figures', 'dir'), mkdir('figures'); end
names = {'bler_vs_snr', 'throughput_at_operating_point', 'required_bear_power', 'downlink_frequency_response'};
figs = findobj('Type', 'figure');
[~, order] = sort([figs.Number]);
figs = figs(order);
for i = 1:numel(figs)
    exportgraphics(figs(i), fullfile('figures', [names{i} '.png']), 'Resolution', 130);
end

function snrReq = requiredSnr(snr, b, target)
% Lowest SNR where BLER drops to the target (log-linear interpolation).
b = max(b(:).', 1e-4);
i = find(b <= target, 1);
if isempty(i)
    snrReq = NaN;
elseif i == 1
    snrReq = snr(1);
else
    snrReq = interp1(log10(b(i-1:i)), snr(i-1:i), log10(target));
end
end
