function structures = LoadDICOMStructures(varargin)
% LoadDICOMStructures loads a DICOM RT Structure Set (RTSS) file and
% extracts the structure information into a MATLAB cell array. See below 
% for more information on the structure format.  This function may
% optionally also be passed with an atlas, whereby only structures matching
% the atlas include/exclude statements are returned.
%
% The following variables are required for proper execution: 
%   varargin{1}: string containing the path to the DICOM files
%   varargin{2}: string containing the DICOM RTSS file to be loaded
%   varargin{3}: structure of reference image.  Must include a frameRefUID
%       field referencing the structure set, as well as dimensions, width, 
%       and start fields
%   varargin{4} (optional): cell array of atlas names, include/exclude 
%       regex statements, and load flags (if zero, matched structures will 
%       not be loaded)
%
% The following variable is returned upon succesful completion:
%   structures: cell array of structure names, color, frameRefUID, and 3D 
%       mask array of same size as reference image containing fraction of 
%       voxel inclusion in structure
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

% Log start of plan load and start timer
Event(sprintf(['Generating structure masks from %s for frame of ', ...
    'reference %s'], varargin{2}, varargin{3}.frameRefUID));
tic;

% Start waitbar
progress = waitbar(0, 'Loading DICOM structure set');

% Read DICOM header info from file
info = dicominfo(fullfile(varargin{1}, varargin{2}));

% Update progress bar
waitbar(0.1, progress);

% Initialize return variable
structures = cell(length(fieldnames(info.ROIContourSequence)), 1);

% If no structures were found
if isempty(structures)
    
    % Throw an error
    Event('No contours were found', 'ERROR');
end

% Loop through each StructureSetROISequence field
for item = fieldnames(info.StructureSetROISequence)'
    
    % Store contour number
    n = info.StructureSetROISequence.(item{1}).ROINumber;
    
    % Store the ROIName variable
    name = info.StructureSetROISequence.(item{1}).ROIName;
    
    % Initialize load flag.  If this structure name matches a structure in 
    % the provided varargin{3} with load set to false, this structure will not be
    % loaded
    load = true;
    
    %% Compare name to atlas
    if nargin == 4
        
        % Loop through each atlas structure
        for j = 1:size(varargin{4}, 2)

            % Compute the number of include atlas REGEXP matches
            in = regexpi(name, varargin{4}{j}.include);

            % If the atlas structure also contains an exclude REGEXP
            if isfield(varargin{4}{j}, 'exclude') 
                
                % Compute the number of exclude atlas REGEXP matches
                ex = regexpi(name, varargin{4}{j}.exclude);
                
            else
                % Otherwise, return 0 exclusion matches
                ex = [];
            end

            % If the structure matched the include REGEXP and not the
            % exclude REGEXP (if it exists)
            if size(in,1) > 0 && size(ex,1) == 0
                
                % Set the load flag based on the matched atlas structure
                load = varargin{4}{j}.load;

                % Stop the atlas for loop, as the structure was matched
                break;
            end
        end

        % Clear temporary variables
        clear in ex j;
    end
    
    % If the load flag is still set to true
    if load 
        
        % If the structure frame of reference matches the image frame of 
        % reference
        if strcmp(varargin{3}.frameRefUID, info.StructureSetROISequence.(...
                item{1}).ReferencedFrameOfReferenceUID)
        
            % Store structure name
            structures{n}.name = name;
            
            % Store the frameRefUID
            structures{n}.frameRefUID = info.StructureSetROISequence.(...
                item{1}).ReferencedFrameOfReferenceUID;

        % Otherwise, the frame of reference does not match
        else
            
            % Notify user that this structure was skipped
            Event(['Structure ', name, ' frame of reference did not match ', ...
                'the image and will not be loaded']);
        
        end
        
    % Otherwise, the load flag was set to false during atlas matching
    else
        
        % Notify user that this structure was skipped
        Event(['Structure ', name, ' matched exclusion list from atlas', ...
            ' and will not be loaded']);
    end
    
    % Clear temporary variables
    clear name;
end

% Update progress bar
waitbar(0.2, progress);

