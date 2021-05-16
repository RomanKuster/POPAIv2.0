function runBehaviourPredictionActiGraph(varargin)
% COPYRIGHT (c) 2021, Roman P Kuster, roman.kuster@alumni.ethz.ch. All 
% rights reserved. Redistribution and use in source and binary forms, with
% or without modification, are permitted for academic purposes provided the
% conditions and disclaimer in the README file are met. Use for commercial
% purposes is prohibited.
%
% This function loads ActiGraph(R) counts-per-second and raw data files
% (both in .csv format) to predict sedentary behaviour. Execute the 
% function by typing runBehaviourPrediction in the command window, and 
% select the folder containing your csv files in the explorer window that 
% pops-up. Please carefully read the README file distributed with this 
% function.
%
% Output file: a .csv file for each subject containing the behaviour
% prediction (*1minSedentaryBehaviour.csv), a .xlsx file for all subjects 
% containing the sedentary behaviour prediction
% (Summarised Behaviour Prediction_date-time.csv).
%
% The following optional input arguments are available (Name,Value):
% *'UseProtocolFileToLimitTime','Yes': uses the *Protocol*.xls file to
%  limit the processing to the specified start and stop time. See README
%  file distributed with this function for instruction on the xls file
%  format.
% *'ExcludeSubjectsHavingOutputCSV','Yes': excludes subjects having already
%  an outputfile available.
% *'SuppressSummaryFile','Yes': suppress the generation of a summary xlsx 
%  file for all subjects.
% *'ExcludeNonValidTimeInOutput','Yes': deletes minutes from the output
%  file if time was not covered by the protocol, no effect if no protocol
%  is used.
% *'AxisOrder', {'y','x','z'}: Change the order of the axis in the input
%  files (counts-per-second AND raw data), e.g. to y, x, z (default is x,
%  y, z).
% *'CutPoints', [100, 200]: Change the cut-points used to separate inactive
%  and active sitting (first entry, e.g. 100) and/or inactive and active
%  standing (second entry, e.g. 200). Default is 75 (sitting) and 150
%  (standing).
% All optional input arguments are deactivated by default.
%
% Function last modified on the 26th of April 2021.

%% %%%%%%%%%%%%%%%%%%%%%%% VARARGIN HANDLING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set Default Values if varargin is not specified;
UseProtocolFileToLimitTime = 'Yes';        % case sensitive to 'Yes' -> uses protocol to limit data processing, check template
ExcludeSubjectsHavingOutputCSV = 'No';    % case sensitive to 'Yes' -> skip subjects when file "*1minBehaviour.csv" exists
SupressSummaryFile = 'No';                % case sensitive to 'Yes' -> supresses summary file for all subjects
ExcludeNonValidTimeInOutput = 'Yes';       % case sensitive to 'Yes' -> erase all non-valid minutes in the output file
AxisOrder = {'x','y','z'};                % specifies axis order in RAW and CPS file
CutPoints = [75, 150];                    % counts-per-minute cut-point to separate inactive and active sitting and standing.

% Handle varargin
if nargin > 0
    optionNames = varargin(1:2:end);
    optionValues = varargin(2:2:end);
    for k = 1:numel(optionNames)
        switch optionNames{k}
            case "UseProtocolFileToLimitTime"
                UseProtocolFileToLimitTime = optionValues{k};
            case "ExcludeSubjectsHavingOutputCSV"
                ExcludeSubjectsHavingOutputCSV = optionValues{k};
            case "SupressSummaryFile"
                SupressSummaryFile = optionValues{k};
            case "AxisOrder"
                AxisOrder = optionValues{k};
            case "CutPoints"
                CutPoints = optionValues{k};
        end
    end
end
AxisOrderNumb = [find([AxisOrder{:}] == 'x'),find([AxisOrder{:}] == 'y'),find([AxisOrder{:}] == 'z'),];


