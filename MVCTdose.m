function varargout = MVCTdose(varargin)
% The TomoTherapy MVCT Dose Calculator is a GUI based standalone 
% application written in MATLAB that parses TomoTherapy patient archives 
% and DICOM CT/RTSS files and calculates the dose to the CT given a set of
% MVCT delivery parameters.  The results are displayed and available for
% export.
%
% TomoTherapy is a registered trademark of Accuray Incorporated. See the
% README for more information, including installation information and
% algorithm details.
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

% Last Modified by GUIDE v2.5 09-Oct-2017 16:38:02

% Begin initialization code - DO NOT EDIT
gui_Singleton = 0;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MVCTdose_OpeningFcn, ...
                   'gui_OutputFcn',  @MVCTdose_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function MVCTdose_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MVCTdose (see VARARGIN)

% Turn off MATLAB warnings
warning('off', 'all');

% Choose default command line output for MVCTdose
handles.output = hObject;

% Set version handle
handles.version = '1.0.2';

% Determine path of current application
[path, ~, ~] = fileparts(mfilename('fullpath'));

% Set current directory to location of this application
cd(path);

% Clear temporary variable
clear path;

% Get version information.  See LoadVersionInfo for more details.
handles.versionInfo = LoadVersionInfo();

% Store program and MATLAB/etc version information as a string cell array
string = {'TomoTherapy MVCT Dose Calculator'
    sprintf('Version: %s (%s)', handles.version, handles.versionInfo{6});
    sprintf('Author: Mark Geurts <mark.w.geurts@gmail.com>');
    sprintf('MATLAB Version: %s', handles.versionInfo{2});
    sprintf('MATLAB License Number: %s', handles.versionInfo{3});
    sprintf('Operating System: %s', handles.versionInfo{1});
    sprintf('CUDA: %s', handles.versionInfo{4});
    sprintf('Java Version: %s', handles.versionInfo{5})
};

% Add dashed line separators      
separator = repmat('-', 1,  size(char(string), 2));
string = sprintf('%s\n', separator, string{:}, separator);

% Log information
Event(string, 'INIT');

% Add submodules
AddSubModulePaths();

% Load config file
handles.config = ParseConfigOptions('config.txt');

% Set version UI text
set(handles.version_text, 'String', sprintf('Version %s', handles.version));

% Load beam models
handles.beammodels = LoadBeamModels(handles.config.MODEL_PATH);

% Set beam model menu
set(handles.beam_menu, 'String', handles.beammodels);

% If only one beam model exists, set and auto-populate results
if length(handles.beammodels) == 2
    set(handles.beam_menu, 'Value', 2);
else
    set(handles.beam_menu, 'Value', 1);
end

% Load the default IVDT
handles.ivdt_table = LoadIVDTFile(handles.config.IVDT_FILE, ...
    handles.ivdt_table);

% Execute ClearAllData
handles = ClearAllData(handles);

% Set pitch menu options
set(handles.pitch_menu, 'String', horzcat('Select', ...
    handles.config.PITCH_OPTIONS));

% Default MLC sinogram to all open
set(handles.mlc_radio_a, 'Value', 1);
    
% Set beam parameters
handles = SelectBeamModel(handles);

% Set the initial image view orientation based off the config file
handles.tcsview = handles.config.DEFAULT_IMAGE_VIEW;

% Set the default transparency based off the config file
set(handles.alpha, 'String', handles.config.DEFAULT_TRANSPARENCY);

% Attempt to load the atlas
handles.atlas = LoadAtlas('structure_atlas/atlas.xml');

% Schedule timer to periodically check on calculation status
Event('Scheduling timer to periodically test server connection');
start(timer('TimerFcn', {@CheckConnection, hObject}, ...
    'BusyMode', 'drop', 'ExecutionMode', 'fixedSpacing', ...
    'TasksToExecute', Inf, 'Period', 60, 'StartDelay', 1));

