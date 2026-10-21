function res = customOfdmSim(p, dir, xBear, snrdB, fd, K, nFrames, mode)
%CUSTOMOFDMSIM Link simulation of the team's narrowband OFDM design.
%   1 kHz subcarrier spacing, 116 us CP (longer than the 60 us two-HAP
%   delay), 8PSK with rate-1/2 LDPC (5G LDPC via nrDLSCH) and a random BICM
%   interleaver. A comb of known pilots is used for channel estimation, with
%   spline interpolation across frequency and per-subcarrier ZF (MRC across
%   both HAP receivers in UL). The noise variance is known at the receiver.
%   The channel is the same as for the NR simulation (makeHapChannel).
%
%   Output fields: snrdB, bler, tput [bit/s], tbs [bit], peak [bit/s].

if nargin < 8, mode = "both"; end
dir = upper(string(dir));
cu  = p.cu;
Qm  = log2(cu.M);

% Subcarrier map: Nact active subcarriers centred around (and excluding) DC
kAct   = [-cu.Nact/2:-1, 1:cu.Nact/2].';
binAct = mod(kAct, cu.Nfft) + 1;
isPilot  = false(cu.Nact, 1);
isPilot(1:cu.pilotSpacing:end) = true;
isPilot(end) = true;                      % pilot at the band edge
pilotPos = find(isPilot);
dataPos  = find(~isPilot);
nData    = numel(dataPos);

rsP = RandStream('mt19937ar', 'Seed', 7);
pilots = exp(1j*(pi/4 + pi/2*randi(rsP, [0 3], numel(pilotPos), cu.nSymPerFrame)));

% Coding: 5G DL-SCH chain (CRC, segmentation, LDPC, rate matching). Its
% QPSK mode only sets the rate-matching bit interleaver; the bits are
% mapped to 8PSK here.
G   = nData * cu.nSymPerFrame * Qm;
tbs = 8*floor((G*cu.codeRate - 24)/8);
enc = nrDLSCH('TargetCodeRate', cu.codeRate);
dec = nrDLSCHDecoder('TargetCodeRate', cu.codeRate, ...
    'TransportBlockLength', tbs, 'MaximumLDPCIterationCount', cu.maxLDPCIter);
perm = randperm(RandStream('mt19937ar', 'Seed', 11), G).';

symLen   = cu.Nfft + cu.cpLen;
frameDur = cu.nSymPerFrame * symLen / cu.Fs;
res.snrdB = snrdB;
res.tbs   = tbs;
res.peak  = tbs / frameDur;
res.bler  = zeros(size(snrdB));
res.tput  = zeros(size(snrdB));

for iSnr = 1:numel(snrdB)
    ch = makeHapChannel(p, xBear, dir, fd, K, cu.Fs, 1000, mode);
    snrLin = 10^(snrdB(iSnr)/10);
    N0 = 1/sqrt(2*cu.Nfft*snrLin);
    nVar = 1/snrLin;                       % noise variance per subcarrier
    rng(1, 'twister');
    nErr = 0;

    for f = 1:nFrames
        % Transmitter
        trBlk = randi([0 1], tbs, 1);
        setTransportBlock(enc, trBlk);
        cw = enc('QPSK', 1, G, 0);
        cw = cw(perm);
        dataSym = pskmod(double(cw), cu.M, pi/cu.M, 'gray', 'InputType', 'bit');
        dataSym = reshape(dataSym, nData, cu.nSymPerFrame);

        X = complex(zeros(cu.Nfft, cu.nSymPerFrame));
        X(binAct(pilotPos), :) = pilots;
        X(binAct(dataPos), :)  = dataSym;
        x = ifft(X);
        x = [x(end-cu.cpLen+1:end, :); x];
        tx = x(:);

        % Channel and noise
        rx = applyHapChannel(ch, tx);
        rx = rx + N0*complex(randn(size(rx)), randn(size(rx)));
        rx = rx(1+ch.filterDelay : ch.filterDelay + numel(tx), :);

        % Receiver per HAP branch
        nBr = size(rx, 2);
        num = complex(zeros(nData, cu.nSymPerFrame));
        den = zeros(nData, cu.nSymPerFrame);
        for b = 1:nBr
            y = reshape(rx(:, b), symLen, cu.nSymPerFrame);
            Y = fft(y(cu.cpLen+1:end, :));
            Yact = Y(binAct, :);
            Hp = Yact(pilotPos, :) ./ pilots;
            H  = interp1(pilotPos, Hp, (1:cu.Nact).', 'spline');
            Hd = H(dataPos, :);
            num = num + conj(Hd) .* Yact(dataPos, :);
            den = den + abs(Hd).^2;
        end
        eq = num ./ den;
        nvEq = nVar ./ den;

        % Soft demodulation (max-log LLR scales with 1/noise variance)
        llr = pskdemod(eq(:), cu.M, pi/cu.M, 'gray', ...
            'OutputType', 'approxllr', 'NoiseVariance', 1);
        llr = reshape(llr, Qm, []) ./ nvEq(:).';
        llrDe = zeros(G, 1);
        llrDe(perm) = llr(:);

        resetSoftBuffer(dec, 0);
        [~, blkErr] = dec(llrDe, 'QPSK', 1, 0);
        nErr = nErr + blkErr;
    end

    res.bler(iSnr) = nErr/nFrames;
    res.tput(iSnr) = (1 - res.bler(iSnr)) * res.peak;
end
end
