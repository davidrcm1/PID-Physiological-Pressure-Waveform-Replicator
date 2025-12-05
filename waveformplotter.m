
clear; clc; close all;

%% --- Params ---
dt              = 0.013;     % Arduino timestep [s]
pre_hold_s      = 2.0;       % 2 s at fixed target
fixed_target    = 80.0;      % mmHg during pre-hold
target_duration = 4.0;       % stretch ONE_CYCLE to X seconds
cycles          = 3;         % repeat count
add_offset_mmHg = 9.6163*2;       % use to align baseline of waveform

%% --- Load dataset ---
S  = load('ILIAC_physio.mat');
fn = fieldnames(S);
CAR = S.(fn{1});

%% --- Pick waveform and convert Pa -> mmHg ---
idx     = 1;
sig     = CAR{idx}.ONE_CYCLE;
t_orig  = sig(:,1);
P_orig  = sig(:,2) / 133.322;          % Pa → mmHg

%% --- Stretch to target_duration ---
orig_duration = t_orig(end) - t_orig(1);
scale_factor  = target_duration / orig_duration;
t_scaled      = (t_orig - t_orig(1)) * scale_factor;  % start at 0
P_scaled      = P_orig + add_offset_mmHg;

%% --- Resample stretched waveform at dt ---
N_wf   = round(target_duration / dt);
t_wf   = (0:N_wf-1).' * dt;             % 0, dt, ..., 4s - dt
P_wf   = interp1(t_scaled, P_scaled, t_wf, 'linear', 'extrap');

%% --- Build one cycle: ---
N_pre  = round(pre_hold_s / dt);
t_pre  = (0:N_pre-1).' * dt;           
P_pre  = fixed_target * ones(N_pre,1);

t_one  = [t_pre; (t_pre(end)+dt) + t_wf];      
P_one  = [P_pre; P_wf];

one_len = numel(t_one);
seg_dur = (one_len-1) * dt;           

%% --- Repeat cycles  --
t_all = [];
P_all = [];
t_offset = 0;
for c = 1:cycles
    if c == 1
        t_all = [t_all; t_one];
    else
        t_all = [t_all; t_one + t_offset + dt];   % shift, avoid duplicate at join
    end
    P_all = [P_all; P_one];
    t_offset = t_all(end);                         % new end time
end

%% --- Check plot ---
figure('Color','w'); 
plot(t_all, P_all, 'LineWidth', 1.25); grid on;
xlabel('Time (s)'); ylabel('Pressure (mmHg)');
title(sprintf('Sequence: [2s @ %.0f] + [%.1fs waveform] x%d, dt = %.3f s', ...
      fixed_target, target_duration, cycles, dt));

%% --- Export CSV for Arduino  --
T = table(t_all, P_all, 'VariableNames', {'Time_s','Pressure_mmHg'});
writetable(T, 'IL4s.csv');   % match in code: SD.open("wf.csv")

fprintf('✅ Wrote wf.csv with %d rows. Total duration ≈ %.3f s\n', ...
        height(T), t_all(end));
