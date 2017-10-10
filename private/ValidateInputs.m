function handles = ValidateInputs(handles)
% ValidateInputs checks to see if all dose calculation inputs have
% been set, and if so, enables the "Calculate Dose" button
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
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Initialize validated flag and reason string
handles.validated = true;
reason = '';

%% Verify data variables are set
% Verify CT data exists
if ~isfield(handles, 'image') || ~isfield(handles.image, 'data') || ...
        length(size(handles.image.data)) ~= 3
    
    reason = 'image data does not exist';
    handles.validated = false;
    
% Verify slice selector exists
elseif ~isfield(handles, 'selector')
    
    reason = 'no slice selector found';
    handles.validated = false;
    
% Verify IVDT table data exists
elseif size(get(handles.ivdt_table, 'Data'), 1) < 2
    
    reason = 'no IVDT data exists';
    handles.validated = false;
    
% Verify beam output exists and is greater than 0
elseif isnan(str2double(get(handles.beamoutput, 'String'))) || ...
        str2double(get(handles.beamoutput, 'String')) <= 0
    
    reason = 'beam output is not valid';
    handles.validated = false;

% Verify gantry period exists and is greater than 0
elseif isnan(str2double(get(handles.period, 'String'))) || ...
        str2double(get(handles.period, 'String')) <= 0
    
    reason = 'gantry period is not valid';
    handles.validated = false;

% Verify field width exists and is greater than 0
elseif isnan(str2double(get(handles.jaw, 'String'))) || ...
        str2double(get(handles.jaw, 'String')) <= 0
    
    reason = 'field width is not valid';
    handles.validated = false;
    
% Verify pitch exists and is greater than 0
elseif isnan(str2double(get(handles.pitch, 'String'))) || ...
        str2double(get(handles.pitch, 'String')) <= 0
    
    reason = 'pitch is not valid';
    handles.validated = false;
end

%% Verify IVDT values
% Convert IVDT values to numbers
ivdt = str2double(get(handles.ivdt_table, 'Data'));

% Verify first HU value is -1024
if ivdt(1,1) ~= -1024
    
    reason = 'the first IVDT entry must define density at -1024';
    handles.validated = false;
   
% Verify the HU values are sorted
elseif ~issorted(ivdt(:, 1))
    
    reason = 'the IVDT HU values must be in ascending order';
    handles.validated = false;

% Verify the density values are sorted
elseif ~issorted(ivdt(:, 2))
    
    reason = 'the IVDT density values must be in ascending order';
    handles.validated = false;
    
% Verify at least two HU values exist
elseif length(ivdt(:, 1)) - sum(isnan(ivdt(:, 1))) <= 2
    
    reason = 'the IVDT must contain at least two values';
    handles.validated = false;
    
% Verify the number of non-zero HU and density values are equal
elseif length(ivdt(:, 1)) - sum(isnan(ivdt(:, 1))) ~= ...
        length(ivdt(:, 2)) - sum(isnan(ivdt(:, 2)))
    
    reason = 'the number of IVDT HU and density values must be equal';
    handles.validated = false;
end

%% Verify slice selection values
if ~handles.validated && isfield(handles, 'selector') 
    
    % Retrieve current handle
    api = iptgetapi(handles.selector);

    % If a valid handle is not returned
    if isempty(api) || ~isvalid(api)
        
        % handles.validated calculation
        reason = 'no slice selector found';
        handles.validated = false; 

    % Otherwise, a valid handle is returned
    else
        
        % Retrieve current values
        pos = api.getPosition();
        
        % If current values are not within slice boundaries
        if pos(1,1) < handles.image.start(3) || pos(2,1) > ...
                handles.image.start(3) + size(handles.image.data, 3) * ...
                handles.image.width(3)
            
            % handles.validated calculation
            reason = 'slice selector is not within image boundaries';
            handles.validated = false;
            
        end
    end
end

%% Verify custom MLC values
% If a custom sinogram is selected
if get(handles.mlc_radio_b, 'Value') == 1
    
    % Verify sinogram data exists
    if ~isfield(handles, 'sinogram') || size(handles.sinogram, 1) == 0
        
        reason = 'custom sinogram is not loaded';
        handles.validated = false;
    
    % Verify a projection rate exists and is greater than 0
    elseif isnan(str2double(get(handles.projection_rate, 'String'))) || ...
            str2double(get(handles.projection_rate, 'String')) <= 0
        
        reason = 'projection rate is not valid';
        handles.validated = false;
    
    end
end

%% Finish verification
% If calcDose is set to 0, the calc server does not exist
if handles.calcDose == 0
    
    reason = 'dose calculator is not connected';
    handles.validated = false;
end

% If validated flag is still set
if handles.validated
    
    % If previous state was handles.validatedd
    if strcmp(get(handles.calc_button, 'Enable'), 'off')
        
        % Log reason for changing status
        Event('Dose calculation inputs passed validation checks');
    end
    
    % Enable calc button
    set(handles.calc_status, 'Enable', 'on');
    set(handles.calc_button, 'Enable', 'on');
else
    % If previous state was enabled
    if strcmp(get(handles.calc_button, 'Enable'), 'on')
        
        % Log reason for changing status
        Event(['Dose calculation is disabled: ', reason], 'WARN');
    end
    
    % Disable calc button
    set(handles.calc_status, 'Enable', 'off');
    set(handles.calc_button, 'Enable', 'off');
end

% Clear temporary variables
clear reason pos ivdt;