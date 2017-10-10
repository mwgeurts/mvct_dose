function handles = RunDoseCalculation(handles)
% RunDoseCalculation is called by MVCTdose when the user clicks the
% calculate dose button. It creates the necessary inputs and then executes
% CalcDose().
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

% Start waitbar
progress = waitbar(0, 'Calculating dose');

%% Create Image Input
% Retrieve IVDT data
Event('Retrieving IVDT data');
ivdt = str2double(get(handles.ivdt_table, 'Data'));

% Remove empty values
ivdt(any(isnan(ivdt), 2),:) = [];

% Convert HU values back to CT numbers
ivdt(:,1) = ivdt(:,1) + 1024;

% Store ivdt data to image structure
handles.image.ivdt = ivdt;

% Update progress bar
waitbar(0.1, progress);

%% Create Plan Input
% Retrieve slice selector handle
api = iptgetapi(handles.selector);

% If a valid handle is not returned
if isempty(api)

    % Throw an error
    Event('No slice selector found', 'ERROR');

% Otherwise, a valid handle is returned
else

    % Retrieve current values
    pos = api.getPosition();

end

% Execute GenerateDeliveryPlan
plan = GenerateDeliveryPlan(get(handles.mlc_radio_b, 'Value'), ...
    str2double(get(handles.projection_rate, 'String')), handles.plan, ...
    handles.image, pos, str2double(get(handles.pitch, 'String')), ...
    str2double(get(handles.period, 'String')), ...
    str2double(get(handles.jaw, 'String')), handles.sinogram);

% Update progress bar
waitbar(0.2, progress);

%% Write beam model to temporary directory
% Generate temporary folder
folder = tempname;
[status, cmdout] = system(['mkdir ', folder]);
if status > 0
    Event(['Error occurred creating temporary directory: ', cmdout], ...
        'ERROR');
end

% Copy beam model files to temporary directory
Event(['Copying beam model files from ', fullfile(handles.config.MODEL_PATH, ...
    handles.beammodels{get(handles.beam_menu, 'Value')}), '/ to ', folder]);
[status, cmdout] = system(['cp ', fullfile(handles.config.MODEL_PATH, ...
    handles.beammodels{get(handles.beam_menu, 'Value')}, '*.*'), ...
    ' ', folder, '/']);

% If status is 0, cp was successful.  Otherwise, log error
if status > 0
    Event(['Error occurred copying beam model files to temporary ', ...
        'directory: ', cmdout], 'ERROR');
end

% Clear temporary variables
clear status cmdout;

% Update progress bar
waitbar(0.25, progress);

% Open read handle to beam model dcom.header
fidr = fopen(fullfile(handles.config.MODEL_PATH, handles.beammodels{get(...
    handles.beam_menu, 'Value')}, 'dcom.header'), 'r');

% Open write handle to temporary dcom.header
Event('Editing dcom.header to specify output');
fidw = fopen(fullfile(folder, 'dcom.header'), 'w');

% If either file handles are invalid, throw an error
if fidr < 3 || fidw < 3
    Event('A file handle could not be opened to dcom.header', 'ERROR');
end

% Retrieve the first line from dcom.header
tline = fgetl(fidr);

% While data exists
while ischar(tline)
    
    % If line contains beam output
    if ~isempty(regexpi(tline, 'dcom.efiot'))
        
        % Write custom beam output based on UI value
        fprintf(fidw, 'dcom.efiot = %g\n', ...
            str2double(get(handles.beamoutput, 'String')));
        
    % Otherwise, write tline back to temp file
    else
        fprintf(fidw, '%s\n', tline);
    end
    
    % Retrieve the next line
    tline = fgetl(fidr);
end

% Close file handles
fclose(fidr);
fclose(fidw);

% Update progress bar
waitbar(0.3, progress);

%% Calculate and display dose
% Calculate dose using image, plan, directory, & sadose flag
handles.dose = CalcDose(handles.image, plan, 'modelfolder', folder, ...
    'sadose', handles.config.USE_SADOSE);

% If dose was computed
if isfield(handles.dose, 'data')

    % Update progress bar
    waitbar(0.7, progress, 'Updating results');

    % Clear temporary variables
    clear ivdt plan k folder fidr fidw tline api pos totalTau;
    
    % If structures are present
    if isfield(handles, 'structures') && ~isempty(handles.structures)
        
        % Calculate DVH plot
        Event('Calculating DVH');
        if isfield(handles, 'dvh') && isvalid(handles.dvh)
            handles.dvh.Calculate('doseA', handles.dose);
        else
            handles.dvh = DVHViewer('axis', handles.dvh_axes, ...
                'structures', handles.structures, ...
                'doseA', handles.dose, 'table', handles.dvh_table, ...
                'atlas', handles.atlas, 'columns', 4);
        end
        
        % Update progress bar
        waitbar(0.8, progress);
        
        % Display dose
        Event('Plotting dose image');
        
        % Update existing plot, or create new one
        if isfield(handles, 'tcsplot') && isvalid(handles.tcsplot)
            handles.tcsplot.Initialize('overlay', handles.dose);
        else
            handles.tcsplot = ImageViewer('axis', handles.dose_axes, ...
                'tcsview', handles.tcsview, 'background', handles.image, ...
                'overlay', handles.dose, 'alpha', ...
                sscanf(get(handles.alpha, 'String'), '%f%%')/100, ...
                'structures', handles.structures, ...
                'structuresonoff', get(handles.dvh_table, 'Data'), ...
                'slider', handles.dose_slider, 'cbar', 'on', ...
                'pixelval', 'off');
        end
        
        % Enable statistics table
        set(handles.dvh_table, 'Visible', 'on');

        % Enable DVH export button
        set(handles.dvh_button, 'Enable', 'on');
    else
        % Create new plot
        Event('Plotting dose image');
        handles.tcsplot = ImageViewer('axis', handles.dose_axes, ...
            'tcsview', handles.tcsview, 'background', handles.image, ...
            'overlay', handles.dose, 'alpha', ...
            sscanf(get(handles.alpha, 'String'), '%f%%')/100, ...
            'slider', handles.dose_slider, 'cbar', 'on', 'pixelval', 'on');
    end
    
    % Enable transparency and TCS inputs
    set(handles.alpha, 'visible', 'on');
    set(handles.tcs_button, 'visible', 'on');

    % Update progress bar
    waitbar(1.0, progress, 'Dose calculation completed');

    % Enable dose export buttons
    set(handles.dose_button, 'Enable', 'on');
end

% Close progress handle
close(progress);

% Clear temporary variables
clear progress;