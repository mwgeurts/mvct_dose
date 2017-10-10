function table = LoadIVDTFile(file, table)
% LoadIVDTFile is called by MVCTdose during initialization and loads the
% default IVDT from the provided file location. It returns by updating the
% GUI IVDT table with the file contents.
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

% Log start
Event('Loading default IVDT');

% Open read file handle to default ivdt file
fid = fopen(file, 'r');

% If a valid file handle is returned
if fid > 2
    
    % Retrieve first line
    tline = fgetl(fid);
    
    % Match CT numbers
    s = strsplit(tline, '=');
    ctNums = textscan(s{2}, '%f');
    
    % Retrieve second line
    tline = fgetl(fid);
    
    % Match density values
    s = strsplit(tline, '=');
    densVals = textscan(s{2}, '%f');
    
    % Verify CT numbers and values were found
    if ~isempty(ctNums) && ~isempty(densVals)
        
        % Verify lengths match
        if length(ctNums{1}) ~= length(densVals{1})
            Event('Default IVDT vector length mismatch', 'ERROR');
        
        % Verify at least two elements exist
        elseif length(ctNums{1}) < 2
            Event('Default IVDT does not contain enough values', 'ERROR');
            
        % Verify the first CT number value is zero
        elseif ctNums{1}(1) ~= 0
            Event('Default IVDT first CT number must equal zero', 'ERROR');
            
        % Otherwise, set IVDT table
        else
            
            % Initialize ivdt temp cell array
            ivdt = cell(length(ctNums{1}) + 1, 2);
            
            % Loop through elements, writing formatted values
            for i = 1:length(ctNums{1})
                
                % Save formatted numbers
                ivdt{i,1} = sprintf('%0.0f', ctNums{1}(i) - 1024);
                ivdt{i,2} = sprintf('%g', densVals{1}(i));
                
            end
            
            % Set UI table contents
            set(table, 'Data', ivdt);
            
            % Log completion
            Event(sprintf(['Default IVDT loaded successfully with %i ', ...
                'elements'], length(ctNums{1})));
        end
    else
        % Otherwise, throw an error
        Event('Default IVDT file is not formatted correctly', 'ERROR');
    end
    
    % Close file handle
    fclose(fid);
    
else
    % Otherwise, throw error as default IVDT is missing
    Event('Default IVDT file is missing', 'ERROR');
end

% Clear temporary variables
clear fid tline s ctNums densVals ivdt i;