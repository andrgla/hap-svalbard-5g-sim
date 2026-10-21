function lb = linkBudget(p, xBear, dir)
%LINKBUDGET Static link budget from each HAP to a bear at position xBear.
%   dir is "DL" (HAP -> bear) or "UL" (bear -> HAP). Per-HAP quantities
%   are N-by-2 (columns HAP A, HAP B). The combined SNR is the incoherent
%   power sum (DL: both HAPs transmit; UL: MRC of both HAP receivers).

g = hapGeometry(p, xBear);
lb.fspl  = 20*log10(4*pi*g.r*p.fc/p.c);
lb.Lfix  = p.Lgas + p.Lrain + p.As;
lb.Ghap  = hapAntennaGain(p, g.psi);

if upper(string(dir)) == "DL"
    lb.Prx_dBm = p.PtHAP_dBm + lb.Ghap + p.Gbear - lb.fspl - lb.Lfix;
else
    lb.Prx_dBm = p.PtBear_dBm + p.Gbear + lb.Ghap - lb.fspl - lb.Lfix;
end

lb.noise_dBm = p.N0_dBmHz + 10*log10(p.B);
lb.SNR       = lb.Prx_dBm - lb.noise_dBm;          % per HAP [dB]
lb.SNRmax    = max(lb.SNR, [], 2);                 % strongest HAP [dB]
lb.SNRcomb   = 10*log10(sum(10.^(lb.SNR/10), 2));  % combined [dB]
lb.dL        = abs(lb.fspl(:,1) - lb.fspl(:,2));   % path-loss difference [dB]

% Two-path interference metrics (notes eq. 28)
a = 10.^(lb.Prx_dBm/20);
lb.CI        = 20*log10(max(a,[],2) ./ min(a,[],2));
lb.fadeDepth = 20*log10(sum(a,2) ./ abs(a(:,1) - a(:,2)));

% Shannon capacity
lb.C = p.B * log2(1 + 10.^(lb.SNRcomb/10));
lb.g = g;
end
