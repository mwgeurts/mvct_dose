function handles = LoadCTImage(handles, name, path)
% LoadCTImage is called by MVCTdose when the user clicks the image browse
% button. It displayed a file selection dialog box to allow the user to
% select DICOM file or a patient archive XML, then loads the images.
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

% Update default path
handles.config.path = path;
Event(['Default file path updated to ', path]);

% If not cell array, cast as one
if ~iscell(name)

    % Update text box with file name
    set(handles.image_file, 'String', fullfile(path, name));
    names{1} = name;

else
    % Update text box with first file
    set(handles.image_file, 'String', path);
    names = name;
end

% Disable DVH table
set(handles.dvh_table, 'Visible', 'off');

% Disable dose and DVH axes
set(allchild(handles.dose_axes), 'visible', 'off'); 
set(handles.dose_axes, 'visible', 'off');
colorbar(handles.dose_axes, 'off');
set(allchild(handles.dvh_axes), 'visible', 'off'); 
set(handles.dvh_axes, 'visible', 'off');

% Hide dose slider/TCS/alpha
set(handles.dose_slider, 'visible', 'off');
set(handles.tcs_button, 'visible', 'off');
set(handles.alpha, 'visible', 'off');

% Disable export buttons
set(handles.dose_button, 'Enable', 'off');
set(handles.dvh_button, 'Enable', 'off');

% Search for an xml extension
s = regexpi(names{1}, '.xml$');

% If .xml was not found, use DICOM to load image    
if isempty(s) 

    % Load DICOM images
    handles.image = LoadDICOMImages(path, names);

    % Enable structure set browse
    set(handles.struct_file, 'Enable', 'on');        
    set(handles.struct_browse, 'Enable', 'on');

    % If current structure set FOR UID does not match image
    if isfield(handles, 'structures') && ~isempty(handles.structures) ...
            && (~isfield(handles.structures{1}, 'frameRefUID') || ...
            ~strcmp(handles.structures{1}.frameRefUID, ...
            handles.image.frameRefUID))

        % Log event
        Event(['Existing structure data cleared as it no longer ', ...
            'matches loaded image set'], 'WARN');

        % Clear structures
        handles.structures = [];

        % Clear structures file
        set(handles.struct_file, 'String', ''); 
    end
else

    % Start waitbar
    progress = waitbar(0, 'Loading patient archive');

    % Search for plans and MVCT scan lengths
    scans = FindMVCTScans(path, names{1});

    % Update progress bar
    waitbar(0.3, progress);

    % If no plans were found
    if isempty(scans)

        % Log event
        Event('No plans were found in selected patient archive', ...
            'ERROR');

    % Otherwise, if one plan was found
    elseif length(scans) == 1

        % Select only plan
        s(1) = 1;

    % Otherwise, if more than one plan was found
    elseif length(scans) > 1

        % Prompt user to select plan
        Event('Opening UI for user to select image set');
        n = cell2mat(scans);
        [s, v] = listdlg('PromptString', ...
            'Multiple plans were found. Select a plan to load:', ...
            'SelectionMode', 'single', 'ListString', {n.planName}, ...
            'ListSize', [300 100]);

        % If no plan was selected, throw an error
        if v == 0
            Event('No plan is selected', 'ERROR');
        end

        % Clear temporary variable
        clear v n;
    end

    % Load image 
    handles.image = LoadImage(path, names{1}, ...
        scans{s(1)}.planUID);

    % Update progress bar
    waitbar(0.6, progress);

    % Load plan (for isocenter position)
    handles.plan = LoadPlan(path, names{1}, scans{s(1)}.planUID);

    % Update progress bar
    waitbar(0.7, progress);

    % Load structure set
    handles.structures = LoadStructures(path, names{1}, ...
        handles.image, handles.atlas);

    % Update progress bar
    waitbar(0.9, progress);

    % Initialize slice menu
    Event(sprintf('Loading %i scans to slice selection menu', ...
        length(scans{s(1)}.scanLengths)));
    handles.slices = cell(1, length(scans{s(1)}.scanLengths)+1);
    handles.slices{1} = 'Manual slice selection';

    % Loop through scan lengths
    for i = 1:length(scans{s(1)}.scanUIDs)
        handles.slices{i+1} = sprintf('%i. [%g %g] %s-%s', i, ...
            scans{s(1)}.scanLengths(i,:) + handles.image.isocenter(3), ...
            scans{s(1)}.date{i}, scans{s(1)}.time{i});
    end

    % Update slice selection menu UI
    set(handles.slice_menu, 'String', handles.slices);
    set(handles.slice_menu, 'Value', 1);

    % Initialize ivdt temp cell array
    Event('Updating IVDT table from patient archive');
    ivdt = cell(size(handles.image.ivdt, 1) + 1, 2);

    % Loop through elements, writing formatted values
    for i = 1:size(handles.image.ivdt, 1)

        % Save formatted numbers
        ivdt{i,1} = sprintf('%0.0f', handles.image.ivdt(i,1) - 1024);
        ivdt{i,2} = sprintf('%g', handles.image.ivdt(i, 2));

    end

    % Set IVDT table
    set(handles.ivdt_table, 'Data', ivdt);

    % Clear temporary variables
    clear scans s i ivdt;

    % Update waitbar
    waitbar(1.0, progress, 'Patient archive loading completed');

    % Clear and disable structure set browse
    set(handles.struct_file, 'String', '');
    set(handles.struct_file, 'Enable', 'off');        
    set(handles.struct_browse, 'Enable', 'off');

    % Close waitbar
    close(progress);

    % Clear temporary variables
    clear progress;