%% %%%%%%%%%%%%%%%%%%%% GET & CHECK INPUT FILES %%%%%%%%%%%%%%%%%%%%%%%%%%%
% get ParentDirectory containing the data with a pop-up window:
% ParentDataDirectory = uigetdir(pwd,'Select the folder containing the participant data');
ParentDataDirectory = 'C:\Users\xkuo\Desktop\localBehavPredDataAG';

% search for all raw, 1sec, and output-csv files in ParentDirectory, incl. subfolders:
files.raw = dir([ParentDataDirectory,'\**\*RAW.csv']);
files.cps = dir([ParentDataDirectory,'\**\*1sec.csv']);
files.output = dir([ParentDataDirectory,'\**\*EventsSedentary.csv']);

% compare whether the raw and 1sec files match (number and name of files):
if numel(files.raw) ~= numel(files.cps) % if they do not match
    if numel(files.raw) > numel(files.cps)
        disp('There are more raw files than cps files')
    else
        disp('There are more cps files than raw files')
    end
    error(['Please make sure every raw file has a corresponding cps file in ',ParentDataDirectory, ' (including subfolders)'])
    
else % if they do, check whether they have the same name:
    filenames.raw = arrayfun(@(x) extractBefore(convertCharsToStrings(x.name),'RAW.'),files.raw); % get name without .csv
    filenames.cps = arrayfun(@(x) extractBefore(convertCharsToStrings(x.name),'1sec.'),files.cps); % get name without .csv
    if isequal(filenames.raw,filenames.cps) ~= 1
        error(['The name of raw and cps files do not match, check your data in ',ParentDataDirectory, ' (including subfolders)'])
    else
        disp(['Filenames successfully checked, the following ', num2str(numel(files.raw)), ' file(s) were detected: '])
        disp(filenames.raw)
    end
end
clear filenames


%% %%%%%%%%%%%%%%%%%%%% PREPARE DATA PROCESSING %%%%%%%%%%%%%%%%%%%%%%%%%%%
% Load the posture prediction algorithm:
try
    load('PosturePredictionAlgorithm','PosturePredictionAlgorithm')
catch
    error('PosturePredictionAlgorithm not found, make sure the algorithm is stored in the Matlab folder containing the functions')
end

