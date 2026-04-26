

files = dir('*.mat');
AllFiles = {files.name};
mkdir Plots

Fontname = 'Arial';
Fontsize = 14;

MeanSpect_All = {};
MeanAmp_All = {};
SEMAmp_All = {};
TimeAmp_All = {};
TimeSpect_All = {};

Latency_AllFiles  = {};
Duration_AllFiles = {};
Raster_Onsets_All  = {};
Raster_Offsets_All = {};
AllStimDuration = [];

VariableParameter = {};

% Variable = 'Current';
% Unit  = 'μA';

Variable = 'Duration';
Unit  = 'ms';

% Variable = 'Frequency';
% Unit  = 'Hz';

for i=1:length(AllFiles)

    load(AllFiles{i})
    Params.Current = AllFiles{i}(19:end-16);
    Params.Frequency = AllFiles{i}(25:end-10);
    Params.Duration = AllFiles{i}(31:end-4);
    AllStimDuration(i) = str2double(Params.Duration(1:end-2));

    Spectrogram_All = [];
    Time_Vector = [];
    Freq_Vector = [];
    Amp_All = [];
    Onsets_All = [];
    Offsets_All = [];
    Duration_All = [];

    for j=1:length(Results.Trials)
        
        if j == 1
            Raster_Onsets  = {};
            Raster_Offsets = {};
        end

        RawSong = Results.Trials(j).RawAudio;
        Fs = Results.Trials(j).Fs;
        Pre = Results.Trials(j).PrePadding_sec;
        Onset = Results.Trials(j).Onsets_sec;
        Offset = Results.Trials(j).Offsets_sec;
        SyllDuration = Results.Trials(j).Durations_ms;

        % 1. Sort the first array and get the indices (I)
        [Onset, I] = sort(Onset);

        % 2. Apply those same indices to the second array
        Offset = Offset(I);
        SyllDuration = SyllDuration(I);

        if length(Onset)>1
            Onsets_All = [Onsets_All Onset(1)];
            Offsets_All = [Offsets_All Offset(1)];
            Duration_All = [Duration_All SyllDuration(1)];
            Raster_Onsets{j}  = Onset(1:end);
            Raster_Offsets{j} = Offset(1:end);

        else
            Onsets_All = [Onsets_All Onset];
            Offsets_All = [Offsets_All Offset];
            Duration_All = [Duration_All SyllDuration];
            Raster_Onsets{j}  = Onset;
            Raster_Offsets{j} = Offset;
        end

        FiltSong = bandpass(RawSong,Fs,300,10000);
        AmpProfile  = abs(hilbert(FiltSong));

        if j == 1
            minLen = length(AmpProfile);
        end

        minLen = min(minLen, length(AmpProfile));
        Amp_All(1:minLen,j) = AmpProfile(1:minLen);

        nfft=round(Fs*8/1000);
        nfft = 2^nextpow2(nfft);
        spect_win = hanning(nfft);
        noverlap = round(0.95*length(spect_win));
        [spect, freq, time_song] = spectrogram(FiltSong,spect_win,noverlap,nfft,Fs,'yaxis');
        time_song = time_song - Pre - (length(spect_win)/(2*Fs));
        spect_power = abs(spect);

        idx_spect=scale_spect(spect);
        f_min = freq(1);
        f_max = freq(length(freq));
        freq_spect = [f_min, f_max];

        t_min = time_song(1);
        t_max = time_song(end);
        time_spect = [t_min, t_max];

        if j == 1
            Spectrogram_All = zeros(size(spect_power,1), size(spect_power,2), length(Results.Trials));
            Time_Vector = time_spect;
            Freq_Vector = freq_spect;
        end

        minCols = min(size(spect_power,2), size(Spectrogram_All,2));
        Spectrogram_All(:,1:minCols,j) = spect_power(:,1:minCols);
    end

    Mean_Spectrogram = mean(Spectrogram_All,3);
    idx_mean_spect = scale_spect(Mean_Spectrogram);

    Mean_AmpProfile = mean(Amp_All, 2);
    SEM_AmpProfile = std(Amp_All, 0, 2)/sqrt(length(Results.Trials));
    Time_Vector_Amp = (0:minLen-1)/Fs - Pre;
    Mean_AmpProfile = smooth(Mean_AmpProfile, 10);  % smooth 20 samples

    % --- trim amplitude and time vector to minLen ---
    Mean_AmpProfile = Mean_AmpProfile(1:minLen);
    SEM_AmpProfile  = SEM_AmpProfile(1:minLen);
    Time_Vector_Amp = Time_Vector_Amp(1:minLen);

    MeanSpect_All{i} = Mean_Spectrogram;
    TimeSpect_All{i} = Time_Vector;
    MeanAmp_All{i}   = Mean_AmpProfile;
    SEMAmp_All{i}  = SEM_AmpProfile;
    TimeAmp_All{i}   = Time_Vector_Amp;

    Onsets_All = Onsets_All*1000;
    Latency_AllFiles{i}  = Onsets_All;
    Duration_AllFiles{i} = Duration_All;
    VariableParameter{i} = [Params.(Variable)(1:end-2) ' ' Unit];
    Raster_Onsets_All{i}  = Raster_Onsets;
    Raster_Offsets_All{i} = Raster_Offsets;

    % % Create a wider figure window
    % figure('Units','normalized','Position',[0.05 0.1 0.9 0.7])   % wider figure
    % set(gcf,'Renderer','painters')   % ensures text and lines look identical
    % % 
    % % -------- PLOT AVERAGE SPECTROGRAM --------
    % subplot(2,4,[1:2])
    % disp_idx_spect(idx_mean_spect, Time_Vector, Freq_Vector, -50, -10, 1.5, 'hot', 'classic');
    % 
    % axis([Time_Vector(1) Time_Vector(end) 300 8000])
    % xline(0, 'b','LineWidth',2)
    % xlabel('Time from burst onset (s)')
    % ylabel('Frequency (Hz)')
    % title('Average Spectrogram Across Bursts')
    % set(gca,'FontSize',Fontsize,'Fontname',Fontname)
    % 
    % 
    % % -------- PLOT AMPLITUDE PROFILE --------
    % subplot(2,4,[5:6])
    % plot(Time_Vector_Amp, Mean_AmpProfile, 'LineWidth', 2, 'Color', 'k');
    % 
    % upper = Mean_AmpProfile + SEM_AmpProfile;
    % lower = Mean_AmpProfile - SEM_AmpProfile;
    % hold on
    % t = Time_Vector_Amp(:)';     % force row
    % upper = upper(:)';           % force row
    % lower = lower(:)';           % force row
    % patch([t fliplr(t)], [upper fliplr(lower)], 'k', 'EdgeColor','none', 'FaceAlpha',0.5);
    % 
    % xlim([Time_Vector(1) Time_Vector(end)])
    % xline(0, 'b','LineWidth',2)
    % xlabel('Time from burst onset (s)');
    % ylabel('Amplitude');
    % title('Average Amplitude Profile Across Bursts');
    % set(gca,'FontSize',Fontsize,'FontName',Fontname);
    % 
    % 
    % subplot(2,4,3)
    % boxchart(Onsets_All, 'BoxFaceColor','#FF0000', 'MarkerStyle','none', 'BoxEdgeColor', '#000000')
    % hold on
    % scatter(ones(length(Onsets_All),1), Onsets_All, 100, 'filled', 'MarkerFaceColor','#FF0000', 'MarkerFaceAlpha',0.4)
    % 
    % ax = gca;
    % ax.XTick = [];
    % ylim([min(Onsets_All)-5 max(Onsets_All)+5])
    % ylabel('Latency (ms)')
    % title('Latency')
    % set(gca,'FontSize',Fontsize,'FontName',Fontname,'LineWidth',1.2)
    % box on
    % 
    % 
    % subplot(2,4,7)
    % trials = 1:length(Onsets_All);
    % plot(trials, Onsets_All, '-k', 'LineWidth',1.5)  % black line connecting points
    % hold on
    % scatter(trials, Onsets_All, 100, ...
    %     'MarkerFaceColor','#FF0000', ...
    %     'MarkerEdgeColor','#FF0000', ...
    %     'MarkerFaceAlpha',0.5, ...
    %     'MarkerEdgeAlpha',0.5);
    % 
    % ylim([min(Onsets_All)-5 max(Onsets_All)+5])
    % xlabel('Trial Number')
    % ylabel('Latency (ms)')
    % box on
    % title('Latency')
    % set(gca,'FontSize',Fontsize,'FontName',Fontname)
    % 
    % 
    % subplot(2,4,4)
    % boxchart(Duration_All, 'BoxFaceColor','#FF0000', 'MarkerStyle','none', 'BoxEdgeColor', '#000000')
    % hold on
    % scatter(ones(length(Duration_All),1), Duration_All, 100, 'filled', 'MarkerFaceColor','#FF0000', 'MarkerFaceAlpha',0.4)
    % 
    % ax = gca;
    % ax.XTick = [];
    % ylim([min(Duration_All)-10 max(Duration_All)+10])
    % ylabel('Duration (ms)')
    % title('Duration')
    % set(gca,'FontSize',Fontsize,'FontName',Fontname,'LineWidth',1.2)
    % box on
    % 
    % subplot(2,4,8)
    % trials = 1:length(Duration_All);
    % plot(trials, Duration_All, '-k', 'LineWidth',1.5)  % black line connecting points
    % hold on
    % scatter(trials, Duration_All, 100, ...
    %     'MarkerFaceColor','#FF0000', ...
    %     'MarkerEdgeColor','#FF0000', ...
    %     'MarkerFaceAlpha',0.5, ...
    %     'MarkerEdgeAlpha',0.5);
    % 
    % ylim([min(Duration_All)-10 max(Duration_All)+10])
    % xlabel('Trial Number')
    % ylabel('Duration (ms)')
    % box on
    % title('Duration')
    % set(gca,'FontSize',Fontsize,'FontName',Fontname)
    % 
    % sgtitle(['purple93orange225 (' num2str(Params.Current(1:end-2)) ' uA, ' num2str(Params.Frequency(1:end-2)) ' Hz, ' num2str(Params.Duration(1:end-2)) ' ms)'], 'FontWeight', 'bold');
    % set(gca,'FontSize',Fontsize,'Fontname',Fontname)
    % set(gcf,'Color','White')
    % 
    % cd Plots
    % savefig(gcf, ['purple93orange225_' num2str(Params.Current) '_' num2str(Params.Frequency) '_' Params.Duration '.fig']);
    % exportgraphics(gcf, ['purple93orange225_' num2str(Params.Current) '_' num2str(Params.Frequency) '_' Params.Duration '.tif']);
    % close(gcf)
    % cd ..

