function G = hapAntennaGain(p, psi)
%HAPANTENNAGAIN HAP antenna gain [dBi] at angle psi [deg] from nadir.
%   cos^n main lobe with the -3 dB point at p.psiB (shape as in ITU-R
%   F.1336), limited to a floor p.sidelobeDB below the peak.

n = log(10^(-3/10)) / log(cosd(p.psiB));
G = p.Gm + 10*n*log10(max(cosd(psi), eps));
G = max(G, p.Gm - p.sidelobeDB);
end
