function rx = applyHapChannel(ch, tx)
%APPLYHAPCHANNEL Pass a waveform through a channel from makeHapChannel.
%   tx is padded with ch.pad zeros so that all delayed energy is kept.
%   DL returns one column (sum of the HAP paths); UL returns one column
%   per HAP receiver. A slow log-normal scintillation gain is drawn per call.

tx = [tx; zeros(ch.pad, size(tx, 2))];
nP = numel(ch.tdl);
y  = complex(zeros(size(tx, 1), nP));
for k = 1:nP
    yk = ch.tdl{k}(tx);
    yk = fracDelay(yk, ch.delaySamp(k));
    scint = 10^(ch.sigmaScint*randn/20);
    y(:, k) = ch.amp(k) * scint * exp(1j*ch.phase(k)) * yk;
end

if ch.dir == "DL"
    rx = sum(y, 2);
else
    rx = y;
end
end

function y = fracDelay(x, d)
% Delay x by d samples (fractional) in the frequency domain.
if d == 0
    y = x;
    return
end
N = size(x, 1);
Nfft = 2^nextpow2(N + ceil(d) + 1);
k = [0:Nfft/2-1, -Nfft/2:-1].' / Nfft;
Y = ifft(fft(x, Nfft) .* exp(-1j*2*pi*k*d));
y = Y(1:N, :);
end