end

n = length(AllFiles);

% LATENCY
latency_min = inf;
latency_max = -inf;
for i = 1:n
    latency_min = min(latency_min, min(Latency_AllFiles{i}));
    latency_max = max(latency_max, max(Latency_AllFiles{i}));
end

% add small tolerance, e.g., 5% of range
latency_range = latency_max - latency_min;
latency_min = latency_min - 0.05*latency_range;
latency_max = latency_max + 0.05*latency_range;

% DURATION
duration_min = inf;
duration_max = -inf;
for i = 1:n
    duration_min = min(duration_min, min(Duration_AllFiles{i}));
    duration_max = max(duration_max, max(Duration_AllFiles{i}));
end

duration_range = duration_max - duration_min;
duration_min = duration_min - 0.05*duration_range;
duration_max = duration_max + 0.05*duration_range;


% figure('Units','normalized','Position',[0.02 0.05 0.95 0.88])
% t = tiledlayout(4,2*n,'TileSpacing','compact','Padding','compact');
% t.Position = [0.08 0.08 0.85 0.85];   % leave space at bottom for xlabel
% set(gcf,'Renderer','painters')   % ensures text and lines look identical
% 
% 
% % =========================================================
% % ROW 1 : LATENCY (BOX LEFT, LINE RIGHT)
% % =========================================================
% ax_first_row = gobjects(1,2*n);
% 
% 
% for i = 1:n
% 
%     % ----- boxplot -----
%     ax_first_row(2*i-1) = nexttile;
%     boxchart(Latency_AllFiles{i}, ...
%         'BoxFaceColor','#FF0000', ...
%         'MarkerStyle','none', ...
%         'BoxEdgeColor','#000000');
% 
%     hold on
%     scatter(ones(length(Latency_AllFiles{i}),1), Latency_AllFiles{i}, ...
%         80,'filled','MarkerFaceColor','#FF0000','MarkerFaceAlpha',0.4);
% 
%     ylim([latency_min latency_max]);
%     xticks([])       % remove x-axis tick labels
%     xlabel(VariableParameter{i})  % single x-axis label instead
%     if i==1
%         ylabel('Latency (ms)')
%     end
%     set(gca,'FontSize',Fontsize,'FontName',Fontname)
%     box on
% 
% 
%     % ----- trial line -----
%     ax_first_row(2*i) = nexttile;
%     trials = 1:length(Latency_AllFiles{i});
% 
%     plot(trials, Latency_AllFiles{i}, '-k','LineWidth',1.5)
%     hold on
%     scatter(trials, Latency_AllFiles{i}, 80, ...
%         'MarkerFaceColor','#FF0000', ...
%         'MarkerEdgeColor','#FF0000', ...
%         'MarkerFaceAlpha',0.5, ...
%         'MarkerEdgeAlpha',0.5);
% 
%     ylim([latency_min latency_max]);
%     xlabel('Trial Number')
%     set(gca,'FontSize',Fontsize,'FontName',Fontname)
%     box on
% 
% end
% 
% 
% % =========================================================
% % ROW 2 : DURATION (BOX LEFT, LINE RIGHT)
% % =========================================================
% for i = 1:n
% 
%     % ----- boxplot -----
%     nexttile
%     boxchart(Duration_AllFiles{i}, ...
%         'BoxFaceColor','#FF0000', ...
%         'MarkerStyle','none', ...
%         'BoxEdgeColor','#000000');
% 
%     hold on
%     scatter(ones(length(Duration_AllFiles{i}),1), Duration_AllFiles{i}, ...
%         80,'filled','MarkerFaceColor','#FF0000','MarkerFaceAlpha',0.4);
% 
%     ylim([duration_min duration_max]);
%     xticks([])       % remove x-axis tick labels
%     xlabel(VariableParameter{i})  % single x-axis label instead
%     if i==1
%         ylabel('Duration (ms)')
%     end
%     set(gca,'FontSize',Fontsize,'FontName',Fontname)
%     box on
% 
% 
%     % ----- trial line -----
%     nexttile
% 
%     trials = 1:length(Duration_AllFiles{i});
% 
%     plot(trials, Duration_AllFiles{i}, '-k','LineWidth',1.5)
%     hold on
%     scatter(trials, Duration_AllFiles{i}, 80, ...
%         'MarkerFaceColor','#FF0000', ...
%         'MarkerEdgeColor','#FF0000', ...
%         'MarkerFaceAlpha',0.5, ...
%         'MarkerEdgeAlpha',0.5);
% 
%     ylim([duration_min duration_max]);
%     xlabel('Trial Number')
%     set(gca,'FontSize',Fontsize,'FontName',Fontname)
%     box on
% 
% end
% 
% 
% % =========================================================
% % ROW 3 : SPECTROGRAM (each takes 2 columns)
% % =========================================================
% 
% for i = 1:n
% 
%     nexttile([1 2])
%     idx_mean_spect = scale_spect(MeanSpect_All{i});
% 
%     disp_idx_spect(idx_mean_spect, TimeSpect_All{i}, Freq_Vector, ...
%         -50, -10, 1.5, 'hot', 'classic');
% 
%     axis([TimeSpect_All{i}(1) TimeSpect_All{i}(end) 300 8000])
%     xline(0,'b','LineWidth',2)
%     yticks([2000 4000 6000 8000])
% 
%     ax = gca;
%     ax.YAxis.Exponent = 3;     % forces ×10^3 (kHz style scaling)
% 
%     drawnow
%     box on
%     set(gca,'LineWidth',1,'Layer','top')
% 
%     if i==1
%         ylabel('Frequency (Hz)')
%     end
% 
%     %title(VariableParameter{i}, 'FontWeight','normal')
%     set(gca,'FontSize',Fontsize,'FontName',Fontname)
%     box on
% 
% end
% 
% 
% % =========================================================
% % ROW 4 : AMPLITUDE PROFILE (same width as spectrogram)
% % =========================================================
% global_min = inf;
% global_max = -inf;
% 
% for i = 1:length(MeanAmp_All)
%     global_min = min(global_min, min(MeanAmp_All{i}));
%     global_max = max(global_max, max(MeanAmp_All{i}));
% end
% 
% for i = 1:n
% 
%     nexttile([1 2])
%     hold on
% 
%     t = TimeAmp_All{i}(:)';
%     meanAmp = MeanAmp_All{i}(:)';
%     semAmp  = SEMAmp_All{i}(:)';
% 
%     upper = meanAmp + semAmp;
%     lower = meanAmp - semAmp;
% 
%     patch([t fliplr(t)], [upper fliplr(lower)], ...
%           'k','EdgeColor','none','FaceAlpha',0.5)
% 
%     plot(t, meanAmp,'k','LineWidth',1)
% 
%     xline(0,'b','LineWidth',2)
% 
%     range = global_max - global_min;
%     ylim([global_min - 0.05*range , global_max + 0.05*range])
%     xlim([Time_Vector(1) Time_Vector(end)])
% 
%     if i==1
%         ylabel('Amplitude (V)')
%     end
% 
%     set(gca,'FontSize',Fontsize,'FontName',Fontname)
%     box on
% 
% end
% 
% annotation('textbox',[0 0.01 1 0.05], ...
%     'String','Time (s)', ...
%     'EdgeColor','none', ...
%     'HorizontalAlignment','center', ...
%     'FontSize',Fontsize, ...
%     'FontName',Fontname);
% 
% 
% drawnow  % ensure axes positions are finalized
% 
% for i = 1:n
%     % get positions of left and right axes in figure normalized units
%     pos1 = ax_first_row(2*i-1).Position;
%     pos2 = ax_first_row(2*i).Position;
% 
%     % horizontal center between left of first and right of second
%     x_center = pos1(1) + pos2(1) + pos1(3) + pos2(3);  % sum edges
%     x_center = x_center / 2;  % average
% 
%     % vertical position just above the top of the first row
%     y_top = max(pos1(2)+pos1(4), pos2(2)+pos2(4));
% 
%     % create annotation textbox
%     annotation('textbox', [x_center-0.06 y_top-0.02 0.12 0.035], ...
%                'String', VariableParameter{i}, ...
%                'EdgeColor', 'none', ...
%                'HorizontalAlignment','center', ...
%                'VerticalAlignment','bottom', ...
%                'FontSize', Fontsize+2, ...
%                'FontName', Fontname, ...
%                'FontWeight','bold');
% end
% 
% %sgtitle('purple93orange225', 'FontSize',Fontsize,'Fontname',Fontname)
% set(gca,'FontSize',Fontsize,'Fontname',Fontname)
% set(gcf,'Color','White')
% 
% 
% cd Plots
% savefig(gcf, ['purple93orange225_' Variable '.fig']);
% exportgraphics(gcf, ['purple93orange225_' Variable '.tif']);
% close(gcf)


