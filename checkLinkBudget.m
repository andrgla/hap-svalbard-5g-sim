%CHECKLINKBUDGET Check the MATLAB model against numbers in the course notes.
%   Uses base MATLAB only (no toolboxes needed).

p = hapParams();
pass = true;

% FSPL at the coverage edge, notes eq. 7: 129.588 dB
fsplEdge = 20*log10(4*pi*sqrt(18e3^2 + 31.17e3^2)*p.fc/p.c);
pass = report('FSPL at 31.17 km [dB]', fsplEdge, 129.588, 0.01) && pass;

% Tab. 4/5: path loss, difference and delay difference along y = 0
x   = [0 3.9 7.8 11.7 15.6]*1e3;
L1  = [123.6 123.8 124.3 125.1 126.0];
L2  = [129.6 128.8 127.9 126.9 126.0];
dT  = [60 48 33 17 0]*1e-6;
lb  = linkBudget(p, x, "DL");
for i = 1:numel(x)
    tag = sprintf('x = %4.1f km', x(i)/1e3);
    pass = report([tag ' L1 [dB]'], lb.fspl(i,1), L1(i), 0.1) && pass;
    pass = report([tag ' L2 [dB]'], lb.fspl(i,2), L2(i), 0.1) && pass;
    pass = report([tag ' dtau [us]'], lb.g.dtau(i)*1e6, dT(i)*1e6, 1) && pass;
end

% Notes p.19-20: C = 2.94 Mbit/s for 120 mW, total loss 129.63 dB, no gains
N0 = p.kB*p.T;
k  = 10^(-129.6309291513125/10);
C  = p.B*log2(1 + k*0.120/(p.B*N0));
pass = report('Shannon C [Mbit/s]', C/1e6, 2.9488, 0.01) && pass;
Preq = (2^(p.Rtarget/p.B) - 1)*p.B*N0/k;
pass = report('P_TOT for 2 Mbit/s [mW]', Preq*1e3, 67.46, 0.1) && pass;

% Antenna: -3 dB at 60 deg from nadir
pass = report('G(60 deg) - Gm [dB]', hapAntennaGain(p, 60) - p.Gm, -3, 1e-6) && pass;

if pass
    fprintf('\nAll link budget checks passed.\n');
else
    fprintf('\nSome link budget checks FAILED.\n');
end

% Operating point summary
fprintf('\nOperating SNR (strongest HAP / combined) at 2 GHz, B = %.1f MHz\n', p.B/1e6);
lbU = linkBudget(p, x, "UL");
for i = 1:numel(x)
    fprintf('  x = %4.1f km: DL %5.1f / %5.1f dB, UL %5.1f / %5.1f dB, C/I %4.1f dB\n', ...
        x(i)/1e3, lb.SNRmax(i), lb.SNRcomb(i), lbU.SNRmax(i), lbU.SNRcomb(i), lb.CI(i));
end

function ok = report(name, val, ref, tol)
ok = abs(val - ref) <= tol;
status = 'ok';
if ~ok, status = 'FAIL'; end
fprintf('%-28s %10.4f  (notes %10.4f)  %s\n', name, val, ref, status);
end
