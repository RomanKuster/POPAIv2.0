function [EpisodesToPredict,episodeTable] = extractEpisodesToPredictAP(episodeTable,ExcludeExtralongEpisodesInHours)
% identify sitting episodes longer than 60 seconds and split into
% minute-by-minute data in episodeTable, get prediction start of each
% episode with corresponding index in episodeTable. Episodes smaller than
% 60 seconds are predicted so they end at the end of the initial episodes
% longer than 60 seconds, or balanced around single episodes (equally
% overlapping start and stop).


%% Predefinitions
if ExcludeExtralongEpisodesInHours == 0
    excludeEpisodesLargerAs = 2400; % 100 days in hours
else 
    excludeEpisodesLargerAs = ExcludeExtralongEpisodesInHours;
end


%% Identify Sitting, and split to minutedata
% Split all Sit Episodes longer than 60 seconds and shorter than ExcludeExtralongEpisodesInHours. 
idxSitToSplit = find(episodeTable.BehaviourCode==99 & episodeTable.Duration>60 & episodeTable.Duration < excludeEpisodesLargerAs*60*60);
for row = length(idxSitToSplit):-1:1
    TimeToMove = episodeTable.Duration(idxSitToSplit(row)) -60; % ... move the time
    counter = 0;
    while TimeToMove > 0 % split data as long as TimeToMove is positive
        % copy the row
        episodeTable = [episodeTable(1:idxSitToSplit(row)+counter,:); episodeTable(idxSitToSplit(row)+counter:end,:)];
        % adjust Duration
        episodeTable.Duration(idxSitToSplit(row)+counter) = 60; % limit bout to 60 seconds...
        episodeTable.Duration(idxSitToSplit(row)+counter+1) = TimeToMove; % ...and transfer remaining time
        % adjust start time
        episodeTable.TimeSinceFirstDay(idxSitToSplit(row)+counter+1) = episodeTable.TimeSinceFirstDay(idxSitToSplit(row)+counter+1) + 60/60/60/24;
        % remove minute from TimeToMove
        TimeToMove = TimeToMove - 60;
        counter = counter + 1;
    end
end


%% Identify Episodes to Predict
% all episodes classified as sitting by the activPal shorter than maximum episode duration
EpisodesToPredict = [episodeTable(episodeTable.BehaviourCode==99 & episodeTable.Duration < excludeEpisodesLargerAs*60*60,1:2) array2table(find(episodeTable.BehaviourCode==99 & episodeTable.Duration < excludeEpisodesLargerAs*60*60),'VariableNames',{'idxepisodeTable'})];

% for episode lasting 60 seconds:
ind = find(EpisodesToPredict.Duration == 60);
EpisodesToPredict.PredictionStart(ind) = EpisodesToPredict.TimeSinceFirstDay(ind); % use TimeSinceFirstDay to predict the Minute

% for episodes shorter than 60 seconds, following non-sitting:
ind = find(EpisodesToPredict.Duration < 60 & [1; diff(EpisodesToPredict.idxepisodeTable)]~=1);
EpisodesToPredict.PredictionStart(ind) = (EpisodesToPredict.TimeSinceFirstDay(ind) + ((EpisodesToPredict.Duration(ind)/2)/60/60/24) - 30/60/60/24); % start 30 sec before middle of Episode

% for episodes shorter than 60 seconds, following sitting:
ind = find(EpisodesToPredict.Duration < 60 & [1; diff(EpisodesToPredict.idxepisodeTable)]==1);
EpisodesToPredict.PredictionStart(ind) = EpisodesToPredict.TimeSinceFirstDay(ind) - ((60-EpisodesToPredict.Duration(ind))/60/60/24); % start 60-duration seconds before start time to match end

disp('  -> episodes to predict extracted...         (extractEpisodesToPredictAP.m)')

if ExcludeExtralongEpisodesInHours ~= 0
   disp(['     -> Sitting episodes larger than ',num2str(ExcludeExtralongEpisodesInHours),' hours were excluded from prediction']) 
end
return