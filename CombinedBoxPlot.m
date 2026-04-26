n = length(AllFiles);

%% =========================================================
% FIND GLOBAL LIMITS (same logic as your code)
% =========================================================

% LATENCY
latency_min = inf;
latency_max = -inf;

for i = 1:n
    latency_min = min(latency_min, min(Latency_AllFiles{i}));
    latency_max = max(latency_max, max(Latency_AllFiles{i}));
end

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


%% =========================================================
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


%% =========================================================
% FIGURE
% =========================================================

figure('Units','normalized','Position',[0.1 0.1 0.8 0.75])
tiledlayout(2,1,'TileSpacing','compact','Padding','compact')
set(gcf,'Renderer','painters')   % ensures text and lines look identical


%% =========================================================
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


%% =========================================================
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