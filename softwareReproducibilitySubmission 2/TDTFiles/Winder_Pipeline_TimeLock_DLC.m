%%MODIFED Code by Sam Centanni with contributions from Munir Gunes Kutlu and Banu Kutlu
% Contact samuel.centanni@vanderbilt.edu

clear all; close all; %Clear all variables and close all figures
BlockDir=uigetdir('Select TDT Photometry Block'); %Get folder name
cd(BlockDir); %Change directory to photometry folder
[Tank,Block,~]=fileparts(cd); %List full directory for Tank and Block
data=TDTbin2mat(BlockDir); %Use TDT2Mat to extract data.

behaviorfolder = uigetdir;
filePattern = fullfile(behaviorfolder, '*.csv'); % Change to whatever format the files are in.
data.behaviorfile = dir(filePattern); %build list of all behavior files in selected folder
%% SYNAPSE- Extract Relevant Data from Data file
%Create Variables for each Photometry Channel and timestamps
Ch470=data.streams.x470A.data; %GCaMP
Ch405=data.streams.x405A.data; %Isosbestic Control
Ts = ((1:numel(data.streams.x470A.data(1,:))) / data.streams.x470A.fs)'; % Get Ts for samples based on Fs
StartTime=300; %Set the starting sample(recommend eliminating a few seconds for photoreceiver/LED rise time).
EndTime=length(Ch470); %Set the ending sample (again, eliminate some).
Fs=data.streams.x470A.fs; %Variable for Fs
Ts=Ts(StartTime:EndTime); % eliminate timestamps before starting sample and after ending.
Ch470=Ch470(StartTime:EndTime);
Ch405=Ch405(StartTime:EndTime);

%% Function to get DeltaF/F using regression fit
%Function to get DF/F for whole session
%Delta470=data.streams.x470A.data;

Delta470=DeltaF(Ch470,Ch405,[StartTime EndTime]); %TURN ON and next two lines OFF if you want to normalize to 405

% percentileNew = prctile(Ch470, 10);
% Delta470 = (Ch470(1:end) - percentileNew)./percentileNew;

%% Extracting Data


data.beh={};
A2={};
for k= 1:length(data.behaviorfile)
    filename = char(strcat({data.behaviorfile(k).folder}.','/',{data.behaviorfile(k).name}.')); 
    T = readtable((filename), 'ReadVariableNames', false);
    A= table2array(T);
    %next 3 lines for shifted analysis ONLY******
%     A=A(1:end,1)-10;
%     rowsToDeleteA = any((A < 0),2);
%     A(rowsToDeleteA,:) = [];
    A2=[A2 A];   
end
data.beh=A2;
clear A2

interval_pre = -5000; %milliseconds
interval_pre_s= abs(interval_pre./1000);
StartTime_s= StartTime./1000;
interval_post = 5000; %milliseconds
interval_post_s= (interval_post./1000)+StartTime_s;
EndTime_s= Ts(end,1);
B=[];
for y=1:length(data.behaviorfile)
    rowsToDelete = any((data.beh{1,y}) < (interval_pre_s + StartTime_s) | (data.beh{1,y})> (EndTime_s-interval_post_s) ,2);
    B=data.beh{1,y};
    B(rowsToDelete,:) = [];
    data.beh{1,y}=B;
end
    
clear interval_post_s interval_pre_s B A EndTime_s
%% Taking TTL times and Delta490 values around TTLs
%data.epocs.Po6_.onset - Tone

TTL_signal2={};
TTL_temp2={};
TTL_times2={};
for d= 1:length(data.behaviorfile)
    TTL_size = numel(data.beh{1,d});
    TTL_times = zeros(TTL_size,1);
    TTL_temp = zeros(TTL_size,1);
    interval_count = abs(interval_pre) + abs(interval_post);
    TTL_signal = zeros(interval_count, TTL_size);
    for TTL_index = 1:TTL_size %% timestamp
        [c, ind] = min(abs(Ts-data.beh{1,d}(TTL_index, 1)));  %returns the position best fit between T and TTL onset

        position = 0;
        for interval_ind = interval_pre:interval_post
            position = position+1;
            TTL_signal(position, TTL_index) = Delta470(ind + interval_ind);
            
        end

        TTL_temp(TTL_index) = Delta470(ind); %writes the Delta490 value for the best T+Po0 position
        TTL_times(TTL_index) = ind;
    end
    TTL_signal2= [TTL_signal2, TTL_signal];
    TTL_temp2= [TTL_temp2, TTL_temp];
    TTL_times2= [TTL_times2, TTL_times];
end

    data.TTLsig=TTL_signal2;
    data.TTLtemp=TTL_temp2;
    data.TTLtime=TTL_times2;

clear TTL_signal2 TTL_temp2 TTL_times2 d
%% Calculate z-score
baseline_pre = -2000; %milliseconds
baseline_post = 0; %milliseconds
z_allfin={};

     
for d= 1:length(data.behaviorfile)
     TTL_size = numel(data.TTLtime{1,d});
     baseline_size = abs(baseline_pre) + abs(baseline_post);
     baseline = zeros(size(data.TTLsig{1,d},1));
     z_all = zeros(size(data.TTLsig{1,d}));
     TTL_signal=data.TTLsig{1,d};
    
    for interval_index = 1:TTL_size
    baseline = TTL_signal(1:baseline_size, interval_index);
    b_mean = mean(baseline); % baseline period mean
    b_stdev = std(baseline); % baseline period stdev
        
        for TTL_index = 1:size(TTL_signal(:, interval_index)) % Z score per bin
        z_all(TTL_index, interval_index) = (TTL_signal(TTL_index, interval_index) - b_mean)/b_stdev;
        end
        
    end
    z_allfin= [z_allfin, z_all];
    
end

z_allfin1=z_allfin{1,1};
z_allfin2=z_allfin{1,2};
z_allfin3=z_allfin{1,3};

clear z_all z y x k

meanbeh1= mean((z_allfin1),2);
figure
plot(meanbeh1)
meanbeh2= mean((z_allfin2),2);
figure
plot(meanbeh2)
meanbeh3= mean((z_allfin3),2);
figure
plot(meanbeh3)


%Save TTL_signal to CSV file
csvwrite('HeadMovements(Zscore).csv',z_allfin1);
csvwrite('TailMovements(Zscore).csv',z_allfin2);
csvwrite('WholeBody(Zscore).csv',z_allfin3);

date = datestr(now,'mmddyyyy HHMMAM');
save(date);
%% extra plotting stuff

% plot(TTL_signal,'DisplayName','TTL_signal')
% 
% csvwrite('tone.csv',TTL_signal);
% 
% figure
% plot(Delta470)
% hold
% x=(1:length(Delta470));
% z = zeros(length(x),1) + -.01;
% p= plot(x,z,'-^','MarkerIndices',TTL_times)
% p.MarkerSize= 10
% p.MarkerFaceColor= 'green'


