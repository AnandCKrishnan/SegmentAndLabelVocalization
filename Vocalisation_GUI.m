%% ========================================================================
% Vocalisation_GUI.m
%
% MATLAB GUI-based tool to detect, visualize, and manually curate
% vocalisation events from Intan (.rhd) recordings and aligned audio (.wav) files.
%
% Author: Anand C Krishnan
% Date: 25.03.2026
%
%% ========================================================================

function Vocalisation_GUI
clc; clear;

%% ==================== SELECT FOLDERS ===================================
h = msgbox('Select the Intan (.rhd) file directory', 'Stimuli files'); 
uiwait(h);
IntanFilePath = uigetdir(pwd, 'Select the folder');

% h = msgbox('Select the Intan aligned .wav file directory', '.wav files'); 
% uiwait(h);
% WavFilePath = uigetdir(pwd, 'Select the folder');

WavFilePath = [fileparts(fileparts(IntanFilePath)) '/IntanAlignedPyCBSFiles'];

%% ==================== LOAD ALL RHD FILES ================================
cd(IntanFilePath)
files = dir('*.rhd'); 
IntanNames = {files.name};

Time_Intan = []; 
Dig_Intan = [];

for iF = 1:length(IntanNames)
    [t_board_adc, amplifier_data, board_adc_data, frequency_parameters, board_dig_in_data] = ...
        read_Intan_RHD2000_file_M(IntanNames{iF});
    Time_Intan = [Time_Intan, t_board_adc];
    Dig_Intan  = [Dig_Intan, board_dig_in_data];
end

Fs = 30000;

%% ==================== FIND BURSTS =======================================
min_width = round(0.0003*Fs);                  
clean_signal = bwareaopen(Dig_Intan, min_width); 
pulse_start_idx = find(diff(clean_signal) == 1) + 1; 

min_sep = 0.001*Fs; 
pulse_start_idx = pulse_start_idx([true diff(pulse_start_idx) > min_sep]);

pulse_gap = diff(pulse_start_idx)/Fs;

burst_start_idx = pulse_start_idx([true pulse_gap>0.9]); 
burst_start_idx(end) = []; 
burst_start_idx(1) = [];
burst_end_idx   = pulse_start_idx([pulse_gap>0.9 false]); 
burst_end_idx(1) = [];

%% ==================== LOAD WAV FILES ===================================
cd(WavFilePath)
files = dir('*.wav'); 
PyCBSNames = {files.name};
PyCBSData = [];

for iF = 1:length(PyCBSNames)
    [x, Fs] = audioread(PyCBSNames{iF});
    PyCBSData = [PyCBSData; x];
end

%% ==================== PARAMETERS =======================================
NumTrials = length(burst_start_idx);   
Pre  = 0.5*Fs;   
Post = 1*Fs;     
TargetTrials = 30; 

Results = struct;
validTrial = 0;
skippedTrials = 0;
validFileCount = 0;

