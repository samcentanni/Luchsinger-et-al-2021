function [Delta470] = DeltaF(Ch470,Ch405,varargin)
% Smooth and process 490 channel and control channel data for fiber
% photometry. 

%Inputs:
% 1--Ch490-GCamp Channel
% 2--Ch405-isosbestic control channel
% 3--Start time- Set a specific sample to start at
% 4--End time-specify a specific ending sample


if length(varargin)==1
    Ch470=Ch470(1,varargin{1}:end)'; %GCaMP
    Ch405=Ch405(1,varargin{1}:end)'; %Isosbestic Control
elseif length(varargin)==2
    Ch470=Ch470(1,varargin{1}:varargin{2})'; %GCaMP
    Ch405=Ch405(1,varargin{1}:varargin{2})'; %Isosbestic Control
end

F470=smooth(Ch470,0.0004,'lowess'); 
F405=smooth(Ch405,0.0004,'lowess');

%F490=smooth(Ch490,0.002,'lowess'); 
%F405=smooth(Ch405,0.002,'lowess');

%%Moving Average instead of Lowess.
 %F490=smooth(Ch490,299,'moving'); 
 %F405=smooth(Ch405,299,'moving');

subplot (1,2,1);plot(Ch470);hold on;plot(Ch405);
%subplot (1,3,2);plot(Z490);hold on;plot(Z405);
subplot (1,2,2);plot(F470);hold on;plot(F405);
hold off
FastPrint('RawAndSmoothedChannels');

bls=polyfit(F405(1:end),F470(1:end),1);
%scatter(F405(10:end-10),F490(10:end-10))
Y_Fit=bls(1).*F405+bls(2);
%figure
Delta470=(F470(:)-Y_Fit(:))./Y_Fit(:);

figure
plot(Delta470.*100)
ylabel('% \Delta F/F')
xlabel('Time (Seconds)')
title('\Delta F/F for Recording ')
FastPrint('WholeSessionTrace');


end

