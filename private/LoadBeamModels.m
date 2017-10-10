function beammodels = LoadBeamModels(path)
% LoadBeamModels is called by MVCTdose during initialization to search for
% beam models in the provided folder. A list of beam models is returned as
% a cell array.
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

% Initialize beam models cell array
beammodels = {'Select AOM'};

% Search for folder list in beam model folder
Event(sprintf('Searching %s for beam models', path));
dirs = dir(path);

% Loop through results
for i = 1:length(dirs)
    
    % If the result is not a directory, skip
    if strcmp(dirs(i).name, '.') || strcmp(dirs(i).name, '..') || ...
            dirs(i).isdir == 0
        continue;
    else
       
        % Check for beam model files
        if exist(fullfile(path, dirs(i).name, 'dcom.header'), ...
                'file') == 2 && exist(fullfile(path, ...
                dirs(i).name, 'fat.img'), 'file') == 2 && ...
                exist(fullfile(path, dirs(i).name, ...
                'kernel.img'), 'file') == 2 && ...
                exist(fullfile(path, dirs(i).name, 'lft.img'), ...
                'file') == 2 && exist(fullfile(path, ...
                dirs(i).name, 'penumbra.img'), 'file') == 2
            
            % Log name
            Event(sprintf('Beam model %s verified', dirs(i).name));
            
            % If found, add the folder name to the beam models cell array
            beammodels{length(beammodels)+1} = dirs(i).name;
        else
            
            % Otherwise log why folder was excluded
            Event(sprintf(['Folder %s excluded as it does not contain all', ...
                ' required beam model files'], dirs(i).name), 'WARN');
        end
    end
end

% Log total number of beam models found
Event(sprintf('%i beam models found', length(beammodels) - 1));

% Clear temporary variables
clear dirs i;