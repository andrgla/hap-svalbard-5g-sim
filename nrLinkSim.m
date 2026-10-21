function res = nrLinkSim(p, dir, xBear, snrdB, fd, K, nSlots, mode)
%NRLINKSIM 5G NR PUSCH (UL) or PDSCH (DL) link simulation over the HAP channel.
%   res = nrLinkSim(p, dir, xBear, snrdB, fd, K, nSlots, mode)
%   snrdB is the per-RE SNR of the strongest HAP path; the weaker path is
%   scaled by its link-budget difference. The receiver uses practical
%   timing and DM-RS channel estimation, MMSE equalisation (MRC across both
%   HAP receivers in UL) and LDPC decoding. There is no HARQ, so BLER is the
%   first-transmission BLER.
%
%   Output fields: snrdB, bler, tput [bit/s], tbs [bit], peak [bit/s].

if nargin < 8, mode = "both"; end
dir = upper(string(dir));
isUL = dir == "UL";

carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = p.nr.scs;
carrier.NSizeGrid = p.nr.nPRB;
carrier.CyclicPrefix = 'normal';
ofdmInfo = nrOFDMInfo(carrier);

if isUL
    sch = nrPUSCHConfig;
    sch.TransformPrecoding = false;
else
    sch = nrPDSCHConfig;
end
sch.PRBSet = 0:p.nr.nPRB-1;
sch.SymbolAllocation = [0 carrier.SymbolsPerSlot];
sch.Modulation = p.nr.modulation;
sch.NumLayers = 1;
sch.DMRS.DMRSAdditionalPosition = p.nr.dmrsAddPos;

if isUL
    [schInd, schInfo] = nrPUSCHIndices(carrier, sch);
    enc = nrULSCH;
    dec = nrULSCHDecoder;
else
    [schInd, schInfo] = nrPDSCHIndices(carrier, sch);
    enc = nrDLSCH;
    dec = nrDLSCHDecoder;
end
R = p.nr.codeRate;
tbs = nrTBS(sch.Modulation, 1, numel(sch.PRBSet), schInfo.NREPerPRB, R);
enc.TargetCodeRate = R;
dec.TargetCodeRate = R;
dec.TransportBlockLength = tbs;
dec.MaximumLDPCIterationCount = p.nr.maxLDPCIter;

slotsPerSec = 1000 * p.nr.scs/15;
res.snrdB = snrdB;
res.tbs   = tbs;
res.peak  = tbs * slotsPerSec;
res.bler  = zeros(size(snrdB));
res.tput  = zeros(size(snrdB));

for iSnr = 1:numel(snrdB)
    % Same channel realisation for every SNR point
    ch = makeHapChannel(p, xBear, dir, fd, K, ofdmInfo.SampleRate, 1000, mode);
    N0 = 1/sqrt(2*double(ofdmInfo.Nfft)*10^(snrdB(iSnr)/10));
    rng(1, 'twister');
    nErr = 0;
    offset = 0;

    for s = 0:nSlots-1
        carrier.NSlot = s;
        if isUL
            dmrsInd = nrPUSCHDMRSIndices(carrier, sch);
            dmrsSym = nrPUSCHDMRS(carrier, sch);
        else
            dmrsInd = nrPDSCHDMRSIndices(carrier, sch);
            dmrsSym = nrPDSCHDMRS(carrier, sch);
        end

        % Transmitter
        trBlk = randi([0 1], tbs, 1);
        if isUL
            setTransportBlock(enc, trBlk);
            cw  = enc(sch.Modulation, 1, schInfo.G, 0);
            sym = nrPUSCH(carrier, sch, cw);
        else
            setTransportBlock(enc, trBlk);
            cw  = enc(sch.Modulation, 1, schInfo.G, 0);
            sym = nrPDSCH(carrier, sch, cw);
        end
        txGrid = nrResourceGrid(carrier);
        txGrid(schInd)  = sym;
        txGrid(dmrsInd) = dmrsSym;
        tx = nrOFDMModulate(carrier, txGrid);

        % Channel and noise
        rx = applyHapChannel(ch, tx);
        rx = rx + N0*complex(randn(size(rx)), randn(size(rx)));

        % Timing, demodulation and channel estimation
        t = nrTimingEstimate(carrier, rx, dmrsInd, dmrsSym);
        if t <= ch.pad
            offset = t;
        end
        rx = rx(1+offset:end, :);
        rxGrid = nrOFDMDemodulate(carrier, rx);
        nSym = carrier.SymbolsPerSlot;
        if size(rxGrid, 2) < nSym
            rxGrid(:, end+1:nSym, :) = 0;
        end
        rxGrid = rxGrid(:, 1:nSym, :);
        [hEst, nVar] = nrChannelEstimate(carrier, rxGrid, dmrsInd, dmrsSym, ...
            'CDMLengths', sch.DMRS.CDMLengths);

        % Equalise (MMSE; MRC across the two HAP receivers in UL)
        [schRx, schH] = nrExtractResources(schInd, rxGrid, hEst);
        [schEq, csi]  = nrEqualizeMMSE(schRx, schH, nVar);

        % Demodulate, apply CSI weights and decode
        if isUL
            [llr, rxSym] = nrPUSCHDecode(carrier, sch, schEq, nVar);
            csi = nrLayerDemap(csi);
            Qm  = numel(llr)/numel(rxSym);
            w   = repmat(csi{1}.', Qm, 1);
            llr = llr .* w(:);
            resetSoftBuffer(dec, 0);
            [~, blkErr] = dec(llr, sch.Modulation, 1, 0);
        else
            [llr, rxSym] = nrPDSCHDecode(carrier, sch, schEq, nVar);
            csi = nrLayerDemap(csi);
            Qm  = numel(llr{1})/numel(rxSym{1});
            w   = repmat(csi{1}.', Qm, 1);
            llr{1} = llr{1} .* w(:);
            resetSoftBuffer(dec, 0);
            [~, blkErr] = dec(llr, sch.Modulation, 1, 0);
        end
        nErr = nErr + blkErr;
    end

    res.bler(iSnr) = nErr/nSlots;
    res.tput(iSnr) = (1 - res.bler(iSnr)) * res.peak;
end
end