%% ==================== MAIN CURATION LOOP ================================
i = 1;
while validTrial < TargetTrials && i <= NumTrials
    fprintf('\nChecking stimulus %d\n', i);

    start_sample = max(1, burst_start_idx(i) - Pre);
    end_sample   = min(length(PyCBSData), burst_end_idx(i) + Post);
    if end_sample <= start_sample
        i=i+1; 
        continue; 
    end

    RawSong = PyCBSData(start_sample:end_sample);
    FiltSong = bandpass(RawSong, Fs, 300, 10000);  
    Time_Vector_Amp = (0:length(FiltSong)-1)/Fs - Pre/Fs;

    nfft = 2^nextpow2(round(Fs*8/1000));  
    spect_win = hanning(nfft);
    noverlap = round(0.75*nfft);          

    [spect, freq, t_spect] = spectrogram(FiltSong, spect_win, noverlap, nfft, Fs, 'yaxis');
    spect_power = abs(spect);

    Time_Vector_Spect = t_spect - Pre/Fs;
    spect_power_interp = interp1(Time_Vector_Spect, spect_power', Time_Vector_Amp, 'linear', 0)';
    Time_Vector_Spect = Time_Vector_Amp;

    idx_spect = scale_spect(spect_power_interp);

    %% ==================== RUN GUI ======================================
    [N_voc, start_idx, end_idx, goBack, goNext, keepFile] = EditVocalisations_GUI_FinalEmbedded( ...
        Time_Vector_Spect, freq, idx_spect, Time_Vector_Amp, FiltSong, Fs, ...
        i, NumTrials, validFileCount);

    %% ==================== HANDLE NAVIGATION ===========================
    if goBack
        if validTrial > 0
            Results.Trials(validTrial) = [];
            validTrial = validTrial - 1;
        end
        validFileCount = max(0, validFileCount-1);
        i = max(1, i-1); 
        continue;
    elseif goNext
        i = i + 1;
    else
        break
    end

    %% ==================== SAVE DATA ===================================
    if keepFile && N_voc>0
        validTrial = validTrial + 1;
        validFileCount = validFileCount + 1;

        onsets  = Time_Vector_Amp(start_idx);
        offsets = Time_Vector_Amp(end_idx);
        durations = (offsets - onsets)*1000;

        Results.Trials(validTrial).StimulusNumber = i;
        Results.Trials(validTrial).N_voc          = N_voc;
        Results.Trials(validTrial).Onsets_sec     = onsets;
        Results.Trials(validTrial).Offsets_sec    = offsets;
        Results.Trials(validTrial).Durations_ms   = durations;
        Results.Trials(validTrial).RawAudio       = RawSong;       % raw audio with padding
        Results.Trials(validTrial).Fs             = Fs;            % sampling rate
        Results.Trials(validTrial).PrePadding_sec = Pre/Fs;        % optional, store padding info
        Results.Trials(validTrial).PostPadding_sec= Post/Fs;       % optional

        % Results.Trials(validTrial).SpectrogramData = spect_power_interp;
        % Results.Trials(validTrial).Freq_Vector     = freq;
        % Results.Trials(validTrial).Time_Vector     = Time_Vector_Spect;
        % Results.Trials(validTrial).AmpProfile      = FiltSong;
        % Results.Trials(validTrial).Time_Vector_Amp = Time_Vector_Amp;

        fprintf('Saved trial %d (contains vocalisation)\n', validTrial);
    else
        skippedTrials = skippedTrials + 1;
        fprintf('Skipped (no vocalisation)\n');
    end
end

%% ==================== SAVE RESULTS TO MAT FILE ==========================
Results.N_valid_trials       = validTrial;
Results.N_skipped_trials     = skippedTrials;
Results.Total_trials_checked = i-1;

[FileName, PathName] = uiputfile('*.mat','Save Vocalisation Results As');
if isequal(FileName,0) || isequal(PathName,0)
    disp('User canceled save. Data not saved.');
else
    save(fullfile(PathName, FileName),'Results','-v7.3');
    disp(['Data saved to: ' fullfile(PathName, FileName)]);
end

%% ==================== EMBEDDED GUI FUNCTION =============================
function [N_voc, start_idx, end_idx, goBack, goNext, keepFile] = EditVocalisations_GUI_FinalEmbedded( ...
        Time_Vector, Freq_Vector, idx_mean_spect, Time_Vector_Amp, FiltSong, Fs, ...
        fileNumber, totalFiles, validFileCount)
    
    goBack = 0; goNext = 0; keepFile = false;

    %% ==== COMPUTE AMPLITUDE ENVELOPE ===================================
    AmpProfile = abs(hilbert(FiltSong));
    AmpProfile = smoothdata(AmpProfile,'gaussian',round(0.010*Fs));
    baseline = AmpProfile(Time_Vector_Amp<0);
    AmpProfile = (AmpProfile - mean(baseline))./std(baseline);
    threshold = 4;

    above = AmpProfile>threshold;
    crossings = find(diff(above));
    if mod(length(crossings),2) ~= 0
        % if odd number of crossings, drop the last one
        crossings = crossings(1:end-1);
    end
    start_idx = crossings(1:2:end); 
    end_idx = crossings(2:2:end);
    minDur = round(0.010*Fs); 
    valid = (end_idx - start_idx) > minDur;
    start_idx = start_idx(valid); 
    end_idx = end_idx(valid);

    %% ==== CREATE FIGURE ================================================
    fig = figure('Color','w','Position',[200 100 1000 700]);
    titleHandle = sgtitle('');
    yLimits = [min(AmpProfile)-1, max(AmpProfile)+1];

    ax1 = subplot(2,1,1);
    disp_idx_spect(idx_mean_spect, Time_Vector, Freq_Vector, -50, -10, 1.5, 'hot', 'classic');
    axis([Time_Vector(1) Time_Vector(end) 300 8000])
    xline(0,'b','LineWidth',2); title('Spectrogram'); hold on

    ax2 = subplot(2,1,2);
    plot(Time_Vector_Amp,AmpProfile,'k','LineWidth',2); hold on
    yline(threshold,'r','LineWidth',2); xline(0,'b','LineWidth',2)
    xlabel('Time (s)'); ylabel('Norm amplitude (SD)'); 
    xlim([Time_Vector(1) Time_Vector(end)]);
    ylim(yLimits); title('Amplitude profile');

    hPatch = gobjects(0); hLineSpectStart = gobjects(0); hLineSpectEnd = gobjects(0);
    hLineAmpStart = gobjects(0); hLineAmpEnd = gobjects(0);

    drawSegments();

    %% ==== GUI BUTTONS ==================================================
    uicontrol('Style','pushbutton','String','DELETE VOCALISATION','Units','normalized','Position',[0.03 0.02 0.18 0.06],'FontSize',10,'Callback',@deleteSegment);
    uicontrol('Style','pushbutton','String','DELETE ALL','Units','normalized','Position',[0.22 0.02 0.14 0.06],'FontSize',10,'Callback',@deleteAll);
    uicontrol('Style','pushbutton','String','ADD VOCALISATION','Units','normalized','Position',[0.37 0.02 0.18 0.06],'FontSize',10,'Callback',@addSegment);
    uicontrol('Style','pushbutton','String','MANUAL SEGMENT','Units','normalized','Position',[0.56 0.02 0.18 0.06],'FontSize',10,'Callback',@manualSegment);
    uicontrol('Style','pushbutton','String','BACK','Units','normalized','Position',[0.86 0.02 0.06 0.06],'FontSize',10,'Callback',@goBackFcn);
    uicontrol('Style','pushbutton','String','NEXT','Units','normalized','Position',[0.93 0.02 0.06 0.06],'FontSize',10,'Callback',@goNextFcn);

    set(fig,'KeyPressFcn',@(src,event) keyboardShortcut(src,event));

    uiwait(fig);

    N_voc = length(start_idx);
    close(fig);

    %% ==================== NESTED CALLBACK FUNCTIONS ===================

    function drawSegments()
        delete(hPatch); delete(hLineSpectStart); delete(hLineSpectEnd); delete(hLineAmpStart); delete(hLineAmpEnd);
        hPatch = gobjects(length(start_idx),1); hLineSpectStart = gobjects(length(start_idx),1);
        hLineSpectEnd = gobjects(length(start_idx),1); hLineAmpStart = gobjects(length(start_idx),1);
        hLineAmpEnd = gobjects(length(start_idx),1);
        for k=1:length(start_idx)
            t1 = Time_Vector_Amp(start_idx(k)); t2 = Time_Vector_Amp(end_idx(k));
            hPatch(k) = patch(ax2,[t1 t2 t2 t1],[yLimits(1) yLimits(1) yLimits(2) yLimits(2)],[0 0.4 0],'EdgeColor','none','FaceAlpha',0.4);
            hLineSpectStart(k) = xline(ax1,t1,'Color',[0 0.4 0],'LineWidth',1.5);
            hLineSpectEnd(k)   = xline(ax1,t2,'Color',[0 0.4 0],'LineWidth',1.5);
            hLineAmpStart(k)   = xline(ax2,t1,'Color',[0 0.4 0],'LineWidth',1.5);
            hLineAmpEnd(k)     = xline(ax2,t2,'Color',[0 0.4 0],'LineWidth',1.5);
        end
        updateTitle();
    end

    function updateTitle()
        nSeg = length(start_idx);
        titleHandle.String = sprintf('File %d / %d | Files with vocalisation = %d | Segments = %d', ...
            fileNumber, totalFiles, validFileCount, nSeg);
    end

    function deleteSegment(~,~)
        [x,~] = ginput(1);
        for k=1:length(start_idx)
            t1 = Time_Vector_Amp(start_idx(k)); t2 = Time_Vector_Amp(end_idx(k));
            if x>t1 && x<t2, start_idx(k)=[]; end_idx(k)=[]; drawSegments(); return; end
        end
    end

    function deleteAll(~,~)
        start_idx=[]; end_idx=[]; drawSegments();
    end

    function addSegment(~,~)
        [x,~] = ginput(1); [~,idx_click]=min(abs(Time_Vector_Amp-x));
        crossings = find(diff(AmpProfile>threshold)); [~,cidx]=min(abs(crossings-idx_click));
        if mod(cidx,2)==1, s=crossings(cidx); e=crossings(cidx+1);
        else s=crossings(cidx-1); e=crossings(cidx); end
        if (e-s)<minDur, return; end
        start_idx=[start_idx;s]; end_idx=[end_idx;e]; drawSegments();
    end

    function manualSegment(~,~)
        [x,~,button]=ginput(2); if button(1)~=1||button(2)~=3, return; end
        [~,s]=min(abs(Time_Vector_Amp-x(1))); [~,e]=min(abs(Time_Vector_Amp-x(2)));
        if (e-s)<minDur, return; end
        start_idx=[start_idx;s]; end_idx=[end_idx;e]; drawSegments();
    end

    function goBackFcn(~,~), goBack=1; goNext=0; keepFile=false; uiresume(fig); end
    function goNextFcn(~,~), goNext=1; goBack=0; keepFile = ~isempty(start_idx); uiresume(fig); end
    function keyboardShortcut(~, event)
        switch event.Key
            case 'd'  % delete all segments
                deleteAll();
            case 's'  % press 's' to go to NEXT trial
                goNextFcn();
        end
    end

end

end