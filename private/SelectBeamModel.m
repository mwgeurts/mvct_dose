function handles = SelectBeamModel(handles)
% SelectBeamModel is called by MVCTdose during initialization and when a
% new beam model is selected from the dropdown list.
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

% Clear and disable beam output
set(handles.beamoutput, 'String', '');
set(handles.beamoutput, 'Enable', 'off');
set(handles.text9, 'Enable', 'off');

% Clear and disable gantry period
set(handles.period, 'String', '');
set(handles.period, 'Enable', 'off');
set(handles.text13, 'Enable', 'off');

% Clear and disable jaw settings
set(handles.jaw, 'String', '');
set(handles.jaw, 'Enable', 'off');
set(handles.jaw_menu, 'String', 'Select');
set(handles.jaw_menu, 'Value', 1);
set(handles.jaw_menu, 'Enable', 'off');
set(handles.text20, 'Enable', 'off');

% Disable pitch 
set(handles.pitch, 'Enable', 'off');
set(handles.pitch_menu, 'Enable', 'off');
set(handles.text18, 'Enable', 'off');

% Disable MLC parameters
set(handles.mlc_radio_a, 'Enable', 'off');
set(handles.mlc_radio_b, 'Enable', 'off');

% Disable custom sinogram inputs
set(handles.sino_file, 'Enable', 'off');
set(handles.sino_browse, 'Enable', 'off');
set(handles.projection_rate, 'Enable', 'off');
set(handles.text16, 'Enable', 'off');
set(handles.text17, 'Enable', 'off');

% Disable sinogram axes
set(allchild(handles.sino_axes), 'visible', 'off'); 
set(handles.sino_axes, 'visible', 'off');

% Initialize field size array
handles.fieldsizes = [];
    
% If current value is greater than 1 (beam model selected)
if get(handles.beam_menu, 'Value') > 1
    
    % Initialize penumbras array
    penumbras = [];
    
    % Open file handle to dcom.header
    fid = fopen(fullfile(handles.config.MODEL_PATH, ...
        handles.beammodels{get(handles.beam_menu, 'Value')}, 'dcom.header'), 'r');
    
    % If fopen was successful
    if fid > 2
        
        % Retrieve first line
        tline = fgetl(fid);
        
        % While data exists
        while ischar(tline)
        
            % If the line is efiot
            match = ...
                regexpi(tline, 'dcom.efiot[ =]+([0-9\.e\+-]+)', 'tokens');
            if ~isempty(match)
                
                % Set the beam output
                set(handles.beamoutput, 'String', sprintf('%0.4e', ...
                    str2double(match{1})));
                Event(sprintf('Beam output set to %0.4e MeV-cm2/sec', ...
                    str2double(match{1})));
            end
            
            % If the line is penumbra x counts
            match = regexpi(tline, ['dcom.penumbra.header.([0-9]+).', ...
                'xCount[ =]+([0-9]+)'], 'tokens');
            if ~isempty(match)
                
                % Store the x counts
                penumbras(str2double(match{1}(1))+1, 1) = ...
                    str2double(match{1}(2)); %#ok<*AGROW>
            end
            
            % If the line is penumbra z counts
            match = regexpi(tline, ['dcom.penumbra.header.([0-9]+).', ...
                'zCount[ =]+([0-9]+)'], 'tokens');
            if ~isempty(match)
                
                % Store the z counts
                penumbras(str2double(match{1}(1))+1, 2) = ...
                    str2double(match{1}(2));
            end
                
            % Retrieve next line
            tline = fgetl(fid);
        end
        
        % Close file
        fclose(fid);
     
    % Otherwise, throw an error
    else
        Event(sprintf('Error opening %s', fullfile(handles.config.MODEL_PATH, ...
            handles.beammodels{get(handles.beam_menu, 'Value')}, ...
            'dcom.header')), 'ERROR');
    end
    
    % Open a file handle to penumbra.img
    fid = fopen(fullfile(handles.config.MODEL_PATH, ...
        handles.beammodels{get(handles.beam_menu, 'Value')}, ...
        'penumbra.img'), 'r', 'l');
    
    % If fopen was successful
    if fid > 2
        
        % Loop through the penumbras
        for i = 1:size(penumbras,1)
            
            % Read in the ith penumbra filter
            arr = reshape(fread(fid, prod(penumbras(i,:) + 1), 'single'), ...
                penumbras(i,:) + 1);
            
            % Store field size
            handles.fieldsizes(i) = arr(1,1);
            
        end
        
        % Reshape field size array and multiply by 85 cm
        handles.fieldsizes = reshape(handles.fieldsizes, [], 2) * 85;
        
    % Otherwise, throw an error
    else
        Event(sprintf('Error opening %s', fullfile(handles.config.MODEL_PATH, ...
            handles.beammodels{get(handles.beam_menu, 'Value')}, ...
            'penumbra.img')), 'ERROR');
    end
    
    % Initialize menu cell array
    menu = cell(1, size(handles.fieldsizes, 1));
    
    % Loop through field sizes
    for i = 1:size(handles.fieldsizes, 1)
        
        % Store field size in [back, front] format
        menu{i} = sprintf('[%0.2g %0.2g]', handles.fieldsizes(i, :));
        
        % Log field size
        Event(sprintf('Commissioned field size [%0.2g %0.2g] loaded', ...
            handles.fieldsizes(i, :)));
    end
    
    % Set field size options
    set(handles.jaw_menu, 'String', horzcat('Select', menu));
    
    % Enable beam output
    set(handles.beamoutput, 'Enable', 'on');
    set(handles.text9, 'Enable', 'on');
    
    % Enable gantry period
    set(handles.period, 'String', sprintf('%0.1f', ...
        handles.config.DEFAULT_PERIOD));
    set(handles.period, 'Enable', 'on');
    Event(sprintf('Gantry period set to %0.1f sec', ...
        handles.config.DEFAULT_PERIOD));
    set(handles.text13, 'Enable', 'on');

    % Enable jaw settings
    set(handles.jaw_menu, 'Enable', 'on');
    set(handles.jaw, 'Enable', 'on');
    set(handles.text20, 'Enable', 'on');

    % Enable pitch settings
    set(handles.pitch_menu, 'Enable', 'on');
    set(handles.pitch, 'Enable', 'on');
    set(handles.text18, 'Enable', 'on');

    % Enable MLC parameters
    set(handles.mlc_radio_a, 'Enable', 'on');
    set(handles.mlc_radio_b, 'Enable', 'on');

    % If custom sinogram is selected
    if get(handles.mlc_radio_b, 'Value') == 1
        
        % Enable custom sinogram inputs
        set(handles.sino_file, 'Enable', 'on');
        set(handles.sino_browse, 'Enable', 'on');
        set(handles.projection_rate, 'Enable', 'on');
        set(handles.text16, 'Enable', 'on');
        set(handles.text17, 'Enable', 'on');
    end
    
    % If custom sinogram is loaded
    if isfield(handles, 'sinogram') && ~isempty(handles.sinogram)
        
        % Enable sinogram axes
        set(allchild(handles.sino_axes), 'visible', 'on'); 
        set(handles.sino_axes, 'visible', 'on');
    end
    
    % Clear temporary variables
    clear fid i tline match penumbras arr menu;
end