% Loop through each ROIContourSequence
for item = fieldnames(info.ROIContourSequence)'
   
    % Store contour number
    n = info.ROIContourSequence.(item{1}).ReferencedROINumber;
    
    % Update progress bar
    waitbar(0.2 + 0.8 * n/length(fieldnames(info.ROIContourSequence)), ...
        progress);
    
    % If name was loaded (and therefore this contour matches the atlas
    if isfield(structures{n}, 'name')
    
        % Log contour being loaded
        Event(sprintf('Loading structure %s (%i curves)', ...
            structures{n}.name, length(fieldnames(info.ROIContourSequence.(...
                item{1}).ContourSequence))));
        
        % Store the ROI color, if it exists
        if isfield(info.ROIContourSequence.(item{1}), 'ROIDisplayColor')
            structures{n}.color = ...
                info.ROIContourSequence.(item{1}).ROIDisplayColor';
        else
            structures{n}.color = [0 0 0];
        end
        
        % Generate empty logical mask of the same image size as the reference
        % image (see LoadDICOMImages for more information)
        structures{n}.mask = false(varargin{3}.dimensions); 

        % Inititalize structure volume
        structures{n}.volume = 0;
        
        % Loop through each ContourSequence
        for subitem = fieldnames(info.ROIContourSequence.(...
                item{1}).ContourSequence)'
           
            % If no contour points exist
            if info.ROIContourSequence.(item{1}).ContourSequence.(...
                    subitem{1}).NumberOfContourPoints == 0
                
                % Skip to next sequence
                continue;
            
            % Otherwise, continue to load points
            else
                
                % Read in the number of points in the curve, converting 
                % from mm to cm
                points = reshape(info.ROIContourSequence.(...
                    item{1}).ContourSequence.(subitem{1}).ContourData, ...
                    3, [])' / 10;
                
                % Determine slice index by searching IEC-Y index using 
                % nearest neighbor interpolation
                slice = interp1(varargin{3}.start(3):varargin{3}.width(3):...
                    varargin{3}.start(3) + (varargin{3}.dimensions(3) - 1) ...
                    * varargin{3}.width(3), 1:varargin{3}.dimensions(3), ...
                    points(1,3), 'nearest', 0);
                
                % If the slice index is within the reference image
                if slice ~= 0
                    
                    % Test if voxel centers are within polygon defined by 
                    % point data, adding result to structure mask.  Note 
                    % that voxels encompassed by even numbers of curves are 
                    % considered to be outside of the structure (ie, 
                    % rings), as determined by the addition test below
                    mask = poly2mask((points(:,2) + varargin{3}.width(2)/2 ...
                        - varargin{3}.start(2)) / varargin{3}.width(2) + 1, ...
                        (points(:,1) + varargin{3}.width(1)/2 - ...
                        varargin{3}.start(1)) / varargin{3}.width(1) + 1, ...
                        varargin{3}.dimensions(1), ...
                        varargin{3}.dimensions(2));

                    % If the new mask will overlap an existing value, subtract
                    if max(max(mask + structures{n}.mask(:,:,slice))) == 2
                        structures{n}.mask(:,:,slice) = ...
                            structures{n}.mask(:,:,slice) - mask;

                    % Otherwise, add it to the mask
                    else
                        structures{n}.mask(:,:,slice) = ...
                            structures{n}.mask(:,:,slice) + mask;
                    end

                % Otherwise, the contour data exists outside of the IEC-y 
                else
                    
                    % Warn the user that the contour did not match a slice
                    Event(['Structure ', structures{n}.name, ' contains', ...
                        ' contours outside of image array'], 'WARN');
                end
            end
        end
        
        % Compute volumes from mask (note, this will differ from the true
        % volume as partial voxels are not considered
        structures{n}.volume = sum(sum(sum(structures{n}.mask))) * ...
            prod(varargin{3}.width);

        % Flip the structure mask in the third dimension
        structures{n}.mask = flip(structures{n}.mask, 3);
        
        % Check if at least one voxel in the mask was set to true
        if max(max(max(structures{n}.mask))) == 0
            
            % If not, warn the user that the mask is empty
            Event(['Structure ', structures{n}.name, ...
                ' is less than one voxel and will be removed'], 'WARN');
            
            % Clear structure from return variable
            structures{n} = [];
        end
    end
end

% Remove empty structure fields
structures = structures(~cellfun('isempty', structures));

% Update waitbar
waitbar(1.0, progress, 'Structure set loading completed');

% Log completion of function
Event(sprintf('Successfully loaded %i structures in %0.3f seconds', ...
    length(structures), toc));

% Close waitbar
close(progress);

% Clear temporary files
clear info n item subitem points slice mask load progress;

% Catch errors, log, and rethrow
catch err
    
    % Delete progress handle if it exists
    if exist('progress','var') && ishandle(progress), delete(progress); end
    
    % Log error via Event.m
    Event(getReport(err, 'extended', 'hyperlinks', 'off'), 'ERROR');
end