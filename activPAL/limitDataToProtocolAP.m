function episodeTable = limitDataToProtocolAP(episodeTable, ProtocolTable, subfoldernameSubject)
% limit data to protocol time

% find subfolder name in Protocol
idx = find(strcmp(table2array(ProtocolTable(:,1)),subfoldernameSubject));
% if the subject appears only once
if numel(idx) == 1
    % get data from Protocol
    StartTime = ProtocolTable.StartTimeSinceFirstDay(idx);
    StopTime = ProtocolTable.StopTimeSinceFirstDay(idx);
    if StopTime <= StartTime
        disp('Protocol stop occurs before start, protocol ignored')
    else
        % Limit episodeTable to Protocol data Start
        if ~isnan(StartTime)
            if StartTime > episodeTable.TimeSinceFirstDay(1)
                [~,~,ind] = histcounts(StartTime,episodeTable.TimeSinceFirstDay); % ind contains start time
                if ind > 1
                    episodeTable(1:ind,:) = []; % remove all lines before ind
                end
                episodeTable = [episodeTable(1,:);episodeTable]; % copy first line
                episodeTable.TimeSinceFirstDay(2) = StartTime; % adjust starttime...
                episodeTable.Duration(2) = episodeTable.Duration(1) - (episodeTable.TimeSinceFirstDay(2)-episodeTable.TimeSinceFirstDay(1))*24*60*60; %... duration...
                episodeTable.ActivityScore(2) = episodeTable.ActivityScore(1) / episodeTable.Duration(1) * episodeTable.Duration(2); % ... and Activity Score.
                episodeTable(1,:) = []; % erase first line
                disp('Start time from protocol used to limit the recording')
            else
                disp(['Start time from protocol ignored (before recording start)'])
            end
        else
            disp(['Start time from protocol ignored (not a number)'])
        end
        
        % Limit episodeTable to Protocol data Stop
        if ~isnan(StopTime)
            if StopTime < episodeTable.TimeSinceFirstDay(end) + episodeTable.Duration(end)/60/60/24
                [~,~,ind] = histcounts(StopTime,episodeTable.TimeSinceFirstDay); % ind contains stop time
                if ind == 0; ind = size(episodeTable,1); end % if last ind contains stop time, histcounts results in ind = 0
                if ind < size(episodeTable,1)
                    episodeTable(ind+1:end,:) = []; % remove all lines after ind
                end
                episodeTable = [episodeTable; episodeTable(end,:)]; % copy last line
                episodeTable.TimeSinceFirstDay(end) = StopTime; % adjust starttime (of last episode)...
                episodeTable.Duration(end-1) = (episodeTable.TimeSinceFirstDay(end)-episodeTable.TimeSinceFirstDay(end-1))*24*60*60; %... duration...
                episodeTable.ActivityScore(end-1) = episodeTable.ActivityScore(end) / episodeTable.Duration(end) * episodeTable.Duration(end-1); % ... and Activity Score.
                episodeTable(end,:) = []; % erase last line
                disp('Stop time from protocol used to limit the recording')
            else
                disp(['Stop time from protocol ignored (after recording stop)'])
            end
        else
            disp(['Stop time from protocol ignored (not a number)'])
        end
    end
    disp('  -> protocol data used to limit recording... (limitDataToProtocolAP.m)')
% if the subject does not appear
elseif isempty(idx)
    disp('  -> PROTOCOL DATA IGNORED (subject not found)...             (limitDataToProtocolAP.m)')
% if the subject appears several time
else
    disp('  -> PROTOCOL DATA IGNORED (subject appears several time)...  (limitDataToProtocolAP.m)')
end
return