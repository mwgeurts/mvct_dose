function handles = ClearAllData(handles)
% ClearAllData is called by MVCTdose during application initialization
% and if the user presses "Clear All" to reset the UI and initialize all
% runtime data storage variables. Note that all checkboxes will get updated
% to their configuration default settings.
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

% Log action
if isfield(handles, 'image')
    Event('Clearing all data variables from memory');
else
    Event('Initializing data variables');
end

% Clear image data
set(handles.image_file, 'String', '');  
handles.image = [];

% Cleat plan data
handles.plan = [];
handles.sinogram = [];

% Clear and delete slice selector
if isfield(handles, 'selector') 
    
    % Retrieve current handle
    api = iptgetapi(handles.selector);

    % If a valid handle is returned, delete it
    if ~isempty(api); api.delete(); end

    % Clear temporary variable
    clear api;
end

% Clear slice selection list variable and update menu
handles.slices = {'Manual slice selection'};
set(handles.slice_menu, 'String', handles.slices);

% Clear and disable structure set browse
set(handles.struct_file, 'String', '');  
set(handles.struct_file, 'Enable', 'off');        
set(handles.struct_browse, 'Enable', 'off');
handles.structures = [];

% Clear stats table
set(handles.dvh_table, 'Data', cell(20, 4));

% Disable slice selection axes
set(allchild(handles.slice_axes), 'visible', 'off'); 
set(handles.slice_axes, 'visible', 'off');

% Disable calc button and status
set(handles.calc_status, 'Enable', 'off');
set(handles.calc_button, 'Enable', 'off');

% Hide plots
if isfield(handles, 'tcsplot')
    delete(handles.tcsplot);
else
    set(allchild(handles.dose_axes), 'visible', 'off'); 
    set(handles.dose_axes, 'visible', 'off');
    set(handles.dose_slider, 'visible', 'off');
    colorbar(handles.dose_axes,'off');
end
if isfield(handles, 'dvh')
    delete(handles.dvh);
else
    set(handles.dvh_table, 'Data', cell(16,6));
    set(allchild(handles.dvh_axes), 'visible', 'off'); 
    set(handles.dvh_axes, 'visible', 'off');
end

% Hide TCS/alpha
set(handles.tcs_button, 'visible', 'off');
set(handles.alpha, 'visible', 'off');

% Disable export buttons
set(handles.dose_button, 'Enable', 'off');
set(handles.dvh_button, 'Enable', 'off');

% Set validated flag
handles.validated = false;