% 
% cd ..


% =========================================================
% COMBINE ALL DATA INTO ONE VECTOR (for boxchart)
% =========================================================

all_latency = [];
group_latency = [];

all_duration = [];
group_duration = [];

for i = 1:n
    
    % latency
    L = Latency_AllFiles{i}(:);
    all_latency = [all_latency ; L];
    group_latency = [group_latency ; i*ones(length(L),1)];
    
    % duration
    D = Duration_AllFiles{i}(:);
    all_duration = [all_duration ; D];
    group_duration = [group_duration ; i*ones(length(D),1)];
end


% =========================================================
% FIGURE
% =========================================================

figure('Units','normalized','Position',[0.1 0.1 0.8 0.75])
tiledlayout(2,1,'TileSpacing','compact','Padding','compact')
set(gcf,'Renderer','painters')   % ensures text and lines look identical


% =========================================================
% LATENCY COMBINED BOXPLOT
% =========================================================

nexttile

boxchart(group_latency, all_latency, ...
    'BoxFaceColor','#FF0000', ...
    'BoxEdgeColor','#000000', ...
    'MarkerStyle','none');

hold on

scatter(group_latency, all_latency, 60, ...
    'filled', ...
    'MarkerFaceColor','#FF0000', ...
    'MarkerFaceAlpha',0.3);

