function image = LoadDICOMImages(path, names)
% LoadDICOMImages loads a series of single-frame DICOM CT images and 
% returns a formatted structure for dose calculation. See below for more 
% information on the structure format.
%
% The following variables are required for proper execution: 
%   path: string containing the path to the DICOM files
%   names: cell array of strings containing all files to be loaded
%
% The following variables are returned upon succesful completion:
%   image: structure containing the image data, dimensions, width, type,
%       start coordinates, and key DICOM header values. The data is a three 
%       dimensional array of CT values, while the dimensions, width, and 
%       start fields are three element vectors.  The DICOM header values 
%       are returned as a strings.
%
% Copyright (C) 2015 University of Wisconsin Board of Regents
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

% Run in try-catch to log error via Event.m
try
    
% Log start of image load and start timer
Event(sprintf('Reading images from %s', path));
tic;

% Start waitbar
progress = waitbar(0, 'Loading DICOM images');

% Initialize empty variables for the UIDs, patient demographics, and image 
% dimensions
image.classUID = '';
image.studyUID = '';
image.seriesUID = '';
image.frameRefUID = '';
image.instanceUIDs = cell(0);
image.patientName = '';
image.patientID = '';
image.width(3) = 0;

% Initialize empty 3D array for images and vector of slice locations
% (the data may not be loaded in correct order; these will be used to
% re-sort the slices later)
images = [];
sliceLocations = [];

% Loop through each file in names list
for i = 1:length(names)
    
    % Update waitbar
    waitbar(i/(length(names)+2), progress);
    
    % Attempt to load each file using dicominfo
    try
        
        % If dicominfo is successful, store the header information
        info = dicominfo(fullfile(path, names{i}));
        
    catch
        
        % Otherwise, the file is either corrupt or not a real DICOM
        % file, so warn user
        Event(['File ', names{i}, ' is not a valid DICOM ', ...
            'image and was skipped'], 'WARN');

        % Then, automatically skip to next file in directory 
        continue
    end 
    
    % If this is the first DICOM image (and the class UID
    % have not yet been set
    if strcmp(image.classUID,'') 
        
        % Store the UIDs, patient demographics, and slice thickness (in cm)
        image.classUID = info.SOPClassUID;
        image.studyUID = info.StudyInstanceUID;
        image.seriesUID = info.SeriesInstanceUID;
        image.frameRefUID = info.FrameOfReferenceUID;
        image.patientName = info.PatientName;
        image.patientID = info.PatientID;
        image.width(3) = info.SliceThickness / 10; % cm
        
    % Otherwise, if this file's study UID does not match the others,
    % multiple DICOM studies may be present in the same folder (not
    % currently supported)
    elseif ~strcmp(image.studyUID, info.StudyInstanceUID)
        Event(['Multiple DICOM Study Instance UIDs were found in ', ...
            'this list.  Please select only one study.'], ...
            'ERROR');
        
    % Otherwise, if this file's series UID does not match the others,
    % multiple DICOM series may be present in the same folder (not
    % currently supported)
    elseif ~strcmp(image.seriesUID,info.SeriesInstanceUID) 
        Event(['Multiple DICOM Series Instance UIDs were found in ', ...
            'this list.  Please select only one series.'], ...
            'ERROR');
        
    % Otherwise, if this file's slice thickness in cm is different than
    % the others, throw an error (variable slice thickness is not 
    % currently supported)
    elseif image.width(3) ~= info.SliceThickness / 10
        Event('Variable slice thickness images found', 'ERROR');
    end
    
    % Append this slice's instance UID
    image.instanceUIDs{length(image.instanceUIDs)+1} = info.SOPInstanceUID;
    
    % Append this slice's location to the sliceLocations vector
    sliceLocations(length(sliceLocations)+1) = ...
        -info.SliceLocation; %#ok<*AGROW>
    
    % Append this slice's image data to the images array
    images(size(images,1)+1,:,:) = dicomread(info); %#ok<*AGROW>
    
    % Log file
    Event(['Reading file ', names{i}]);
end

% Update waitbar
waitbar((length(names)+1)/(length(names)+2), progress, 'Processing images');

% Set image type based on series description (for MVCTs) or DICOM
% header modality tag (for everything else)
if strcmp(info.SeriesDescription, 'CTrue Image Set')
    image.type = 'MVCT';
else
    image.type = info.Modality;
end

% Log image type
Event(['DICOM image type identified as ', image.type]);

% Retrieve start voxel coordinates from DICOM header, in cm
image.start(1) = info.ImagePositionPatient(1) / 10;
image.start(2) = info.ImagePositionPatient(2) / 10;
image.start(3) = min(info.ImagePositionPatient(3)) / 10;

% Retrieve x/y voxel widths from DICOM header, in cm
image.width(1) = info.PixelSpacing(1) / 10;
image.width(2) = info.PixelSpacing(2) / 10;

% If patient is Head First
if info.ImageOrientationPatient(1) == 1
    
    % Log orientation
    Event('Patient position identified as Head First');

    % Sort sliceLocations vector in ascending order
    [~, indices] = sort(sliceLocations, 'ascend');
    
% Otherwise, if the patient is Feet First (currently not supported)
elseif info.ImageOrientationPatient(1) == -1
    
    %Event('Patient position identified as Feet First');
    %[~,indices] = sort(sliceLocations, 'descend');

    % Throw an error as the image type is not currently supported/tested
    Event('Feet first data sets are not currently supported', 'ERROR');

% Otherwise, error as the image orientation is neither
else
    Event(['The DICOM images do not have a standard', ...
        'orientation'], 'ERROR');
end

% Initialize daily image data array as single type
image.data = single(zeros(size(images, 3), size(images, 2), ...
    size(images, 1)));

% Re-order images based on sliceLocation sort indices
Event('Sorting DICOM images');

% Loop through each slice
for i = 1:length(sliceLocations)
    
    % Set the image data based on the index value
    image.data(:, :, i) = ...
        single(rot90(permute(images(indices(i), :, :), [2 3 1])));
end

% Flip the image in the second direction
image.data = flipud(image.data);

% Create dimensions structure field based on the daily image size
image.dimensions = size(image.data);

% Update waitbar
waitbar(1.0, progress, 'Image loading completed');

% If an image was successfully loaded
if isfield(image, 'dimensions')
    
    % Log completion and image size
    Event(sprintf(['DICOM images loaded successfully with dimensions ', ...
        '(%i, %i, %i) in %0.3f seconds'], image.dimensions, toc));

% Otherwise, warn user
else
    Event('DICOM image data could not be parsed', 'ERROR');
end

% Close waitbar
close(progress);

% Clear temporary variables
clear i images info sliceLocations indices progress;

% Catch errors, log, and rethrow
catch err
    
    % Delete progress handle if it exists
    if exist('progress','var') && ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end