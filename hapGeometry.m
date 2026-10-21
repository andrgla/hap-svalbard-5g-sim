function g = hapGeometry(p, xBear, yBear)
%HAPGEOMETRY Geometry between a bear on the ground and the two HAPs.
%   g = hapGeometry(p, xBear) uses yBear = 0 (line between the HAPs).
%   Rows correspond to bear positions and columns to HAP A and HAP B.

if nargin < 3
    yBear = zeros(size(xBear));
end
xBear = xBear(:);
yBear = yBear(:);

g.d    = [hypot(xBear - p.xHAP(1), yBear - p.yHAP(1)), ...
          hypot(xBear - p.xHAP(2), yBear - p.yHAP(2))];  % ground distance [m]
g.r    = sqrt(g.d.^2 + p.h^2);                           % slant range [m]
g.psi  = atand(g.d / p.h);                               % angle from nadir [deg]
g.elev = 90 - g.psi;                                     % elevation at bear [deg]
g.tau  = g.r / p.c;                                      % propagation delay [s]
g.dtau = abs(g.tau(:,1) - g.tau(:,2));                   % delay difference [s]
end
