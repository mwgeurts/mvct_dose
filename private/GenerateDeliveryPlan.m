function plan = GenerateDeliveryPlan(custom, rate, refplan, refimage, ...
    slices, pitch, period, jaw, sinogram)
% GenerateDeliveryPlan is called by RunDoseCalculation and generates the 
% delivery plan structure for MVCT dose calculation.
% 
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2017 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURslicesE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Initialize plan structure
Event(['Generating delivery plan from slice selection and beam model', ...
    ' inputs']);
plan = struct;

% If a custom sinogram was loaded
if custom == 1

    % Set plan scale (sec/tau) to inverse of projection rate (tau/sec)
    plan.scale = 1 / rate;
    
% Otherwise, use an all open sinogram
else
    
    % Assume scale is 1 second/tau
    plan.scale = 1;
    
end

% Log scale
Event(sprintf('Plan scale set to %g sec/tau', plan.scale));

% Initialize plan.events array with sync event. Events that do not have a 
% value are given the placeholder value 1.7976931348623157E308 
plan.events{1,1} = 0;
plan.events{1,2} = 'sync';
plan.events{1,3} = 1.7976931348623157E308;

% Add a projection width event at tau = 0
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'projWidth';
plan.events{k,3} = 1;

% Add isoX and isoY
k = size(plan.events, 1) + 1;

% If plan is loaded
if isstruct(refplan) && isfield(refplan, 'isocenter')
    
    % Set isocenter X/Y from delivery plan
    plan.events{k,1} = 0;
    plan.events{k,2} = 'isoX';
    plan.events{k,3} = refplan.isocenter(1);
    plan.events{k+1,1} = 0;
    plan.events{k+1,2} = 'isoY';
    plan.events{k+1,3} = refplan.isocenter(2);

% Otherwise, if image contains isocenter tag
elseif isstruct(refimage) && isfield(refimage, 'isocenter') 
    
    % Set isocenter X/Y from image reference isocenter
    plan.events{k,1} = 0;
    plan.events{k,2} = 'isoX';
    plan.events{k,3} = refimage.isocenter(1);
    plan.events{k+1,1} = 0;
    plan.events{k+1,2} = 'isoY';
    plan.events{k+1,3} = refimage.isocenter(2);
    
% Otherwise set to 0,0 (DICOM isocenter)
else
    plan.events{k,1} = 0;
    plan.events{k,2} = 'isoX';
    plan.events{k,3} = 0;
    plan.events{k+1,1} = 0;
    plan.events{k+1,2} = 'isoY';
    plan.events{k+1,3} = 0;
end

% Add isoZ (cm) based on superior slice selection slicesition
Event(sprintf('MVCT scan start slicesition set to %g cm', max(slices(1,1), ...
    slices(2,1))));
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'isoZ';
plan.events{k,3} = min(slices(1,1), slices(2,1));

% Add isoXRate and isoYRate as 0 cm/tau
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'isoXRate';
plan.events{k,3} = 0;
plan.events{k+1,1} = 0;
plan.events{k+1,2} = 'isoYRate';
plan.events{k+1,3} = 0;

% Add isoZRate (cm/tau) as pitch (cm/rot) / GP (sec/rot) * scale (sec/tau)
Event(sprintf('Couch velocity set to %g cm/sec', pitch / period));
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'isoZRate';
plan.events{k,3} = pitch / period * plan.scale;

% Add jawBack and jawFront based on UI value, assuming beam is symmetric
% about isocenter (in cm at isocenter divided by SAD)
Event(sprintf('Jaw slicesitions set to [-%g %g]', jaw / (85 * 2), ...
    jaw / (85 * 2)));
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'jawBack';
plan.events{k,3} = -jaw / (85 * 2);
plan.events{k+1,1} = 0;
plan.events{k+1,2} = 'jawFront';
plan.events{k+1,3} = jaw / (85 * 2);

% Add jawBackRate and jawFrontRate as 0 (no jaw motion)
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'jawBackRate';
plan.events{k,3} = 0;
plan.events{k+1,1} = 0;
plan.events{k+1,2} = 'jawFrontRate';
plan.events{k+1,3} = 0;

% Add start angle as 0 deg
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'gantryAngle';
plan.events{k,3} = 0;

% Add gantry rate (deg/tau) based on 360 (deg/rot) / UI value (sec/rot) *
% scale (sec/tau)
Event(sprintf('Gantry rate set to %g deg/sec', 360 / period));
k = size(plan.events, 1) + 1;
plan.events{k,1} = 0;
plan.events{k,2} = 'gantryRate';
plan.events{k,3} = 360 / period * plan.scale;

% Determine total number of projections based on couch travel distance (cm)
% / pitch (cm/rot) * GP (sec/rot) / scale (sec/tau)
plan.totalTau = round(abs(slices(2,1) - slices(1,1)) / ...
    pitch * period / plan.scale);
Event(sprintf('End of Procedure set to %g projections', plan.totalTau));

% Add unsync and eop events at final tau value. These events do not have a 
% value, so use the placeholder
k = size(plan.events,1)+1;
plan.events{k,1} = plan.totalTau;
plan.events{k,2} = 'unsync';
plan.events{k,3} = 1.7976931348623157E308;
plan.events{k+1,1} = plan.totalTau;
plan.events{k+1,2} = 'eop';
plan.events{k+1,3} = 1.7976931348623157E308;

% Set lowerLeafIndex plan variable
Event('Lower Leaf Index set to 0');
plan.lowerLeafIndex = 0;

% Set numberOfLeaves
Event('Number of Leaves set to 64');
plan.numberOfLeaves = 64;

% Set numberOfProjections to next whole integer
Event(sprintf('Number of Projections set to %i', ceil(plan.totalTau)));
plan.numberOfProjections = ceil(plan.totalTau);

% Set startTrim and stopTrim
Event(sprintf('Start and stop trim set to 1 and %i', ceil(plan.totalTau)));
plan.startTrim = 1;
plan.stopTrim = ceil(plan.totalTau);

% If a custom sinogram was loaded
if custom == 1

    % If custom sinogram is less than what is needed
    if size(sinogram, 2) < ceil(plan.totalTau)
        
        % Warn user that additional closed projections will be used
        Event(sprintf(['Custom sinogram is shorter than need by %i ', ...
            'projections, and will be extended with all closed leaves'], ...
            ceil(plan.totalTau) - size(sinogram, 2)), 'WARN');
        
        % Initialize empty plan sinogram
        plan.sinogram = zeros(64, plan.numberOfProjections);
        
        % Fill with custom sinogram
        plan.sinogram(:, 1:size(sinogram, 2)) = sinogram;
        
    % Otherwise, if custom sinogram is larger
    elseif size(sinogram, 2) > ceil(plan.totalTau)
        
        % Warn user that not all of sinogram will be used
        Event(sprintf(['Custom sinogram is larger than need by %i ', ...
            'projections, which will be discarded for dose calculation'], ...
            size(sinogram, 2) - ceil(plan.totalTau)), 'WARN');
        
        % Fill with custom sinogram
        plan.sinogram = sinogram(:, 1:ceil(plan.totalTau));
    
    % Otherwise, it is just right
    else
        
        % Inform the user
        Event('Custom sinogram is just right!');
        
        % Fill with custom sinogram
        plan.sinogram = sinogram;
    end
    
% Otherwise, use an all open sinogram
else
    Event('Generating all open leaves sinogram');
    plan.sinogram = ones(64, plan.numberOfProjections);
end