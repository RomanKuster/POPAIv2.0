function runBehaviourPredictionActivPal(varargin)
% COPYRIGHT (c) 2021, Roman P Kuster, roman.kuster@alumni.ethz.ch. All 
% rights reserved. Redistribution and use in source and binary forms, with
% or without modification, are permitted for academic purposes provided the
% conditions and disclaimer in the README file are met. Use for commercial
% purposes is prohibited.
%
% This function loads activPAL(R) event files (.pal) and raw data files
% (.datx) to predict sedentary behaviour. Execute the function by typing
% runBehaviourPrediction in the command window, and select the folder
% containing your pal and datx files in the explorer window that pops-up.
% Please carefully read the README file distributed with this function.
%
% Output file: a .csv file for each subject containing the behaviour
% prediction in the subject folder (*EventsSedentary.csv), a .xls file for
% all subjects containing the behaviour prediction in the main folder
% (Summarised Behaviour Prediction_date-time.xls).
%
% The following optional input arguments are available (Name,Value):
% *'UseProtocolFileToLimitTime','Yes': uses the *Protocol*.xls file to
%  limit the processing to the specified start and stop time. See README
%  file distributed with this function for instruction on the xls file
%  format.
% *'ExcludeExtralongEpisodesInHours',24: excludes sitting events of at
%  least the specified duration (in hours), e.g. 24 hours. These events are
%  assigned a code of 99 in the output files.
% *'ExcludeSubjectsHavingOutputCSV','Yes': excludes subjects having already
%  an outputfile available.
% *'ExcludeNonValidTimeInOutput','Yes': erases all non-valid minutes in the
%  output file.
% *'SuppressSummaryFile','Yes': suppress the generation of a summary xls 
%  file for all subjects.
% *'SumAdjacentEpisodes','Yes': summarize adjacent episodes of the same
%  activPAL code into one episode.
% All optional input arguments are deactivated by default.
%
% The function uses the matlab toolbox published by R. Broadley, available 
% from https://github.com/R-Broadley/activpal_utils-matlab.
% Without the toolbox, the command window will tell you how to create a raw
% data .csv file to be load instead of the .datx file.
%
% Function last modified on the 16th of May 2021.


%% %%%%%%%%%%%%%%%%%%%%%%% VARARGIN HANDLING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set Default Values if varargin is not specified;
UseProtocolFileToLimitTime = 'No';      % case sensitive to 'Yes' -> uses protocol to limit data processing
ExcludeExtralongEpisodesInHours = 2;    % contains minmum duration of episodes excluded from sedentary behaviour prediction, zero defines no exclusion, enter number in hours
ExcludeSubjectsHavingOutputCSV = 'No';  % case sensitive to 'Yes' -> skip subjects when file "*EventsSedentary.csv" exists
ExcludeNonValidTimeInOutput = 'No';     % case sensitive to 'Yes' -> erase all non-valid minutes in the output file
SupressSummaryFile = 'No';              % case sensitive to 'Yes' -> skip creation of summary file
SumAdjacentEpisodes = 'No';             % case sensitive to 'Yes' -> Sums adjacent episodes, i.e. stepping episodes

% Handle varargin
if nargin > 0
    optionNames = varargin(1:2:end);
    optionValues = varargin(2:2:end);
    for k = 1:numel(optionNames)
        switch optionNames{k}
            case "UseProtocolFileToLimitTime"
                UseProtocolFileToLimitTime = optionValues{k};
            case "ExcludeExtralongEpisodesInHours"
                ExcludeExtralongEpisodesInHours = optionValues{k};
            case "ExcludeSubjectsHavingOutputCSV"
                ExcludeSubjectsHavingOutputCSV = optionValues{k};
            case "ExcludeNonValidTimeInOutput"
                ExcludeNonValidTimeInOutput = optionValues{k};
            case "SupressSummaryFile"
                SupressSummaryFile = optionValues{k};
            case "SumAdjacentEpisodes"
                SumAdjacentEpisodes = optionValues{k};
        end
    end
end


%% %%%%%%%%%%%%%%%%%%%% GET & CHECK INPUT FILES %%%%%%%%%%%%%%%%%%%%%%%%%%%
% get ParentDirectory containing the data with a pop-up window:
ParentDataDirectory = uigetdir(pwd,'Select the folder containing the participant folders');

% search for all pal, datx, and output-csv files in ParentDirectory, incl. subfolders:
files.PAL = dir([ParentDataDirectory,'\**\*.pal']);
files.DATX = dir([ParentDataDirectory,'\**\*.datx']);
files.CSV = dir([ParentDataDirectory,'\**\*EventsSedentary.csv']);

% compare whether the pal and datx files match (number and name):
if numel(files.PAL) ~= numel(files.DATX) % if they do not match
    if numel(files.PAL) > numel(files.DATX)
        disp('There are more .pal files than .datx files')
    else
        disp('There are more .datx files than .pal files')
    end
    error(['Please make sure every .pal file has a corresponding .datx file in ',ParentDataDirectory, ' (including subfolders)'])
    
