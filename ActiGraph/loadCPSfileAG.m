function [dataCPS,Header,TimeSinceFirstDayCPS] = loadCPSfileAG(foldernameSubject,filenameSubjectCPS)
% function to extract the counts-per-second data for ActiGraph in format 
% csv that was created with ActiLife. Header information is load and 
% modified for the output file of the parent function.

%% Load Header
delimiter = ','; endRow = 11; formatSpec = '%s%*s%*s%*s%[^\n\r]';
fileID = fopen([foldernameSubject,'\',filenameSubjectCPS],'r');
dataArray = textscan(fileID, formatSpec, endRow, 'Delimiter', delimiter, 'TextType', 'string', 'ReturnOnError', false, 'EndOfLine', '\r\n');
fclose(fileID);
MetadataFile = table(dataArray{1:end-1}, 'VariableNames', {'Timestamp'});

% Get StartTimeSinceFirstDay:
startDate = MetadataFile{4,1};
startDate = datenum(startDate{1,1}(12:end),'dd.mmm.yyyy');
startTime = MetadataFile{3,1};
[~,~,~,H,M,S] = datevec(startTime{1,1}(12:end)); % convert starttime to hours, minutes and seconds...
TimeSinceFirstDayCPS = startDate + (H + M/60 + S/60/60)/24; % ... and combine with start day


%% Create a new Header
% add posture prediction information to Metadata, before "ActiGraph"
ind = strfind(MetadataFile{1,1}{1,1},'ActiGraph');
MetadataFile{1,1}{1,1} = ['Posture Prediction File Created By Kuster et al. 2021 for ', MetadataFile{1,1}{1,1}(ind:end)];
% Change EpochPeriod to 1 Minute
ind = strfind(MetadataFile{5,1}{1,1},':');
MetadataFile{5,1}{1,1}(ind(end)-1) = num2str(1);
MetadataFile{5,1}{1,1}(ind(end)+2) = num2str(0);
% Add Prediction Time and Date to Download Time and Date
MetadataFile{6,1}{1,1} = [MetadataFile{6,1}{1,1}, '; Processing Time ', datestr(now,'HH:MM:SS') ];
MetadataFile{7,1}{1,1} = [MetadataFile{7,1}{1,1}, '; Processing Date ', datestr(now,'dd.mm.yyyy') ];
% Data Header with Code explanation
MetadataFile{11,1}{1,1} = 'Posture Code: Sitting (0), Standing (1), Stepping (2), non-valid time (99); yAxisCounts: counts per minute, with non-valid time (-99); Behaviour Code: Sedentary Behaviour (0), Active Sitting (1), Inactive Standing (2), Active Standing (3), Locomotion (4), non-valid time (99)';

% Write Metadata to Header
Header(1:11,1) = table(MetadataFile{1:11,1});


%% Load AG cps Data
%... load the file...
dataCPS = dlmread([foldernameSubject,'\',filenameSubjectCPS],',',11, 0); % skipp the first 11 rows (metadata) and the first column (timestamp)
% remove lines not needed:
dataCPS(:,5:end) = [];
disp('  -> counts-per-second data loaded... (loadCPSfileAG.m)')

return