end

% Delete slice selector if one exists
if isfield(handles, 'selector')

    % Log deletion
    Event('Deleting old slice selector');

    % Retrieve current handle
    api = iptgetapi(handles.selector);

    % If a valid handle is returned, delete it
    if ~isempty(api); api.delete(); end

    % Clear temporary variable
    clear api;
end

% Set slice to center of dataset
slice = floor(handles.image.dimensions(1)/2);

% Extract sagittal slice through center of image
imageA = squeeze(handles.image.data(slice, :, :));

% Set image widths
width = [handles.image.width(3) handles.image.width(2)];

% Set image start values
start = [handles.image.start(3) handles.image.start(2)];

% Plot sagittal plane in slice selector
axes(handles.slice_axes);

% Create reference object based on the start and width inputs
reference = imref2d(size(imageA), [start(1) start(1) + size(imageA,2) * ...
    width(1)], [start(2) start(2) + size(imageA,1) * width(2)]);

% Display the reference image
imshow(ind2rgb(gray2ind((imageA) / 2048, 64), colormap('gray')), ...
        reference);

% Add image contours
if isfield(handles, 'structures') && ~isempty(handles.structures)

    % Hold the axes to allow overlapping contours
    hold on;

    % Loop through each structure
    for i = 1:length(handles.structures)

        % Loop through each atlas structure
        for j = 1:size(handles.atlas, 2)
            
            % Compute the number of include atlas REGEXP matches
            in = regexpi(handles.structures{i}.name, ...
                handles.atlas{j}.include);
            
            % If the atlas structure also contains an exclude REGEXP
            if isfield(handles.atlas{j}, 'exclude') 
                
                % Compute the number of exclude atlas REGEXP matches
                ex = regexpi(handles.structures{i}.name, ...
                    handles.atlas{j}.exclude);
            else
                % Otherwise, return 0 exclusion matches
                ex = [];
            end
            
            % If the structure matched the include REGEXP and not the
            % exclude REGEXP (if it exists)
            if size(in, 1) > 0 && size(ex, 1) == 0
                
                % Use bwboundaries to generate X/Y contour points based
                % on structure mask
                B = bwboundaries(squeeze(...
                    handles.structures{i}.mask(slice, :, :))');

                % Loop through each contour set (typically this is one)
                for k = 1:length(B)

                    % Plot the contour points given the structure color
                    plot((B{k}(:,1) - 1) * width(1) + start(1), ...
                        (B{k}(:,2) - 1) * width(2) + start(2), ...
                       'Color', handles.structures{i}.color/255, ...
                       'LineWidth', 2);
                end

                % Stop the atlas for loop, as the structure was matched
                break;
            end
        end
        
        % Clear temporary variables
        clear in ex;
    end

    % Unhold axes generation
    hold off;
end

% Show the slice selection plot
set(handles.slice_axes, 'visible', 'on');

% Hide the x/y axis on the images
axis off;

% Disallow zoom on slice selector
h = zoom;
setAllowAxesZoom(h, handles.slice_axes, false);

% Create interactive slice selector line to allow user to select slice 
% ranges, defaulting to all slices
handles.selector = imdistline(handles.slice_axes, ...
    [start(1) start(1) + size(imageA, 2) * width(1)], ...
    [0 0]);

% Retrieve handle to slice selector API
api = iptgetapi(handles.selector);

% Constrain line to only resize horizontally, and only to the upper and
% lower extent of the image using drag constraint function
fcn = @(pos) [max(start(1), min(pos(:,1))) 0; ...
        min(start(1) + size(imageA, 2) * width(1), max(pos(:,1))) 0];
api.setDragConstraintFcn(fcn);

% Hide distance label
api.setLabelVisible(0);

% Clear temporary variable
clear h s i j k name names path sag width start reference slice B ...
    imageA fcn api;