function ch = makeHapChannel(p, xBear, dir, fd, K, Fs, seed, mode)
%MAKEHAPCHANNEL Two-HAP channel for a bear at position xBear.
%   Each HAP path is an independent single-tap Rician nrTDLChannel (LOS
%   plus local ground scattering, K-factor K [dB], max Doppler fd [Hz]).
%   Paths are scaled by their link-budget amplitude relative to the
%   strongest HAP and given the carrier phase 2*pi*r/lambda plus a random
%   transmitter phase offset (notes eq. 26-27).
%
%   dir  "DL": both HAPs transmit the same waveform. The paths add up at
%              the bear with their relative delay (two-path channel).
%        "UL": each HAP receives on its own; the output has one column per
%              HAP (combined by MRC in the receiver).
%   mode "both" (default) uses both HAPs, "single" only the strongest one.
%
%   Apply the channel with applyHapChannel.

if nargin < 8, mode = "both"; end
dir  = upper(string(dir));
mode = lower(string(mode));

lb = linkBudget(p, xBear, dir);
g  = lb.g;

if mode == "single"
    [~, hapIdx] = max(lb.Prx_dBm);
else
    hapIdx = 1:2;
end

rs = RandStream('mt19937ar', 'Seed', seed);
txPhase = 2*pi*rand(rs, 1, 2);

ch.dir   = dir;
ch.hap   = hapIdx;
ch.tdl   = cell(1, numel(hapIdx));
ch.amp   = zeros(1, numel(hapIdx));
ch.phase = zeros(1, numel(hapIdx));
ch.delaySamp = zeros(1, numel(hapIdx));
ch.sigmaScint = p.sigmaScint;

PrxMax = max(lb.Prx_dBm(hapIdx));
tauMin = min(g.tau(hapIdx));
for k = 1:numel(hapIdx)
    i = hapIdx(k);
    tdl = nrTDLChannel;
    tdl.DelayProfile        = 'Custom';
    tdl.PathDelays          = 0;
    tdl.AveragePathGains    = 0;
    tdl.FadingDistribution  = 'Rician';
    tdl.KFactorFirstTap     = K;
    tdl.MaximumDopplerShift = fd;
    tdl.SampleRate          = Fs;
    tdl.NumTransmitAntennas = 1;
    tdl.NumReceiveAntennas  = 1;
    tdl.RandomStream        = 'mt19937ar with seed';
    tdl.Seed                = seed + i;
    ch.tdl{k} = tdl;

    ch.amp(k)   = 10^((lb.Prx_dBm(i) - PrxMax)/20);
    ch.phase(k) = mod(2*pi*g.r(i)/p.lambda, 2*pi) + txPhase(i);
    if dir == "DL"
        ch.delaySamp(k) = (g.tau(i) - tauMin) * Fs;
    end
end

chInfo = info(ch.tdl{1});
ch.filterDelay = chInfo.ChannelFilterDelay;
ch.pad = ceil(max(ch.delaySamp)) + chInfo.MaximumChannelDelay + 8;

% Operating SNR of the strongest used HAP path (SNR reference)
ch.SNRop = max(lb.SNR(hapIdx));
ch.lb = lb;
end
