function res = nrUplinkSim(p, xBear, snrdB, fd, K, nSlots, mode)
%NRUPLINKSIM 5G NR PUSCH from the bear to the HAP(s); see nrLinkSim.
%   mode "both" combines both HAP receivers by MRC, "single" uses only the
%   strongest HAP.
if nargin < 7, mode = "both"; end
res = nrLinkSim(p, "UL", xBear, snrdB, fd, K, nSlots, mode);
end