% Report initilization status
Event(['Initialization completed successfully. Start by selecting a ', ...
    'patient archive or DICOM CT image set.']);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function varargout = MVCTdose_OutputFcn(~, ~, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function image_file_Callback(~, ~, ~)
% hObject    handle to image_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function image_file_CreateFcn(hObject, ~, ~)
% hObject    handle to image_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function image_browse_Callback(hObject, ~, handles)
% hObject    handle to image_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Image browse button selected');

% Request the user to select the image DICOM or XML
Event('UI window opened to select file');
[name, path] = uigetfile({'*.dcm', 'CT Image Files (*.dcm)'; ...
    '*_patient.xml', 'Patient Archive (*.xml)'}, ...
    'Select the Image Files', handles.config.path, 'MultiSelect', 'on');

% If a file was selected
if iscell(name) || sum(name ~= 0)

    % Execute LoadCTImage
    handles = LoadCTImage(handles, name, path);

    % Log completion of slice selection load
    Event(['Slice selector initialized. Drag the endpoints of the slice', ...
        ' selector to adjust the MVCT scan length.']);
    
    % Verify new data
    handles = ValidateInputs(handles);
    
% Otherwise no file was selected
else
    Event('No files were selected');
end

% Clear temporary variables
clear name path;

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function struct_file_Callback(~, ~, ~)
% hObject    handle to struct_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function struct_file_CreateFcn(hObject, ~, ~)
% hObject    handle to struct_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function struct_browse_Callback(hObject, ~, handles)
% hObject    handle to struct_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Structure browse button selected');

% Request the user to select the structure set DICOM
Event('UI window opened to select file');
[name, path] = uigetfile({'*.dcm', 'RTSS Files (*.dcm)'}, ...
    'Select the Structure Set', handles.config.path, 'MultiSelect', 'off');

% If the user selected a file, and appropriate inputs are present
if ~isequal(name, 0) && isfield(handles, 'image') && ...
        isfield(handles, 'atlas')
    
    % Execute LoadRTSS
    handles = LoadRTSS(handles, name, path);

    % Verify new data
    handles = ValidateInputs(handles);

% Otherwise no file was selected
else
    Event('No file was selected, or supporting data is not present');
end

% Clear temporary variables
clear name path;
    
% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice_menu_Callback(hObject, ~, handles) %#ok<*DEFNU>
% hObject    handle to slice_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If user selected a procedure
if get(hObject, 'Value') > 1
    
    % Retrieve positions from slice menu
    val = cell2mat(textscan(...
        handles.slices{get(hObject, 'Value')}, '%f [%f %f] %f-%f'));
    
    % Log event
    Event(sprintf('Updating slice selector to [%g %g]', val(2:3)));
    
    % Retrieve handle to slice selector API
    api = iptgetapi(handles.selector);
    
    % Get current handle position
    pos = api.getPosition();

    % Update start and end values
    pos(1,1) = val(2);
    pos(2,1) = val(3);
    
    % Update slice selector
    api.setPosition(pos);
    
    % Clear temporary variables
    clear val pos api;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slice_menu_CreateFcn(hObject, ~, ~)
% hObject    handle to slice_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Popupmenu controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function beam_menu_Callback(hObject, ~, handles)
% hObject    handle to beam_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Call SelectBeamModel
handles = SelectBeamModel(handles);

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function beam_menu_CreateFcn(hObject, ~, ~)
% hObject    handle to beam_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Popupmenu controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function beamoutput_Callback(hObject, ~, handles)
% hObject    handle to beamoutput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Parse value to number
set(hObject, 'String', sprintf('%g', str2double(get(hObject, 'String'))));

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function beamoutput_CreateFcn(hObject, ~, ~)
% hObject    handle to beamoutput (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jaw_text_Callback(hObject, ~, handles)
% hObject    handle to jaw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jaw_text_CreateFcn(hObject, ~, ~)
% hObject    handle to jaw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function period_Callback(hObject, ~, handles)
% hObject    handle to period (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Parse value to number
set(hObject, 'String', sprintf('%g', str2double(get(hObject, 'String'))));

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function period_CreateFcn(hObject, ~, ~)
% hObject    handle to period (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function pitch_Callback(hObject, ~, handles)
% hObject    handle to pitch (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Parse value to number
set(hObject, 'String', sprintf('%g', str2double(get(hObject, 'String'))));

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function pitch_CreateFcn(hObject, ~, ~)
% hObject    handle to pitch (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function pitch_menu_Callback(hObject, ~, handles)
% hObject    handle to pitch_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If a valid pitch has been selected
if get(hObject, 'Value') > 1
    
    % Log event
    Event(sprintf('Pitch changed to %s (%0.1f cm/rot)', ...
        handles.config.PITCH_OPTIONS{get(hObject, 'Value') - 1}, ...
        handles.config.PITCH_VALUES(get(hObject, 'Value') - 1)));

    % Set pitch value
    set(handles.pitch, 'String', sprintf('%0.1f', ...
        handles.config.PITCH_VALUES(get(hObject, 'Value') - 1)));
end

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function pitch_menu_CreateFcn(hObject, ~, ~)
% hObject    handle to pitch_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Popupmenu controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mlc_radio_a_Callback(hObject, ~, handles)
% hObject    handle to mlc_radio_a (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('MLC sinogram set to all open');

% Disable custom option
set(handles.mlc_radio_b, 'Value', 0);

% Disable custom sinogram inputs
set(handles.sino_file, 'Enable', 'off');
set(handles.sino_browse, 'Enable', 'off');
set(handles.projection_rate, 'Enable', 'off');
set(handles.text16, 'Enable', 'off');
set(handles.text17, 'Enable', 'off');

% Disable sinogram axes
set(allchild(handles.sino_axes), 'visible', 'off'); 
set(handles.sino_axes, 'visible', 'off');

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mlc_radio_b_Callback(hObject, ~, handles)
% hObject    handle to mlc_radio_b (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('MLC sinogram set to custom');

% Disable allopen option
set(handles.mlc_radio_a, 'Value', 0);

% Enable custom sinogram inputs
set(handles.sino_file, 'Enable', 'on');
set(handles.sino_browse, 'Enable', 'on');
set(handles.projection_rate, 'Enable', 'on');
set(handles.text16, 'Enable', 'on');
set(handles.text17, 'Enable', 'on');
    
% If custom sinogram is loaded
if isfield(handles, 'sinogram') && ~isempty(handles.sinogram)

    % Enable sinogram axes
    set(allchild(handles.sino_axes), 'visible', 'on'); 
    set(handles.sino_axes, 'visible', 'on');
end
    
% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function sino_file_Callback(~, ~, ~)
% hObject    handle to sino_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function sino_file_CreateFcn(hObject, ~, ~)
% hObject    handle to sino_file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function sino_browse_Callback(hObject, ~, handles)
% hObject    handle to sino_browse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Sinogram browse button selected');

% Request the user to select the sinogram file
Event('UI window opened to select file');
[name, path] = uigetfile('*.*', 'Select a sinogram binary file', ...
    handles.config.path);

% If the user selected a file
if ~isequal(name, 0)
    
    % Clear existing sinogram data
    handles.sinogram = [];
    
    % Update default path
    handles.config.path = path;
    Event(['Default file path updated to ', path]);
    
    % Update sino_file text box
    set(handles.sino_file, 'String', fullfile(path, name));
    
    % Extract file contents
    handles.sinogram = LoadSinogram(path, name); 
    
    % Log plot
    Event('Plotting sinogram');
    
    % Plot sinogram
    axes(handles.sino_axes);
    imagesc(handles.sinogram');
    colormap(handles.sino_axes, 'default');
    colorbar;
    
    % Enable sinogram axes
    set(allchild(handles.sino_axes), 'visible', 'on'); 
    set(handles.sino_axes, 'visible', 'on');

    % Verify new data
    handles = ValidateInputs(handles);
else
    % Log event
    Event('No file was selected');
end

% Clear temporary variables
clear name path ax;

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function projection_rate_Callback(hObject, ~, handles)
% hObject    handle to projection_rate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Parse value to number
set(hObject, 'String', sprintf('%g', str2double(get(hObject, 'String'))));

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function projection_rate_CreateFcn(hObject, ~, ~)
% hObject    handle to projection_rate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_slider_Callback(hObject, ~, handles)
% hObject    handle to dose_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Update viewer with current slice
handles.tcsplot.Update('slice', round(get(hObject, 'Value')));

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_slider_CreateFcn(hObject, ~, ~)
% hObject    handle to dose_slider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function alpha_Callback(hObject, ~, handles)
% hObject    handle to alpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If the string contains a '%', parse the value
if ~isempty(strfind(get(hObject, 'String'), '%'))
    value = sscanf(get(hObject, 'String'), '%f%%');
    
% Otherwise, attempt to parse the response as a number
else
    value = str2double(get(hObject, 'String'));
end

% Bound value to [0 100]
value = max(0, min(100, value));

% Update viewer with transparency value
handles.tcsplot.Update('alpha', value/100);

% Clear temporary variable
clear value;

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function alpha_CreateFcn(hObject, ~, ~)
% hObject    handle to alpha (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tcs_button_Callback(hObject, ~, handles)
% hObject    handle to tcs_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Based on current tcsview handle value
switch handles.tcsview
    
    % If current view is transverse
    case 'T'
        handles.tcsview = 'C';
        Event('Updating viewer to Coronal');
        
    % If current view is coronal
    case 'C'
        handles.tcsview = 'S';
        Event('Updating viewer to Sagittal');
        
    % If current view is sagittal
    case 'S'
        handles.tcsview = 'T';
        Event('Updating viewer to Transverse');
end

% Re-initialize image viewer with new T/C/S value
handles.tcsplot.Initialize('tcsview', handles.tcsview);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dvh_button_Callback(~, ~, handles)
% hObject    handle to dvh_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('DVH export button selected');

% Prompt user to select save location
Event('UI window opened to select save file location');
[name, path] = uiputfile('*.csv', 'Save DVH As');

% If the user provided a file location
if ~isequal(name, 0) && isfield(handles, 'dvh') && ~isempty(handles.dvh)
    
    % Execute WriteFile
    handles.dvh.WriteFile(fullfile(path, name), 1);
    
% Otherwise no file was selected
else
    Event('No file was selected, or supporting data is not present');
end

% Clear temporary variables
clear name path;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dose_button_Callback(~, ~, handles)
% hObject    handle to dose_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Dose export button selected');

% Prompt user to select save location
Event('UI window opened to select save file location');
[name, path] = uiputfile('*.dcm', 'Save Dose As');

% If the user provided a file location
if ~isequal(name, 0) && isfield(handles, 'image') && ...
        isfield(handles, 'structures') && isfield(handles, 'dose')
    
    % Store structures to image variable
    handles.image.structures = handles.structures;
    
    % Set series description 
    handles.image.seriesDescription = 'TomoTherapy MVCT Calculated Dose';
    
    % Execute WriteDICOMDose
    WriteDICOMDose(handles.dose, fullfile(path, name), handles.image);
    
% Otherwise no file was selected
else
    Event('No file was selected, or supporting data is not present');
end

% Clear temporary variables
clear name path;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jaw_menu_Callback(hObject, ~, handles)
% hObject    handle to jaw_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If a valid pitch has been selected
if get(hObject, 'Value') > 1
    
    % Log event
    Event(sprintf('Field size changed to [%0.2g %0.2g] (%0.2g cm)', ...
        handles.fieldsizes(get(hObject, 'Value') - 1, :), ...
        sum(abs(handles.fieldsizes(get(hObject, 'Value') - 1, :)))));

    % Set field size value
    set(handles.jaw, 'String', sprintf('%0.2g', ...
        sum(abs(handles.fieldsizes(get(hObject, 'Value') - 1, :)))));
    
    % Verify new data
    handles = ValidateInputs(handles);
end

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jaw_menu_CreateFcn(hObject, ~, ~)
% hObject    handle to jaw_menu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Popupmenu controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jaw_Callback(hObject, ~, handles)
% hObject    handle to jaw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Parse value to number
set(hObject, 'String', sprintf('%g', str2double(get(hObject, 'String'))));

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function jaw_CreateFcn(hObject, ~, ~)
% hObject    handle to jaw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Edit controls usually have a white background on Windows.
if ispc && isequal(get(hObject,'BackgroundColor'), ...
        get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function calc_button_Callback(hObject, ~, handles)
% hObject    handle to calc_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Execute RunDoseCalculation()
handles = RunDoseCalculation(handles);

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dvh_table_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to dvh_table (see GCBO)
% eventdata  structure with the following fields 
%       (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty 
%       if Data was not changed
%	Error: error string when failed to convert EditData to appropriate 
%       value for Data
% handles    structure with handles and user data (see GUIDATA)

% Get current data
data = get(hObject, 'Data');

% Verify edited Dx value is a number or empty
if eventdata.Indices(2) == 3 && isnan(str2double(...
        data{eventdata.Indices(1), eventdata.Indices(2)})) && ...
        ~isempty(data{eventdata.Indices(1), eventdata.Indices(2)})
    
    % Warn user
    Event(sprintf('Dx value "%s" is not a number', ...
        data{eventdata.Indices(1), eventdata.Indices(2)}), 'WARN');
    
    % Revert value to previous
    data{eventdata.Indices(1), eventdata.Indices(2)} = ...
        eventdata.PreviousData;
    set(hObject, 'Data', data);

% Otherwise, if Dx was changed
elseif eventdata.Indices(2) == 3
    
    % Update edited Dx/Vx statistic
    handles.dvh.UpdateTable('data', data, 'row', eventdata.Indices(1));

% Otherwise, if display value was changed
elseif eventdata.Indices(2) == 2
    
    % Update dose plot if it is displayed
    if strcmp(get(handles.dose_slider, 'visible'), 'on')

        % Update display
        handles.tcsplot.Update('structuresonoff', data);
    end
    
    % Update edited Dx/Vx statistic
    handles.dvh.UpdatePlot('data', data);
end

% Clear temporary variable
clear data;

% Update handles structure
guidata(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ivdt_table_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to ivdt_table (see GCBO)
% eventdata  structure with the following fields (see 
%       MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty 
%       if Data was not changed
%	Error: error string when failed to convert EditData to appropriate 
%       value for Data
% handles    structure with handles and user data (see GUIDATA)

% Retrieve current data array
ivdt = get(hObject, 'Data');

% Verify edited value is a number or empty
if isnan(str2double(ivdt{eventdata.Indices(1), eventdata.Indices(2)})) && ...
        ~isempty(ivdt{eventdata.Indices(1), eventdata.Indices(2)})
    
    % Warn user
    Event(sprintf(['IVDT value "%s" is not a number, reverting to previous ', ...
        'value'], ivdt{eventdata.Indices(1), eventdata.Indices(2)}), 'WARN');
    
    % Revert value to previous
    ivdt{eventdata.Indices(1), eventdata.Indices(2)} = ...
        eventdata.PreviousData;

% If an HU value was edited, round to nearest integer
elseif eventdata.Indices(2) == 1 && round(str2double(ivdt{eventdata.Indices(1), ...
        eventdata.Indices(2)})) ~= str2double(ivdt{eventdata.Indices(1), ...
        eventdata.Indices(2)}) && ...
        ~isempty(ivdt{eventdata.Indices(1), eventdata.Indices(2)})
    
    % Log round to nearest integer
    Event(sprintf('HU value %s rounded to an integer', ...
        ivdt{eventdata.Indices(1), eventdata.Indices(2)}), 'WARN');
    
    % Store rounded value
    ivdt{eventdata.Indices(1), eventdata.Indices(2)} = sprintf('%0.0f', ...
        str2double(ivdt{eventdata.Indices(1), eventdata.Indices(2)}));

% If a density value was edited, convert to number
elseif eventdata.Indices(2) == 1 && ...
        ~isempty(ivdt{eventdata.Indices(1), eventdata.Indices(2)})
    
    % Store number
    ivdt{eventdata.Indices(1), eventdata.Indices(2)} = sprintf('%g', ...
        str2double(ivdt{eventdata.Indices(1), eventdata.Indices(2)}));
    
end

% If HU values were changed and results are not sorted
if eventdata.Indices(2) == 1 && ~issorted(str2double(ivdt), 'rows')
    
    % Log event
    Event('Resorting IVDT array');
    
    % Retrieve sort indices
    [~,I] = sort(str2double(ivdt), 1, 'ascend');
    
    % Store sorted ivdt array
    ivdt = ivdt(I(:,1),:);
    
end

% If the edited cell was the last row, add a new empty row
if size(ivdt,1) == eventdata.Indices(1)
    ivdt{size(ivdt,1)+1, 1} = [];
end

% Set formatted/sorted IVDT data
set(hObject, 'Data', ivdt);

% Verify new data
handles = ValidateInputs(handles);

% Update handles structure
guidata(hObject, handles);

% Clear temporary variables
clear ivdt I;
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function clear_results_Callback(hObject, ~, handles)
% hObject    handle to clear_results (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Execute ClearAllData
handles = ClearAllData(handles);
    
% Update handles structure
guidata(hObject, handles);
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function figure1_SizeChangedFcn(hObject, ~, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set units to pixels
set(hObject, 'Units', 'pixels');

% Get table width
pos = get(handles.ivdt_table, 'Position') .* ...
    get(handles.uipanel8, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.ivdt_table, 'ColumnWidth', ...
    {floor(0.5*pos(3)) - 11 floor(0.5*pos(3)) - 11});

% Get table width
pos = get(handles.dvh_table, 'Position') .* ...
    get(handles.uipanel5, 'Position') .* ...
    get(hObject, 'Position');

% Update column widths to scale to new table size
set(handles.dvh_table, 'ColumnWidth', ...
    {floor(0.60*pos(3)) - 39 20 floor(0.2*pos(3)) ...
    floor(0.2*pos(3))});

% Clear temporary variables
clear pos;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function figure1_CloseRequestFcn(hObject, ~, ~)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Log event
Event('Closing the MVCT Dose Calculator application');

% Retrieve list of current timers
timers = timerfind;

% If any are active
if ~isempty(timers)
    
    % Stop and delete any timers
    stop(timers);
    delete(timers);
end

% Clear temporary variables
clear timers;

% Delete(hObject) closes the figure
delete(hObject);