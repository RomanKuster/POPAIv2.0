function [dataRAW,TimeSinceFirstDayRAW] = loadRAWfileAG(foldernameSubject,filenameSubjectRAW)
% function to extract the acceleration data for raw ActiGraph signal in 
% format csv that was created with ActiLife

%% Load ActiGraph StartTime from File Header
delimiter = ','; endRow = 11; formatSpec = '%s%*s%*s%*s%[^\n\r]';
fileID = fopen([foldernameSubject,'\',filenameSubjectRAW],'r');
dataArray = textscan(fileID, formatSpec, endRow, 'Delimiter', delimiter, 'TextType', 'string', 'ReturnOnError', false, 'EndOfLine', '\r\n');
fclose(fileID);
MetadataFile = table(dataArray{1:end-1}, 'VariableNames', {'Timestamp'});

% Get StartTimeSinceFirstDay:
startDate = MetadataFile{4,1};
startDate = datenum(startDate{1,1}(12:end),'dd.mmm.yyyy');
startTime = MetadataFile{3,1};
[~,~,~,H,M,S] = datevec(startTime{1,1}(12:end)); % convert starttime to hours, minutes and seconds...
TimeSinceFirstDayRAW = startDate + (H + M/60 + S/60/60)/24; % ... and combine with start day

% Get first datacolumn information ('Timestamp', 'Accelerometer X', date or acceleration signal)
FirstColumnData = MetadataFile{11,1}{1,1};


%% Load Acceleration Data:
% check first row entry
if strcmp(FirstColumnData,'Accelerometer X') 
    skipcolumn = 0;   % don't skip first column
    skiprow = 11;     % header in first 11 rows
elseif strcmp(FirstColumnData,'Timestamp')
    skipcolumn = 1;   % skip first column (Timestamp)
    skiprow = 11;     % header in first 11 rows
else % FirstColumnData contains data (Column Header skipped in ActiLife)
    if isnan(str2double(FirstColumnData)) % first column contains timestamp
        skipcolumn = 1; % skip timestamp data
        skiprow = 10;   % header in first 10 rows
    else                                  % first column contains data
        skipcolumn = 0; % don't skip first column
        skiprow = 10;   % header in first 10 rows
    end
end

dataRAW = dlmread([foldernameSubject,'\',filenameSubjectRAW],',',skiprow, skipcolumn); %skipp the first rows (metadata) and the first column (timestamp)
disp('  -> Acceleration data loaded...      (loadRAWfileAG.m)')

return