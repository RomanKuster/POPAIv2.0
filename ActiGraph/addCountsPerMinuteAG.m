function MinuteBasedBehaviour = addCountsPerMinuteAG(dataCPS,MinuteBasedBehaviour,TimeVec)
% function to add the counts-per-minute from the counts-per-second file for
% the time marked in TimeVec(:,2) as valid, else a code of -99 is used

freq = 1; % second-based input data
idx = 1:(freq*60):size(dataCPS,1); % index of each minute 
if size(dataCPS,1) == idx(end)+59
    idx(end+1) = size(dataCPS,1)+1;
end

MinuteBasedBehaviour.yAxisCounts = zeros(numel(idx)-1,1); % initialise for speed

for i = 1:numel(idx)-1 %(last minute is not present in full length)
    if TimeVec(i,2) == 1 % if minute is valid
        MinuteBasedBehaviour.yAxisCounts(i) = sum(dataCPS(idx(i):idx(i+1)-1,2));
    else
        MinuteBasedBehaviour.yAxisCounts(i) = -99;
    end
end

disp('  -> counts-per-minute added...       (addCountsPerMinuteAG.m)')

return
