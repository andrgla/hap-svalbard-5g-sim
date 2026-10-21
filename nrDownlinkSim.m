function res = nrDownlinkSim(p, xBear, snrdB, fd, K, nSlots, mode)
%NRDOWNLINKSIM 5G NR PDSCH from the HAP(s) to the bear; see nrLinkSim.
%   mode "both" has both HAPs transmit the same waveform (two-path channel
%   with delay difference up to 60 us), "single" uses only the strongest HAP.
if nargin < 7, mode = "both"; end
res = nrLinkSim(p, "DL", xBear, snrdB, fd, K, nSlots, mode);
end
