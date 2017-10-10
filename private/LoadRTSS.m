function handles = LoadRTSS(handles, name, path)
% LoadCTImage is called by MVCTdose when the user clicks the image browse
% button. It displayed a file selection dialog box to allow the user to
% select DICOM RT Structure Set then loads the contours to the slice 
% selection window.
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

% Update text box with file name
set(handles.struct_file, 'String', fullfile(path, name));

% Update default path
handles.config.path = path;
Event(['Default file path updated to ', path]);

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

% Load DICOM structure set
handles.structures = LoadDICOMStructures(path, name, handles.image, ...
    handles.atlas);

% Add image contours, if image data already exists
if isfield(handles, 'image') && isfield(handles.image, 'data') && ...
        size(handles.image.data, 3) > 0

    % Retrieve current handle
    api = iptgetapi(handles.selector);

    % Retrieve current values
    pos = api.getPosition();

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
    reference = imref2d(size(imageA), [start(1) start(1) + ...
        size(imageA,2) * width(1)], [start(2) start(2) + ...
        size(imageA,1) * width(2)]);

    % Display the reference image
    imshow(ind2rgb(gray2ind((imageA) / 2048, 64), colormap('gray')), ...
            reference);

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

    % Hide the x/y axis on the images
    axis off;

    % Disallow zoom on slice selector
    h = zoom;
    setAllowAxesZoom(h, handles.slice_axes, false);

    % Create interactive slice selector line to allow user to select  
    % slice ranges, defaulting to all slices
    handles.selector = imdistline(handles.slice_axes, pos(:,1), ...
        pos(:,2));

    % Retrieve handle to slice selector API
    api = iptgetapi(handles.selector);

    % Constrain line to only resize horizontally, and only to the upper 
    % and lower extent of the image using drag constraint function
    fcn = @(pos) [max(start(1), min(pos(:,1))) 0; ...
        min(start(1) + size(imageA, 2) * width(1), max(pos(:,1))) 0];
    api.setDragConstraintFcn(fcn);

    % Hide distance label
    api.setLabelVisible(0);

    % Clear temporary variables
    clear h slice width start stats i B k fcn api pos;
end