ylim([latency_min latency_max])
xticks(1:n)
xticklabels(VariableParameter)

ylabel('Latency (ms)')
title('Combined Latency Box Plot')

set(gca,'FontSize',Fontsize,'FontName',Fontname)
box on


% =========================================================
% DURATION COMBINED BOXPLOT
% =========================================================

nexttile

boxchart(group_duration, all_duration, ...
    'BoxFaceColor','#FF0000', ...
    'BoxEdgeColor','#000000', ...
    'MarkerStyle','none');

hold on

scatter(group_duration, all_duration, 60, ...
    'filled', ...
    'MarkerFaceColor','#FF0000', ...
    'MarkerFaceAlpha',0.3);

ylim([duration_min duration_max])
xticks(1:n)
xticklabels(VariableParameter)

ylabel('Duration (ms)')
title('Combined Duration Box Plot')

set(gca,'FontSize',Fontsize,'FontName',Fontname)
box on


set(gcf,'Color','white')


cd Plots
savefig(gcf, 'purple93orange225_CombinedLatencyDuration.fig');
exportgraphics(gcf, 'purple93orange225_CombinedLatencyDuration.tif');
close(gcf)


cd ..
%   Raster
% =========================================================
% COMBINED RASTER PLOT (onset → offset as patches)
% different colours for each vocalisation
% =========================================================