% Load protocol data if UseProtocolFileToLimitTime set to Yes:
if strcmp(UseProtocolFileToLimitTime,'Yes')
    warning('off','MATLAB:table:ModifiedAndSavedVarnames')
    dirProtocol = dir([ParentDataDirectory,'\*Protocol*.xlsx']);
    if isempty(dirProtocol)
        error('Protocol not found, ensure there is an xlsx file in the selected directory containing the case sensitive word *Protocol*')
    elseif numel(dirProtocol) > 1
        error('More than 1 Protocol found, ensure there is only one xlsx file in the selected directory containing the case sensitive word *Protocol*. This error also occurs if you have to protocol file currently open, close it and re-try')
    end
    ProtocolTable = readtable([dirProtocol.folder,'\',dirProtocol.name]); % Read Protocol file
    varNames = ProtocolTable.Properties.VariableNames; % get variable names
    % replace NaN for Daytime
    ProtocolTable.(varNames{3})(isnan(ProtocolTable.(varNames{3}))) = 0; % start at 00:00 (input in days)
    ProtocolTable.(varNames{5})(isnan(ProtocolTable.(varNames{5}))) = 1; % stop at 24:00 (input in days)
    % get start and stop time since first day
    ProtocolTable.StartTimeSinceFirstDay = datenum(ProtocolTable.(varNames{2})) + ProtocolTable.(varNames{3}); % NaN if no day was specified
    ProtocolTable.StopTimeSinceFirstDay = datenum(ProtocolTable.(varNames{4})) + ProtocolTable.(varNames{5}); % NaN if no day was specified
    disp('Protocol loaded')
    warning('on','MATLAB:table:ModifiedAndSavedVarnames')
end


%% %%%%%%%%%%%%%%%%%% PROCESS FILES SUBJECTWISE %%%%%%%%%%%%%%%%%%%%%%%%%%%
for sub = 1:numel(files.raw)
    tic
    % Get Subject specific data
    foldernameSubject = files.raw(sub,1).folder;
    filenameSubjectRAW = files.raw(sub,1).name;
    filenameSubjectCPS = files.cps(sub,1).name;
    idxFirstSpace = find(files.raw(sub).name == ' ', 1);
    nameSubject = files.raw(sub).name(1:idxFirstSpace-1); % to match Protocol data
    
    % Check whether the subjects outputfile is already there
    if strcmp(ExcludeSubjectsHavingOutputCSV,'Yes') && isfile([foldernameSubject,'\',filenameSubjectCPS(1:end-8),'1minSedentaryBehaviour.csv'])
        disp(['Processing of subject ',num2str(sub),' of ',num2str(numel(files.raw)),' skipped, outputfile "',filenameSubjectCPS(1:end-8),'1minSedentaryBehaviour.csv" is already stored in ',foldernameSubject])
    else
        disp(['Processing of subject ',num2str(sub),' of ',num2str(numel(files.raw)),' running, file: ',files.raw(sub).name(1:end-7)])
        
        %% 1) Load raw File -> loadPALfileAG.m
        [dataRAW,TimeSinceFirstDayRAW] = loadRAWfileAG(foldernameSubject,filenameSubjectRAW);
        % Re-Arrange Axis order:
        dataRAW = dataRAW(:,AxisOrderNumb);
        % Get number of minutes available to predict
        NumbMinAvailable = floor(size(dataRAW,1)/30/60);
        
        
        %% 2) load cps file -> loadCPSfileAG.m (load and modify header information)
        [dataCPS,Header,TimeSinceFirstDayCPS] = loadCPSfileAG(foldernameSubject,filenameSubjectCPS);
        % Re-Arrange Axis order:
        dataCPS = dataCPS(:,AxisOrderNumb);
        % Add StopTime to create TimeVec
        TimeSinceFirstDayCPS(2) = TimeSinceFirstDayCPS(1) + (size(dataCPS,1)+1)./60./60./24;
        % Get number of minutes available to predict
        NumbMinAvailable(2) = floor(size(dataCPS,1)/60);
        
        
        %% 3) Prepare a TimeVector to catch the prediction (from CPS data) -> local
        if TimeSinceFirstDayRAW(1) == TimeSinceFirstDayCPS(1)
            if isequal(NumbMinAvailable(1),NumbMinAvailable(2))
                TimeVec = [TimeSinceFirstDayCPS(1):1/60/24:TimeSinceFirstDayCPS(2)-1/60/24]';
            else
                error('there are different number of minutes available from RAW and CPS')
            end
        else
            error('the recordings (RAW & CPS) do not start at the same time')
        end
        TimeVec(:,2) = 1; % 1 indicates valid time
        
        
        %% 4) Use Protocol to mark valid and non valid times in TimeVec -> limitDataToProtocolAG.m
        if strcmp(UseProtocolFileToLimitTime,'Yes')
            [TimeVec] = limitDataToProtocolAG(TimeVec, ProtocolTable, nameSubject);
        end
        
        
        %% 4) Calculate Features and Predict Posture -> getFeaturesAndPredictAG.m
        [MinuteBasedBehaviour] = getFeaturesAndPredictAG(dataRAW,PosturePredictionAlgorithm,TimeVec);
        
        
        %% 5) Add counts-per-minute -> addCountsPerMinuteAG.m
        MinuteBasedBehaviour = addCountsPerMinuteAG(dataCPS,MinuteBasedBehaviour,TimeVec);
        
        
        %% 6) Classify Behaviour -> local
        MinuteBasedBehaviour.BehaviourCode(1:size(MinuteBasedBehaviour,1)) = 99; % code for non-valid time
        MinuteBasedBehaviour.BehaviourCode(MinuteBasedBehaviour.Posture == 0 & MinuteBasedBehaviour.yAxisCounts < CutPoints(1)) = 0; % Sedentary Behaviour
        MinuteBasedBehaviour.BehaviourCode(MinuteBasedBehaviour.Posture == 0 & MinuteBasedBehaviour.yAxisCounts >= CutPoints(1)) = 1; % Active Sitting
        MinuteBasedBehaviour.BehaviourCode(MinuteBasedBehaviour.Posture == 1 & MinuteBasedBehaviour.yAxisCounts < CutPoints(2)) = 2; % Inactive Standing
        MinuteBasedBehaviour.BehaviourCode(MinuteBasedBehaviour.Posture == 1 & MinuteBasedBehaviour.yAxisCounts >= CutPoints(2)) = 3; % Active Standing
        MinuteBasedBehaviour.BehaviourCode(MinuteBasedBehaviour.Posture == 2) = 4; % Walking
        
        % add Time from TimeVec in Excel Format:
        MinuteBasedBehaviour.Time = m2xdate(TimeVec(:,1));
        MinuteBasedBehaviour.TimeString = datestr(TimeVec(:,1));
        
        % erase non-valid minutes if desired
        if strcmp(ExcludeNonValidTimeInOutput,'Yes')
            MinuteBasedBehaviour(MinuteBasedBehaviour.BehaviourCode==99,:) = [];
        end
        
        %% 7) Save OutputFile
        % Rearrange MinuteBasedBehaviour
        MinuteBasedBehaviour = MinuteBasedBehaviour(:,[4 5 1 2 3]);
        % add columns to header to combine with MinuteBasedBehaviour
        Header = [table2cell(Header) cell(size(Header,1),size(MinuteBasedBehaviour,2)-1)];
        
        % combine Header and MinuteBasedBehaviour:
        OutputCell = [Header;MinuteBasedBehaviour.Properties.VariableNames;table2cell(MinuteBasedBehaviour)];
        % save to csv:
        writecell(OutputCell,[foldernameSubject,'\',filenameSubjectCPS(1:end-8),'1minSedentaryBehaviour.csv'])
        disp(['  -> csv file of the subject saved to file "',filenameSubjectCPS(1:end-8),'1minSedentaryBehaviour.csv" in folder ',foldernameSubject, ' (runBehaviourPredictionActiGraph.m)'])
        
        if ~strcmp(SupressSummaryFile,'Yes')
            % Save data for summary file
            OutputCellSubjects{sub,1} = OutputCell; % ... data
            OutputCellSubjects{sub,2} = nameSubject; % ... and subject name until first space
        end
    end
    toc
end

if ~strcmp(SupressSummaryFile,'Yes') && exist('OutputCellSubjects')
    % Write data of all subjects in one xls, spreadsheet by spreadsheet
    % remove empty lines in OutputCellSubjects
    idx = (cellfun(@isempty,OutputCellSubjects(:,1)));
    OutputCellSubjects(idx,:) = [];
    % append time to prevent overwriting previous rounds
    rightnow = datestr(now, 'yyyy-mm-dd-HH-MM');
    warning('off','matlab:xlswrite:AddSheet') % suppress warning that spreadsheet was added
    for sub = 1:size(OutputCellSubjects,1)
        writecell(OutputCellSubjects{sub,1},[ParentDataDirectory,'\','Summarised Behaviour Prediction_',rightnow,'.xls'],'Sheet',OutputCellSubjects{sub,2})
    end
    warning('on','matlab:xlswrite:AddSheet') % stop suppressing warning
    disp('Behaviour prediction completed')
    disp(['---> csv file of all subjects saved to file "Summarised Behaviour Prediction.xls" in folder ',ParentDataDirectory])
    disp('Good luck with further processing')
else
    disp('Behaviour prediction completed')
    disp('no "Summarised Behaviour Prediction.xls" file generated')
    disp('Good luck with further processing')
end



return