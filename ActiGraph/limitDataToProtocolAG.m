function [TimeVec] = limitDataToProtocolAG(TimeVec, ProtocolTable, nameSubject)
% function adds a 1 in TimeVec(:,2) if time is included in the protocol
% (and thus considered valid). Match to protocol with subject name.

% find nameSubject in Protocol
idx = find(strcmp(table2array(ProtocolTable(:,1)),nameSubject));
if numel(idx) == 0
    disp('  -> PROTOCOL DATA IGNORED (subject not found)...             (limitDataToProtocolAG.m)')
else
    % Get start and stop time of valid time, and sort by start time
    StartStopTime = [ProtocolTable.StartTimeSinceFirstDay(idx) ProtocolTable.StopTimeSinceFirstDay(idx)];
    StartStopTime = sort(StartStopTime,1);
    % Consider all indices as non-valid:
    TimeVec(:,2) = 0;
    % find corresponding indices of valid time in TimeVec
    for row = 1:size(StartStopTime,1)
        for col = 1:size(StartStopTime,2)
            [val(row,col),ind(row,col)] = min(abs(TimeVec(:,1) - StartStopTime(row,col)));
            if val(row,col) > 1/60/60/24 % 1 second
                error('difference larger than 1 second')
            end
        end
    end
    
    % mark valid time in TimeVec (include start, exclude stoptime)
    for row = 1:size(StartStopTime,1)
        TimeVec(ind(row,1):ind(row,2)-1,2) = 1;
    end
    disp('  -> data limited to protocol...      (limitDataToProtocolAG.m)')
end

return