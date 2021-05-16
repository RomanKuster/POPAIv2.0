function [rawData] = loadDATXfileAP(foldernameSubject,filenameSubjectDATX)
% Load .datx RawData file using github function published by R. Broadley 
% if possible (else read the csv file that needs first to be generated 
% according to the instructions in the Command Window, instructions given 
% for activPAL3 software, check manual if using a different software).
% If file can't be load, the output file rawData is an empty table 
% -> return after csv created to process the subject again


%% Load Raw Data

try % load datx with github function...
    rawData = activpal_utils.load_datx([foldernameSubject,'\',filenameSubjectDATX]); % https://github.com/R-Broadley/activpal_utils-matlab/wiki/Getting-Started
    rawData.signals.dateTime = datenum(rawData.signals.dateTime);
    rawData = rawData.signals;
    rawData.Properties.VariableNames = {'TimeSinceFirstDay';'x';'y';'z'};
    
catch %... or csv if it does not work
    disp('loadDATXfile.m error handling: datx file is not readable, load csv file instead!')
    
    % check if csv file is there:
    filepathCSV = [foldernameSubject,'\',filenameSubjectDATX(1:end-5),'.csv'];
    if isfile(filepathCSV)==0
        disp('------------------------------------------------------------')
        disp('Generate the csv file containing the rawdata with activPal Software')
        disp('Instructions: open activPal3 Software -> File -> Open -> "Select the .datx file" -> Open -> Go to File -> Advanced -> Save acceleration data')
        disp('this generates a raw file in csv format, named the same as the .datx file')
        disp('In the meantime, MATLAB continues to process the reamining subject')
        disp('Return with the given Subject once the csv file was generated and set')
        disp('ExcludeSubjectsHavingOutputCSV to Yes to limit processing to subjects without outputfile')
        disp(['Filename "',filenameSubjectDATX,'" in folder: ',foldernameSubject])
        disp('------------------------------------------------------------')
        rawData = array2table(zeros(0,0));
    else
    rawData = dlmread(filepathCSV,',',5, 0); % read excelfile (time and 3d accel)
    rawData(:,1) = x2mdate(rawData(:,1));
    rawData(:,2:4) = (rawData(:,2:4) - 127) ./ 63; % convert bits into acceleration (as a multiply of 1 g (gravity))
    rawData = array2table(rawData,'VariableNames',{'TimeSinceFirstDay';'x';'y';'z'});
    end
end

disp('  -> raw signal loaded...                     (loadDATXfileAP.m)')

return