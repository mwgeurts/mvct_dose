function sinogram = LoadSinogram(path, name)
% LoadSinogram reads in a binary file, verifies it is formatted correctly,
% and returns a 64 x n array containing the sinogram values.  The function
% will attempt to automatically determine the file format; acceptable
% number formats are single or double, while acceptable endian formats big 
% or little.
%
% The following variables are required for proper execution: 
%   path: string containing the path to the sinogram file
%   name: string containing the name of the binary sinogram in path
%
% The following variables are returned upon succesful completion:
%   sinogram: 64 x n array of leaf open fractions. If unsuccessful, an
%       empty array is returned.
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

% Log start of plan load and start timer
Event(sprintf('Extracting sinogram from %s', name));
tic;

% Initialize empty return variable
sinogram = [];

% Declare endian types, in order of priority
endians = {'little', 'big'};

% Declare number formats, in order of priority
formats = {'single', 'double'};

% Retrieve the file info
fileinfo = dir(fullfile(path, name));
Event(sprintf('File size is %f bytes', fileinfo(1).bytes));

% Initialize break flag
flag = false;

% Loop through number formats
for i = 1:length(formats)
    
    % Loop through endian types
    for j = 1:length(endians)
        
        % Attempt to open read file handle with given endian type
        fid = fopen(fullfile(path, name), 'r', endians{j}(1));
        
        % If a valid file handle was returned
        if fid > 2
            
            % Attempt to read file in a try catch statement
            try
                
                % Read in file, reshaping to 64 x n array
                temp = fread(fid, [64, Inf], formats{i});
                
                % Close file handle
                fclose(fid);
                
                % If result contains values between zero and one
                if min(min(temp)) >= 0 && max(max(temp)) <= 1
                    
                    % Store result as sinogram
                    sinogram = temp;
                    
                    % Set break flag
                    flag = true;
                    
                    % Break nested for loop
                    break;
                end
            catch
                % Close file handle
                fclose(fid);
                
                % If an error occurred, skip to next format
                continue
            end
            
            
        else
            % Otherwise throw an error
            Event('A file handle could not be opened to the provided file', ...
                'ERROR');
        end
    end
    
    % If the break flag was set, break out of both loops
    if flag; break; end
end

% Clear temporary variables
clear fileinfo temp endians formats i j;

% If the sinogram variable was set
if ~isempty(sinogram)
    
    % Report success
    Event(sprintf(['Sinogram loaded successfully with %i projections', ...
        ' in %0.3f seconds'], size(sinogram, 2), toc));
else
    % Report failure
    Event(['The provided file could not be parsed. The binary file must ', ...
        'be formatted as single or double numbers between zero and one, ', ...
        'with an integer multiple of 64 elements'], 'ERROR');
end