figure('Units','normalized','Position',[0.15 0.1 0.7 0.85])
set(gcf,'Renderer','painters')   % ensures text and lines look identical

hold on

trial_offset = 0;
BlockCenters = zeros(1,length(Raster_Onsets_All));

for i = 1:length(Raster_Onsets_All)

    On_File  = Raster_Onsets_All{i};
    Off_File = Raster_Offsets_All{i};

    start_trial = trial_offset + 1;

    % =====================================================
    % VOCALISATION PATCHES (different colour per vocalisation)
    % =====================================================
    for tr = 1:length(On_File)

        % ===== stimulus patch for THIS trial only =====
        stim_start = 0;
        stim_end   = AllStimDuration(i);

        y_trial = [trial_offset+tr-0.5 trial_offset+tr-0.5 ...
            trial_offset+tr+0.5 trial_offset+tr+0.5];

        patch([stim_start stim_end stim_end stim_start], ...
            y_trial, [0.85 0.85 0.85], 'EdgeColor','none');

        on  = On_File{tr};
        off = Off_File{tr};

        if ~isempty(on)

            colors = lines(length(on));   % generate colours

            for k = 1:length(on)

                x = [on(k) off(k) off(k) on(k)] * 1000;
                y = [trial_offset+tr-0.4 trial_offset+tr-0.4 ...
                     trial_offset+tr+0.4 trial_offset+tr+0.4];

                patch(x, y, colors(k,:), 'EdgeColor','none');

            end
        end
    end

    end_trial = trial_offset + length(On_File);

    % store center of this parameter block
    BlockCenters(i) = (start_trial + end_trial)/2;

    % separator line between files
    trial_offset = end_trial;

    % add the gap first
    trial_offset = trial_offset + 5;

    % draw the line at the centre of the gap
    gap_center = trial_offset - 2.5;
    yline(gap_center,'Color',[0.6 0.6 0.6],'LineWidth',1)

% trial_offset = end_trial;
%     center_line = (start_trial + end_trial)/2;
%     yline(center_line,'Color',[0.6 0.6 0.6],'LineWidth',1)
%     %yline(trial_offset+0.5,'Color',[0.6 0.6 0.6],'LineWidth',1)
% 
%     % spacing between files
%     trial_offset = trial_offset + 5;

end

% trigger line
xline(0,'b','LineWidth',2)
ytickangle(90)

% ===== axis labels =====
set(gca,'YTick',BlockCenters)
set(gca,'YTickLabel',VariableParameter)

xlabel('Time from burst onset (ms)')
ylabel(Variable)
xlim([-500 max(AllStimDuration)+1000])     % same time window as your other plots

title('Raster plot: vocalisations after trigger')

set(gca,'FontSize',Fontsize,'FontName',Fontname)
box on
set(gcf,'Color','white')

cd Plots
savefig(gcf, 'purple93orange225_CombinedRastor.fig');
exportgraphics(gcf, 'purple93orange225_CombinedRastor.tif');
close(gcf)