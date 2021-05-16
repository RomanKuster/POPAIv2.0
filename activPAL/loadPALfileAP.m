function [episodeTable] = loadPALfileAP(foldernameSubject,filenameSubjectPAL,varargin)
% Load .pal Episode file, and sum adjacent Episode of same BehaviourCode if
% optional Input "SumAdjacentEpisodes" is set to Yes (default is No).


%% VARARGIN handling
SumAdjacentEpisodes = 'No'; % default
if nargin > 2
    optionNames = varargin(1:2:end);
    optionValues = varargin(2:2:end);
    for k = 1:numel(optionNames)
        switch optionNames{k}
            case "SumAdjacentEpisodes"
                SumAdjacentEpisodes = optionValues{k};
        end
    end
end


%% Predefinitions
Header_pal = 36; % Header-size of the .pal file
fieldorder_pal = {'TimeSinceFirstDay';'Duration';'BehaviourCode';'StepCount';'ActivityScore'}; % Order of Output Table


%% Load Episode file
addpath(foldernameSubject) % add path to directory
fileID = fopen(filenameSubjectPAL);
fseek(fileID,Header_pal,'bof'); % start reading the file after the header

% Go through each bit of the file
i = 1; stop = 1;
while stop
    try % try to solve...
        dataOriginal.TimeSinceFirstDay(i,1) = fread(fileID, 1, 'double');
        DataCount(1) = fread(fileID, 1, 'ulong');
        dataOriginal.BehaviourCode(i,1) = fread(fileID, 1, 'ubit8');
        Amplitude(1) = fread(fileID, 1, 'uint16');
        dataOriginal.Duration(i,1) = fread(fileID, 1, 'single');
        dataOriginal.StepCount(i,1) = fread(fileID, 1, 'single');
        CumStepCount(1) = fread(fileID, 1, 'single');
        dataOriginal.ActivityScore(i,1) = fread(fileID, 1, 'single');
        ActualValue(1) = fread(fileID, 1, 'ubit8');
        Envelope(1) = fread(fileID, 1, 'ulong');
        i = i+1;
    catch % ... if an error occurs (end is reached):
        stop = 0;
    end
end
% terminate loading
fclose(fileID);
% Order the fields in desired manner
dataOriginal = orderfields(dataOriginal,fieldorder_pal);


%% Summarize adjacent Episodes if desired and create episodeTable
if strcmp(SumAdjacentEpisodes,'Yes')
    % add a Fake Code in the end to detect last episode
    dataOriginal.BehaviourCode(end+1) = 999;
    % detect Code Changes
    newEpisodesIdx(:,2) = find(diff(dataOriginal.BehaviourCode)~=0); % detect end of episode
    newEpisodesIdx(2:end,1) = newEpisodesIdx(1:end-1,2)+1; % next episode starts 1 idx later
    newEpisodesIdx(1,1) = 1; % first episodes starts always at idx 1
    % preallocate the new Struct
    a = zeros(length(newEpisodesIdx),1);
    dataSummed = struct('TimeSinceFirstDay',a,'Duration',a,'BehaviourCode',a,'StepCount',a,'ActivityScore',a); clear a
    % and summarize the Original Episodes
    for j = 1:length(newEpisodesIdx)
        dataSummed.TimeSinceFirstDay(j,1) = dataOriginal.TimeSinceFirstDay(newEpisodesIdx(j,1)); % take start value
        dataSummed.Duration(j,1) = sum( dataOriginal.Duration(newEpisodesIdx(j,1):newEpisodesIdx(j,2)) ); % sum all values
        dataSummed.BehaviourCode(j,1) = dataOriginal.BehaviourCode(newEpisodesIdx(j,1)); % take start value
        dataSummed.StepCount(j,1) = sum( dataOriginal.StepCount(newEpisodesIdx(j,1):newEpisodesIdx(j,2)) ); % sum all values
        dataSummed.ActivityScore(j,1) = sum( dataOriginal.ActivityScore(newEpisodesIdx(j,1):newEpisodesIdx(j,2)) ); % sum all values
    end
    clear newEpisodesIdx a
    % convert struct to Table
    episodeTable = struct2table(dataSummed);
    disp('  -> episodes loaded & summarized...          (loadPALfileAP.m)')
else
    episodeTable = struct2table(dataOriginal);
    disp('  -> episodes loaded...                       (loadPALfileAP.m)')
end

rmpath(foldernameSubject)

return