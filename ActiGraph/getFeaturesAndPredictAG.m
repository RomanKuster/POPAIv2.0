function [MinuteBasedBehaviour] = getFeaturesAndPredictAG(dataRAW,PosturePredictionAlgorithm,TimeVec)
% function to predict the posture in a minute-by-minute resolution using 
% the PosturePredictionAlgorithm applied on ActiGraph rawdata. Prediction
% limited to TimeVec(:,2) == 1, else a code 99 is used.

%% Predefinitions
% Sampling Frequency
freq = 30;
% Define Filter properties:
CutoffFreq = 0.5;
[b,a] = butter(2,CutoffFreq / (freq/2)); clear CutoffFreq


%% Prepare Acceleration Signal for Feature Calculation
% Add Vector Magnitude
dataRAW(:,4) = sqrt(dataRAW(:,1).^2 + dataRAW(:,2).^2 + dataRAW(:,3).^2);

% Add Filtered Data for sensor z-axis
FramesToAdd = (freq * 10); % ...add inverted first 10 seconds in beginning (allows filter to settle before first minute to predict)
dataRAW = vertcat(flipud(dataRAW(1:FramesToAdd,:)),dataRAW);
dataRAW(:,5) = filter(b,a, dataRAW(:,3));


%% Calculate FeatureTable and Predict Posture
% Get indices for each minute
idx = (freq * 10)+1:(freq*60):length(dataRAW(1:end,1)); % last minute is not present in full length, use idx(i+1)-1 as stop

% preallocate feature array
features = zeros(length(idx)-1,14);

% calculate feature array:
for i = 1:length(idx)-1
    
    % calculate Features only for valid time
    if TimeVec(i,2) == 1
        
        InputDataMin = dataRAW(idx(i):idx(i+1)-1,:);
        % Feature 01: Third Moment of the Vector Magnitude
        features(i,1) = moment( InputDataMin(isnan(  InputDataMin(:,4)  )~=1,4)  ,3);
        % Feature 02: Minimum of the filtered z-axis
        features(i,2) = min(InputDataMin(:,5));
        % Feature 03: DynamicTimeWarping of x to y axis
        features(i,3) = dtw(InputDataMin(:,1),InputDataMin(:,2));
        % Feature 04: Kurtosis of the Vector Magnitude
        features(i,4) = kurtosis(InputDataMin(:,4));
        % Feature 05: Mean of the z-axis
        features(i,5) = nanmean(InputDataMin(:,3));
        % Feature 06: Power between 0.3Hz to 3Hz of the Vector Magnitude
        features(i,6) = bandpower(InputDataMin(:,4),freq,[0.3 3]);
        % Feature 07: Power between 3Hz to 15Hz of the z-axis
        features(i,7) = bandpower(InputDataMin(:,3),freq,[3 15]);
        % Feature 08: Power between 3Hz to 15Hz of the x-axis
        features(i,8) = bandpower(InputDataMin(:,1),freq,[3 15]);
        % Feature 09: Total Power (between 0Hz to 15Hz) of the y-axis
        features(i,9) = bandpower(InputDataMin(:,2),freq,[0 15]);
        % Feature 10: Number of prominent peaks of the x axis:
        features(i,10) = length(findpeaks( InputDataMin(:,1) ,'Threshold',1e-6,'MinPeakProminence', (max(InputDataMin(:,1))-min(InputDataMin(:,1)))/4));
        % Feature 11: Power at mean frequency ±0.1 Hz
        MeanFreq_Zfilt = meanfreq(InputDataMin(:,5),freq);
        if isnan(MeanFreq_Zfilt)
            features(i,11) = 0; % replace NaN with 0
        else
            MeanFreqRange_Zfilt = [MeanFreq_Zfilt-0.1 MeanFreq_Zfilt+0.1];
            % Limit frequency range to recording:
            if MeanFreqRange_Zfilt(1) < 0; MeanFreqRange_Zfilt(2) = MeanFreqRange_Zfilt(2)+abs(MeanFreqRange_Zfilt(1)); MeanFreqRange_Zfilt(1) = 0;  end % keep the range constant towards the end of the freq spectrum
            if MeanFreqRange_Zfilt(2) > 15; MeanFreqRange_Zfilt(1) = MeanFreqRange_Zfilt(1) - (MeanFreqRange_Zfilt(2)-15); MeanFreqRange_Zfilt(2) = 15;end
            features(i,11) = bandpower(InputDataMin(:,5),freq,MeanFreqRange_Zfilt); clear MeanFreq_Zfilt MeanFreqRange_Zfilt
        end
        % Feature 12: Power between 0.3Hz to 3Hz of the y-axis
        features(i,12) = bandpower(InputDataMin(:,2),freq,[0.3 3]);
        % Feature 13: Power between 0.3Hz to 3Hz of the x-axis
        features(i,13) = bandpower(InputDataMin(:,1),freq,[0.3 3]);
        % Feature 14: Power between 3Hz to 15Hz of the Vector Magnitude
        features(i,14) = bandpower(InputDataMin(:,4),freq,[3 15]);
        
    else
        features(i,1:14) = 99;
    end
    
end

% replace NaN kurtosis (Feature 4) with 0
features(isnan(features(:,4)),4) = 0;


%% Predict Posture using the trained PosturePredictionModel
MinuteBasedBehaviour = table(predict(PosturePredictionAlgorithm,features),'VariableNames',{'Posture'});
% erase prediction for non-valid minutes
MinuteBasedBehaviour.Posture(TimeVec(:,2) == 0) = 99;
disp('  -> Posture Predicted...             (getFeaturesAndPredictAG.m)')

return
