% Fiber photometry data processing
%
%%MODIFIED Code by Sam Centanni- see source below 
% Contact samuel.centanni@vanderbilt.edu

%  please cite our Jove paper: 
%   Martianova, E., Aronson, S., Proulx, C.D. Multi-Fiber Photometry to  
%   Record Neural Activity in Freely Moving Animal. J. Vis. Exp. 
%   (152), e60278, doi:10.3791/60278 (2019).

% Run section by section (Ctrl+Enter)

%% Your data

clear all; close all; %Clear all variables and close all figures
BlockDir=uigetdir('Select TDT Photometry Block'); %Get folder name
cd(BlockDir); %Change directory to photometry folder
[Tank,Block,~]=fileparts(cd); %List full directory for Tank and Block
data=TDTbin2mat(BlockDir); %Use TDT2Mat to extract data.

%% SYNAPSE- Extract Relevant Data from Data file
%Create Variables for each Photometry Channel and timestamps
Ch470=data.streams.x470A.data; %GCaMP
Ch405=data.streams.x405A.data; %Isosbestic Control
Ts = ((1:numel(data.streams.x470A.data(1,:))) / data.streams.x470A.fs)'; % Get Ts for samples based on Fs
StartTime=3000; %Set the starting sample(recommend eliminating a few seconds for photoreceiver/LED rise time).
EndTime=length(Ch470); %Set the ending sample (again, eliminate some).
Fs=data.streams.x470A.fs; %Variable for Fs
Ts=Ts(StartTime:EndTime); % eliminate timestamps before starting sample and after ending.
Ch470=Ch470(StartTime:EndTime);
Ch405=Ch405(StartTime:EndTime);
Ch405=double(Ch405);
Ch470=double(Ch470);

% Change the next two lines depending on your data frame
raw_reference = Ch405; 
raw_signal = Ch470;

% Plot raw data
figure
subplot(2,1,1)
plot(raw_reference,'m')
subplot(2,1,2)
plot(raw_signal,'b')

%% Use function get_zdFF.m to analyze data
zdFF = get_zdFF(raw_reference,raw_signal);

% Plot z-score dF/F
figure
plot(zdFF,'k')

%% Analysis step by step
% Smooth data
smooth_win = 10;
smooth_reference = movmean(raw_reference,smooth_win);
smooth_signal = movmean(raw_signal,smooth_win);

% Plot smoothed signals
figure
subplot(2,1,1)
plot(smooth_reference,'m')
subplot(2,1,2)
plot(smooth_signal,'b')

%% Remove slope using airPLS algorithm (airPLS.m)
lambda = 5e9;
order = 2;
wep = 0.1;
p = 0.5;
itermax = 50;
[reference,base_r]= airPLS(smooth_reference,lambda,order,wep,p,itermax);
[signal,base_s]= airPLS(smooth_signal,lambda,order,wep,p,itermax);

% Plot slopes
figure
subplot(2,1,1)
plot(smooth_reference,'m')
hold on
plot(base_r,'k')
hold off
subplot(2,1,2)
plot(smooth_signal,'b')
hold on
plot(base_s,'k')
hold off

%% Remove the begining of recordings
remove = 200;
reference = reference(remove:end);
signal = signal(remove:end);

% Plot signals
figure
subplot(2,1,1)
plot(reference,'m')
subplot(2,1,2)
plot(signal,'b')

%% Standardize signals
z_reference = (reference - median(reference)) / std(reference);
z_signal = (signal - median(signal)) / std(signal);

% Plot signals
figure
subplot(2,1,1)
plot(z_reference,'m')
subplot(2,1,2)
plot(z_signal,'b')

%% Fit reference signal to calcium signal 
% using non negative robust linear regression
fitdata = fit(z_reference',z_signal',fittype('poly1'));

% Plot fit
figure
hold on
plot(z_reference,z_signal,'k.')
plot(fitdata,'b')
hold off
savefig('fitdata.fig')
%% Align reference to signal
z_reference = fitdata(z_reference)';

% Plot aligned signals
figure
plot(z_reference,'m')
hold on
plot(z_signal,'b')
hold off

%% Calculate z-score dF/F
zdFF = z_signal - z_reference;

% Plot z-score dF/F
figure
plot(zdFF,'k')
savefig('Zscore.fig');
%%Peak Finder
figure
[pks, locs]=findpeaks(zdFF,'MinPeakProminence',7.5,'Annotate','extents'); %change number before Annotate to adjust sensitivity
TsDelta=[2:length(zdFF),0.0001];
TsDelta=TsDelta';
locs=locs';
plot(TsDelta,zdFF,locs,pks,'o')

%ZScore peakfinder
a=zdFF';
a(a<2.91)=0;
a(a>2.91)=1;
b=diff(a);
startspike=find(b==1);
stopspike=find(b==-1);
spikelength=stopspike-startspike;

Maxpeaks=[];
for n=1:length(startspike)
    aa= zdFF(startspike(n,1):stopspike(n,1));
    b=max(aa);
    Maxpeaks= [Maxpeaks b];
end

Maxpeaks=Maxpeaks';

clear a b

%times (seconds) that correspond to startspike
 z=[];
  for n=1:length(startspike)
    a=(Ts(startspike(n,1)));
    z= [z a];
  end
 z=z';

csvwrite('SpikeLength.csv',spikelength);

date = datestr(now,'mmddyyyy HHMMAM');
save(date);