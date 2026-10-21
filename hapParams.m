function p = hapParams()
%HAPPARAMS System parameters for the Svalbard two-HAP polar-bear link.
%   All values are taken from the course notes (src/TTT09-Radio_cource.pdf).
%   Bear position x is measured along the line between the HAPs, with
%   HAP A directly above x = 0 and HAP B above x = p.dHAP.

% Physical constants (c = 3e8 to match the numbers in the notes)
p.c  = 3e8;                 % speed of light [m/s]
p.kB = 1.380649e-23;        % Boltzmann constant [J/K]

% Geometry
p.h     = 18e3;             % HAP altitude [m]
p.dHAP  = 31.2e3;           % HAP-HAP spacing [m] (Tab. 4/5; p.3 uses 50 km)
p.xHAP  = [0 p.dHAP];       % HAP ground positions [m]
p.yHAP  = [0 0];

% Carrier
p.fc     = 2e9;             % carrier frequency [Hz]
p.lambda = p.c/p.fc;        % wavelength [m]

% HAP antenna (cos^n beam, -3 dB at psiB from nadir)
p.Gm          = 3.15;       % peak gain [dBi]
p.psiB        = 60;         % half beamwidth [deg]
p.sidelobeDB  = 20;         % floor below peak [dB]

% Transmit powers and bear antenna
p.PtHAP_dBm  = 20;                  % HAP transmit power [dBm]
p.PtBear_dBm = 10*log10(120);       % bear transmit power, 120 mW [dBm]
p.Gbear      = 0;                   % bear antenna gain [dBi]

% Fixed propagation losses at 2 GHz [dB]
p.Lgas   = 0.034513;        % P.676 summer, high latitude
p.Lrain  = 0.0038411513;    % P.618, 0.01 % of time
p.As     = 0.220;           % P.618 scintillation depth, 0.01 % (margin)
p.sigmaScint = 0.0306;      % scintillation standard deviation [dB]

% Noise
p.T     = 266;                              % noise temperature [K]
p.N0_dBmHz = 10*log10(p.kB*p.T) + 30;       % approx. -174.35 dBm/Hz
p.B     = 2e6;                              % system bandwidth [Hz]

% Small-scale fading
p.fd    = [13 96];          % max Doppler: walking / sprinting bear [Hz]
p.K_dB  = 10;               % Rician K-factor of each HAP path [dB] (assumed)

% Throughput target
p.Rtarget = 2e6;            % HD video uplink [bit/s]

% 5G NR configuration (standard numerology)
p.nr.scs        = 15;       % subcarrier spacing [kHz]
p.nr.nPRB       = 11;       % 11 PRB = 1.98 MHz
p.nr.modulation = '16QAM';
p.nr.codeRate   = 378/1024; % MCS 10 (table 1), approx. 2.1 Mbit/s
p.nr.dmrsAddPos = 2;        % 3 DM-RS symbols per slot (mobility)
p.nr.maxLDPCIter = 12;

% Custom narrowband OFDM design (from the notes, 13.10 and 20.10)
p.cu.Fs           = 2.048e6;    % sample rate [Hz]
p.cu.Nfft         = 2048;       % gives 1 kHz subcarrier spacing
p.cu.Nact         = 2000;       % active subcarriers (DC unused)
p.cu.cpLen        = round(116e-6*p.cu.Fs);  % CP 116 us > 60 us max delay
p.cu.pilotSpacing = 4;          % pilot every 4th active subcarrier
p.cu.nSymPerFrame = 10;         % OFDM symbols per codeword
p.cu.M            = 8;          % 8PSK
p.cu.codeRate     = 1/2;
p.cu.maxLDPCIter  = 12;
end
