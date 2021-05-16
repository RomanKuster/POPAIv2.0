function [EpisodesToPredict] = getFeaturesAndPredictAP(rawData,EpisodesToPredict,ActivityPredictionAlgorithm)
% Function to calculate the selected features from the raw signal and 
% predict the behaviour with the trained algorithm. Prediction added to the
% EpisodesToPredict Table. 

%% Predefinitions
freq = 20;
minute = freq*60;
FramesToAdd = int16(freq * 10);
CutoffFreq = 0.5;
[b,a] = butter(2,CutoffFreq/(freq/2)); clear CutoffFreq


%% Prepare RawData
% change rawData to an array for ease of access:
rawData = table2array(rawData);

% adjust rawData length (START)
[~,ind] = min(abs(rawData(:,1) - EpisodesToPredict.PredictionStart(1))); % find indices of first Episode to predict in rawdata
if ind > 10*freq % if there is more than 10 seconds of data before...
    ind = ind-10*freq; % ...limit to 10 seconds before
    rawData(1:ind-2,:) = []; % (-2 to make sure closest match is earliest ind = 1)
elseif ind < 10*freq % if there is less than 10 seconds of data before...
    FramesToAdd = (freq * 10); % ...add inverted first 10 seconds in beginning (allows filter to settle before first episode to predict)
    rawData = vertcat(flipud(rawData(1:FramesToAdd,:)),rawData);
    tempTime = [rawData(FramesToAdd+1,1)-(FramesToAdd/freq/60/60/24): 1/freq/60/60/24 :rawData(FramesToAdd+1,1)]; % adjust time...
    rawData(1:FramesToAdd,1) = tempTime(1:end-1); % ... to ensure ind finds the right placement
end

% Adjust rawData length (END)
[~,ind] = min(abs(rawData(:,1) - (EpisodesToPredict.PredictionStart(end)+60/60/60/24 ) )); % add 1 minute
if size(rawData,1) > ind+2
    rawData(ind+2,:) = [];
end

% preallocate for speed
rawData(:,5:10) = 0;
% add VM
rawData(:,5) = sqrt(rawData(:,2).^2+rawData(:,3).^2+rawData(:,4).^2);
% Filter:
rawData(:,6:8) = filter(b,a, rawData(:,2:4)); % only X, Y, and Z
% add elevation angle X and Y
[~,rawData(:,9),~] = cart2sph(rawData(:,7),rawData(:,8),rawData(:,6));  % 9: X to Y-Z plane
[~,rawData(:,10),~] = cart2sph(rawData(:,8),rawData(:,6),rawData(:,7)); %10: Y to X-Z plane
% Column Names of rawData are {'Time';'X';'Y';'Z';'VM';'X_filt';'Y_filt';'Z_filt';'X_Angle';'Y_Angle'}; % 10 dimensions (1:10)


%% Find the indices of the StartTime
% finds the indices just before Starttime
[~,~,ind] = histcounts(EpisodesToPredict.PredictionStart,rawData(:,1));
% adjust starttime ind to make sure the first ten seconds are not taken
if ind(1) <= FramesToAdd; ind(1) = FramesToAdd+1; end

% adjust endtime ind to make sure rawData is available
if ind(end)+minute-1 > length(rawData(:,1)) % minute exceeds rawData length (reason: single sitting is predicted equally overlapping start and stop)
    if abs(60 - ((EpisodesToPredict.TimeSinceFirstDay(end) - EpisodesToPredict.PredictionStart(end))*24*60*60 *2 + EpisodesToPredict.Duration(end))) < 1
        ind(end) = length(rawData(:,1))-minute+1;
    else
        error('time in EpisodesToPredict does not match rawsignal in getFeaturesAndPredict, please report error to roman.kuster@alumni.ethz.ch')
    end
end


%% Feature Calculation
% FeatureNames = {'min_X_Angle';'range_X';'range_Y';'range_X_Angle';...
%     'sumSignalChange_X';'sumSignalChange_VM';'sumSignalChange_X_filt';'sumSignalChange_Y_Angle';...
%     'BandPowerMed_X';'BandPowerMed_Y';'Lag1Autocor_X';'Lag1Autocor_Z_filt'};

% preallocate for speed
features(1:size(ind,1),12) = 0;

for i = 1:length(ind)
    % Minimum of X_angle:
    features(i,1) = min(rawData(ind(i):ind(i)+minute-1,[9]));
    % Range of X, Y, X_Angle:
    features(i,2:4) = max(rawData(ind(i):ind(i)+minute-1,[2 3 9])) - min(rawData(ind(i):ind(i)+minute-1,[2 3 9]));
    % sum signal Change of X, VM, X_filt, Y_Angle:
    features(i,5:8) = sum(abs(diff(rawData(ind(i):ind(i)+minute-1,[2 5 6 10]))));
    % BandPowerMed X and Y:
    features(i,9:10) = bandpower(rawData(ind(i):ind(i)+minute-1,[2 3]),freq,[0.3 3]);
    % Lag-1 autocor of X:
    lag_cor =  autocorr(rawData(ind(i):ind(i)+minute-1,[2]),int16(freq));
    if isnan(lag_cor(2)) % in case there is no signal variation at all!
        features(i,11) = 0;
    else
        features(i,11) = lag_cor(2);
    end
    % Lag-1 autocor of Z_filt
    lag_cor =  autocorr(rawData(ind(i):ind(i)+minute-1,[8]),int16(freq));
    if isnan(lag_cor(2)) % in case there is no signal variation at all!
        features(i,12) = 0;
    else
        features(i,12) = lag_cor(2);
    end
end


%% Behaviour Prediction
% rearrange feature array to match TrainedPredictionModel.PredictorNames
features = features(:,[3 2 5 7 1 6 8 4 9 11 10 12]);
EpisodesToPredict.Prediction = predict(ActivityPredictionAlgorithm,features);
disp('  -> behaviour predicted...                   (getFeaturesAndPredictAP.m)')

return