else % if they do, check whether they have the same name:
    filenames.PAL = arrayfun(@(x) extractBefore(convertCharsToStrings(x.name),'.'),files.PAL); % get name without .pal
    filenames.DATX = arrayfun(@(x) extractBefore(convertCharsToStrings(x.name),'.'),files.DATX); % get name without .datx
    if isequal(filenames.PAL,filenames.DATX) ~= 1
        error(['The names of pal and datx files do not match, check your data in ',ParentDataDirectory, ' (including subfolders)'])
    else
        disp(['Filenames successfully checked, the following ', num2str(numel(files.PAL)), ' file(s) were detected: '])
        disp(filenames.PAL)
    end
end
clear filenames


%% %%%%%%%%%%%%%%%%%%%% PREPARE DATA PROCESSING %%%%%%%%%%%%%%%%%%%%%%%%%%%
% Load the activity prediction algorithm:
try
    load('ActivityPredictionAlgorithm','ActivityPredictionAlgorithm')
catch
    error('ActivityPredictionAlgorithm not found, make sure the algorithm is stored in the Matlab folder containing the functions')
end

% Load protocol data if UseProtocolFileToLimitTime set to Yes:
if strcmp(UseProtocolFileToLimitTime,'Yes')
    disp('loading the protocol')
    dirProtocol = dir([ParentDataDirectory,'\*Protocol*.xlsx']); % locate protocol
    if isempty(dirProtocol)
        disp('Protocol not found, ensure there is an xlsx file in the selected directory containing the case sensitive word *Protocol*')
    elseif numel(dirProtocol) > 1
        disp('More than 1 Protocol found, ensure there is only one xlsx file in the selected directory containing the case sensitive word *Protocol*. This error might also occur if you have to protocol file currently open, close it and re-try')
    end
    ProtocolTable = readtable([dirProtocol.folder,'\',dirProtocol.name]); % Read Protocol file
    varNames = ProtocolTable.Properties.VariableNames; % get variable names
    % replace NaN for Daytime
    ProtocolTable.(varNames{3})(isnan(ProtocolTable.(varNames{3}))) = 0; % start at 00:00 (input in days)
    ProtocolTable.(varNames{5})(isnan(ProtocolTable.(varNames{5}))) = 1; % stop at 24:00 (input in days)
    % get start and stop time since first day
    ProtocolTable.StartTimeSinceFirstDay = datenum(ProtocolTable.(varNames{2})) + ProtocolTable.(varNames{3}); % NaN if no day was specified
    ProtocolTable.StopTimeSinceFirstDay = datenum(ProtocolTable.(varNames{4})) + ProtocolTable.(varNames{5}); % NaN if no day was specified
end



%% %%%%%%%%%%%%%%%%%% PROCESS FILES SUBJECTWISE %%%%%%%%%%%%%%%%%%%%%%%%%%%
for sub = 1:numel(files.PAL)
    foldernameSubject = files.PAL(sub,1).folder;
    filenameSubjectPAL = files.PAL(sub,1).name;
    filenameSubjectDATX = files.DATX(sub,1).name;
    
    % Check whether the subjects outputfile is already there
    if strcmp(ExcludeSubjectsHavingOutputCSV,'Yes') && isfile([foldernameSubject,'\',files.PAL(sub).name(1:end-4),' EventsSedentary.csv'])
        disp(['Processing of subject ',num2str(sub),' of ',num2str(numel(files.PAL)),' skipped, outputfile for "',files.PAL(sub).name(1:end-4),'" is already there'])
    else
        
        %% 1) Load Episode File (.pal) -> loadPALfileAP.m
        disp(['Processing of subject ',num2str(sub),' of ',num2str(numel(files.PAL)),' running (file: ',files.PAL(sub).name(1:end-4),')'])
        episodeTable = loadPALfileAP(foldernameSubject,filenameSubjectPAL,'SumAdjacentEpisodes',SumAdjacentEpisodes); % Optional Input: 'summarizeAdjacentEpisodes',1 to sum adjacent stepping episodes
        % convert Excel Time to MATLAB Time (to match with rawdata):
        episodeTable.TimeSinceFirstDay = x2mdate(episodeTable.TimeSinceFirstDay);
        % change initial sitting code to 99
        episodeTable.BehaviourCode(episodeTable.BehaviourCode == 0) = 99;
        
        
        %% 2) Limit data to protocol time -> limitDataToProtocolAP.m
        if strcmp(UseProtocolFileToLimitTime,'Yes')
            % get subfolder name of the subject to match with Protocol data
            idxLastSlash = find(files.PAL(sub).folder == '\', 1, 'last');
            subfoldernameSubject = files.PAL(sub).folder(idxLastSlash+1:end);
            % limit data:
            episodeTable = limitDataToProtocolAP(episodeTable, ProtocolTable, subfoldernameSubject);
        end
        
        
        %% 2) Extract episodes to predict -> extractEpisodesToPredictAP.m
        % get the start of each minute to predict:
        [EpisodesToPredict,episodeTable] = extractEpisodesToPredictAP(episodeTable,ExcludeExtralongEpisodesInHours);
        
        
        %% 3) Load Raw File (.datx) -> loadDATXfileAP.m
        rawData = loadDATXfileAP(foldernameSubject,filenameSubjectDATX); % empty table if file can't be load
        
        % continue only in case rawData is not empty
        if ~isempty(rawData)
            
            
            %% 4) Get Features and Predict the Behaviour -> getFeaturesAndPredictAP.m
            [EpisodesToPredict] = getFeaturesAndPredictAP(rawData,EpisodesToPredict,ActivityPredictionAlgorithm);
            
            
            %% 5) add Prediction to episodeTable (code -1 for sedentary, code 0 for active sitting) -> local
            episodeTable.Prediction(EpisodesToPredict.idxepisodeTable) = EpisodesToPredict.Prediction;
            episodeTable.BehaviourCode(episodeTable.Prediction==1) = -1; % Sedentary Behaviour was predicted
            episodeTable.BehaviourCode(episodeTable.Prediction==2) = 0;  % Active Sitting was predicted
            
            % erase non-valid minutes if desired
            if strcmp(ExcludeNonValidTimeInOutput,'Yes')
                episodeTable(episodeTable.BehaviourCode==99,:) = [];
            end
            
            %% 6) Summarize adjacent sitting episodes -> local
            idx = find(diff(episodeTable.BehaviourCode)==0 & episodeTable.BehaviourCode(1:end-1) <= 0); % rows with same code follows and row is sedentary or active sitting
            while isempty(idx) == 0
                episodeTable.Duration(idx(end)) = episodeTable.Duration(idx(end)) + episodeTable.Duration(idx(end)+1); % sum the episodes together, starting at last episode to keep idx true
                episodeTable(idx(end)+1,:) = [];
                idx(end) = [];
            end
            
            
            
            %% 7) Create OutputFile in InputFolder of each Subject -> local
            % Convert MatlabTime back to ExcelTime:
            episodeTable.TimeSinceFirstDay = m2xdate(episodeTable.TimeSinceFirstDay);
            % Remove Prediction column:
            episodeTable.Prediction = [];
            % Change Step Count into Cummulative Step Count:
            episodeTable.StepCount = cumsum(episodeTable.StepCount);
            % Add DataCount row:
            episodeTable.DataCount = round((episodeTable.TimeSinceFirstDay - episodeTable.TimeSinceFirstDay(1))*24*60*60*10); % tenth of a second resolution from days
            % Change order to Match activPAL episode file:
            episodeTable = episodeTable(:,[1 6 2 3 4 5]);
            % add Header information
            Header(1,1:6) = {'Time'; 'DataCount (samples)'; 'Interval (s)'; 'Behaviour Code (-1 = sedentary, 0 = active sitting, 1 = standing, 2 = stepping, 99 = sitting in excluded long bouts)';'CumulativeStepCount';'Activity Score (MET.h)'};
            % combine Header and episodeTable to Cell:
            episodeCell = [Header;table2cell(episodeTable)];
            % save to csv:
            writecell(episodeCell,[foldernameSubject,'\',files.PAL(sub).name(1:end-4),' EventsSedentary.csv'])
            disp(['  -> The csv file of the subject saved to file "',files.PAL(sub).name(1:end-4),' EventsSedentary.csv" in folder ',foldernameSubject,' (runBehaviourPredictionActivPal.m)'])
            
            if ~strcmp(SupressSummaryFile,'Yes')
                % create struct containing all ...
                episodeTablesSubjects{sub,1} = episodeCell; % ... data
                ind = strfind(files.PAL(sub).name,' ');
                episodeTablesSubjects{sub,2} = files.PAL(sub).name(1:ind); % ... and subject name until first space
            end
            
        else
            disp(['Create .csv rawdata for datx file: ',files.DATX(sub).name,])
        end
    end
end


%% 8) Create summarized OutputFile in InputFolder for all Subjects -> local
if ~strcmp(SupressSummaryFile,'Yes') && exist('episodeTablesSubjects')
    % Write data of all subjects in one xls, spreadsheet by spreadsheet
    % remove empty lines in episodeTablesSubjects
    idx = cellfun(@isempty,episodeTablesSubjects(:,1));
    episodeTablesSubjects(idx,:) = [];
    % append time to prevent overwriting previous rounds
    rightnow = datestr(now, 'yyyy-mm-dd-HH-MM');
    warning('off','matlab:xlswrite:AddSheet') % suppress warning that spreadsheet was added
    for sub = 1:numel(episodeTablesSubjects)/2
        writecell(episodeTablesSubjects{sub,1},[ParentDataDirectory,'\','Summarised Behaviour Prediction_',rightnow,'.xls'],'Sheet',episodeTablesSubjects{sub,2})
    end
    warning('on','matlab:xlswrite:AddSheet') % stop suppressing warning
    disp('Behaviour prediction completed')
    disp(['---> The xls file of all subject saved to file "Summarised Behaviour Prediction.xls" in folder ',ParentDataDirectory,' (runBehaviourPredictionActivPal.m)'])
    disp('Good luck with further processing')
else
    disp('Behaviour prediction completed')
    disp('no "Summarised Behaviour Prediction.xls" file generated')
    disp('Good luck with further processing')
end

return