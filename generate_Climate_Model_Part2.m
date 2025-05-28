function generate_Climate_Model_Part2()
    % --- Automatically extract 10 physical effects from CSV for Simulink ---
    csv_file = 'toyota_chr_energy_consumption.csv'; % Adjust path if needed
    data = readtable(csv_file, 'VariableNamingRule', 'preserve');

    effect_names_csv = {'debit d''air', 'temperature intern', 'nomber de pasagere', ...
        'temperature conssigne', 'intensite solaire', 'puisance d''equipement', ...
        'mass d''air', 'vitesse de voiture', 'temperature externe', 'humidite', ...
        'difference_temperature'};

    effect_names_var = {'debit_d_air', 'temperature_intern', 'nomber_de_pasagere', ...
        'temperature_conssigne', 'intensite_solaire', 'puisance_d_equipement', ...
        'mass_d_air', 'vitesse_de_voiture', 'temperature_externe', 'humidite', ...
        'difference_temperature'};

    for i = 1:length(effect_names_csv)
        effect = effect_names_csv{i};
        effect_var = effect_names_var{i};
        assignin('base', effect_var, struct( ...
            'time', (0:height(data)-1)', ...
            'signals', struct('values', data{:,effect}, 'dimensions', 1) ...
        ));
    end

    modelName = 'Toyota_CHR_Climate_Model_V2';

    if ~bdIsLoaded(modelName)
        error('Le modèle n''est pas chargé. Exécutez d''abord la Partie 1.');
    end

    oldBlocks = {'Reference','Error_Calculation','Temperature_Scope','Control_Scope', ...
        'Vehicle_Dynamics','Reshape_Input_u','Reshape_X_min','Reshape_X_max', ...
        'Reshape_Y_min','Reshape_Y_max','Saturation','Combine_Signals', ...
        'Temp_Out','PID_Out','ToWs_Puissance_Predite','ToWs_Puissance_Reelle','ToWs_Temp_Regulee'};

    for k = 1:numel(oldBlocks)
        safeDeleteBlock(modelName, oldBlocks{k});
    end

    % Step 1: Reference and Error
    add_block('simulink/Sources/Constant', [modelName '/Reference'], ...
        'Value', '25', 'Position', [100 100 130 130]);
    add_block('simulink/Math Operations/Sum', [modelName '/Error_Calculation'], ...
        'Inputs', '|+-', 'Position', [250 100 290 140]);

    % Step 2: Scopes
    add_block('simulink/Sinks/Scope', [modelName '/Temperature_Scope'], 'Position', [600 80 650 120]);
    add_block('simulink/Sinks/Scope', [modelName '/Control_Scope'],     'Position', [600 200 650 240]);


add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/Vehicle_Dynamics'], ...
    'Position', [350 80 500 240]);

    % Assumons que le sous-système existe déjà
subsystem = [modelName '/Vehicle_Dynamics'];
open_system(subsystem);

% Supprimer toutes les lignes
lines = get_param(subsystem, 'Lines');
if isstruct(lines)
    for i = 1:length(lines)
        try
            delete_line(subsystem, lines(i).Name);
        catch
        end
    end
end

% === Blocs ===

% Clean up subsystem: remove all blocks and lines
delete_lines(subsystem);
blocks = find_system(subsystem, 'SearchDepth', 1, 'Type', 'Block');
for k = 2:length(blocks) % skip the subsystem itself
    try
        delete_block(blocks{k});
    catch
    end
end

% === Paramètres physiques ===
% surface_vitree = 5; facteur_solaire = 0.6;
% surface_parois = 10; coefficient_transmission = 2.5;
% chaleur_passager = 100; capacite_thermique_massique_air = 1005;

% Add Outport for puissance_climatisation
add_block('simulink/Sinks/Out1', [subsystem '/Out1'], 'Position', [600 200 630 220]);

% Add 8 Inports: 1 for control_signal, 7 for effects
add_block('simulink/Sources/In1', [subsystem '/control_signal'], 'Position', [30 20 60 40]);
add_block('simulink/Sources/In1', [subsystem '/intensite_solaire'], 'Position', [30 60 60 80]);
add_block('simulink/Sources/In1', [subsystem '/difference_temperature'], 'Position', [30 100 60 120]);
add_block('simulink/Sources/In1', [subsystem '/nomber_de_pasagere'], 'Position', [30 140 60 160]);
add_block('simulink/Sources/In1', [subsystem '/puisance_d_equipement'], 'Position', [30 180 60 200]);
add_block('simulink/Sources/In1', [subsystem '/debit_d_air'], 'Position', [30 220 60 240]);
add_block('simulink/Sources/In1', [subsystem '/temperature_intern'], 'Position', [30 260 60 280]);
add_block('simulink/Sources/In1', [subsystem '/temperature_externe'], 'Position', [30 300 60 320]);

% Qsolaire = surface_vitree * facteur_solaire * intensite_solaire
add_block('simulink/Math Operations/Gain', [subsystem '/Gain_Qsolaire'], 'Gain', num2str(5*0.6), 'Position', [100 50 150 70]);
add_line(subsystem, 'intensite_solaire/1', 'Gain_Qsolaire/1');

% Qparois = surface_parois * coefficient_transmission * difference_temperature
add_block('simulink/Math Operations/Gain', [subsystem '/Gain_Qparois'], 'Gain', num2str(10*2.5), 'Position', [100 100 150 120]);
add_line(subsystem, 'difference_temperature/1', 'Gain_Qparois/1');

% Qinterne = nomber_de_pasagere * chaleur_passager + puisance_d_equipement
add_block('simulink/Math Operations/Gain', [subsystem '/Gain_Qinterne_passager'], 'Gain', '100', 'Position', [100 150 150 170]);
add_line(subsystem, 'nomber_de_pasagere/1', 'Gain_Qinterne_passager/1');
add_block('simulink/Math Operations/Sum', [subsystem '/Sum_Qinterne'], 'Inputs', '++', 'Position', [180 170 220 200]);
add_line(subsystem, 'Gain_Qinterne_passager/1', 'Sum_Qinterne/1');
add_line(subsystem, 'puisance_d_equipement/1', 'Sum_Qinterne/2');

% Qair = (debit_d_air / 3600) * capacite_thermique_massique_air * abs(temperature_intern - temperature_externe)
add_block('simulink/Math Operations/Gain', [subsystem '/Gain_Qair_debit'], 'Gain', num2str(1/3600), 'Position', [100 250 150 270]);
add_line(subsystem, 'debit_d_air/1', 'Gain_Qair_debit/1');
add_block('simulink/Math Operations/Gain', [subsystem '/Gain_Qair_Cp'], 'Gain', '1005', 'Position', [180 250 230 270]);
add_line(subsystem, 'Gain_Qair_debit/1', 'Gain_Qair_Cp/1');
add_block('simulink/Math Operations/Sum', [subsystem '/Diff_Temp_Air'], 'Inputs', '+-', 'Position', [100 320 150 340]);
add_line(subsystem, 'temperature_intern/1', 'Diff_Temp_Air/1');
add_line(subsystem, 'temperature_externe/1', 'Diff_Temp_Air/2');
add_block('simulink/Math Operations/Abs', [subsystem '/Abs_Diff_Temp_Air'], 'Position', [180 320 230 340]);
add_line(subsystem, 'Diff_Temp_Air/1', 'Abs_Diff_Temp_Air/1');
add_block('simulink/Math Operations/Product', [subsystem '/Product_Qair'], 'Position', [260 250 300 280]);
add_line(subsystem, 'Gain_Qair_Cp/1', 'Product_Qair/1');
add_line(subsystem, 'Abs_Diff_Temp_Air/1', 'Product_Qair/2');

% Ajouter le bloc Gain pour control_signal AVANT Sum_Qtotale
add_block('simulink/Math Operations/Gain', [subsystem '/Gain_control_signal'], 'Gain', '4500', 'Position', [100 20 150 40]);
add_line(subsystem, 'control_signal/1', 'Gain_control_signal/1');

% Créer le bloc de somme (Sum_Qtotale) avec 5 entrées
add_block('simulink/Math Operations/Sum', [subsystem '/Sum_Qtotale'], 'Inputs', '+++++', 'Position', [350 150 400 180]);

% Connecter les sorties des gains/produits à Sum_Qtotale
add_line(subsystem, 'Gain_Qsolaire/1', 'Sum_Qtotale/1');
add_line(subsystem, 'Gain_Qparois/1', 'Sum_Qtotale/2');
add_line(subsystem, 'Sum_Qinterne/1', 'Sum_Qtotale/3');
add_line(subsystem, 'Product_Qair/1', 'Sum_Qtotale/4');
add_line(subsystem, 'Gain_control_signal/1', 'Sum_Qtotale/5');

% Ajouter le gain de capacité thermique et l'intégrateur
add_block('simulink/Math Operations/Gain', [subsystem '/Gain_Thermal_Capacity'], 'Gain', '0.0001', 'Position', [510 150 560 180]);
add_line(subsystem, 'Sum_Qtotale/1', 'Gain_Thermal_Capacity/1');

add_block('simulink/Continuous/Integrator', [subsystem '/TempIntegrator'], ...
    'InitialCondition', '20', 'Position', [580 150 630 180]);
add_line(subsystem, 'Gain_Thermal_Capacity/1', 'TempIntegrator/1');

% Connecter la sortie de l'intégrateur à la sortie du sous-système
add_line(subsystem, 'TempIntegrator/1', 'Out1/1');

% (Optional) Remove or disconnect Gain_puissance_clim if present
if ~isempty(find_system(subsystem, 'SearchDepth', 1, 'Name', 'Gain_puissance_clim'))
    try
        delete_block([subsystem '/Gain_puissance_clim']);
    catch
    end
end

    % Step 4: Reshape
    reshapeInputs = {'Input_u','X_min','X_max','Y_min','Y_max'};
    for i = 1:numel(reshapeInputs)
        blk = ['Reshape_' reshapeInputs{i}];
        add_block('simulink/Math Operations/Reshape', [modelName '/' blk], ...
            'Position', [150 50*i+250 190 50*i+280]);
        safeAddLine(modelName, [reshapeInputs{i} '/1'], [blk '/1']);
    end

    % Step 5: RNN Inputs
    for i = 1:numel(reshapeInputs)
        safeAddLine(modelName, ['Reshape_' reshapeInputs{i} '/1'], ...
            ['RNN_Predictor/' num2str(i)]);
    end

    % Step 6: PID
    if ~isempty(find_system(modelName,'Name','PID'))
        set_param([modelName '/PID'], ...
            'P', '0.5', 'I', '0.05', 'D', '0', ...
            'UpperSaturationLimit','1','LowerSaturationLimit','-1','LimitOutput','on');
    end
    safeAddLine(modelName,'Error_Calculation/1','PID/1');

    % Step 7: Combine RNN + PID (now as PID - RNN)
    add_block('simulink/Math Operations/Sum', [modelName '/Combine_Signals'], ...
        'Inputs', '+-', 'Position', [550 120 590 160]);
    safeAddLine(modelName,'PID/1','Combine_Signals/1');
    safeAddLine(modelName,'RNN_Predictor/1','Combine_Signals/2');
    % safeAddLine(modelName,'Combine_Signals/1','Vehicle_Dynamics/1'); % This line will be replaced

    % Step 7a: Add Manual Switch for Control Mode Selection
    add_block('simulink/Signal Routing/Manual Switch', [modelName '/Control_Mode_Switch'], ...
        'Position', [620 120 650 160]); % Positioned after Combine_Signals
    safeAddLine(modelName,'Combine_Signals/1','Control_Mode_Switch/1');
    safeAddLine(modelName,'PID/1','Control_Mode_Switch/2');
    safeAddLine(modelName,'Control_Mode_Switch/1','Vehicle_Dynamics/1'); % Connect switch output to Vehicle Dynamics

    % Step 8: Scopes and Feedback
    safeAddLine(modelName,'Reference/1','Error_Calculation/1');
    safeAddLine(modelName,'Vehicle_Dynamics/1','Error_Calculation/2');
    safeAddLine(modelName,'Vehicle_Dynamics/1','Temperature_Scope/1');
    safeAddLine(modelName,'PID/1','Control_Scope/1');

    % Step 9: Workspace Logging
    add_block('simulink/Sinks/Scope',[modelName '/Temp_Out'], ...
        'Position',[700  80 750 110]); % Replaced To Workspace with Scope
    safeAddLine(modelName,'Vehicle_Dynamics/1','Temp_Out/1');

    % Rename ToWs_Puissance_Reelle to ToWs_PID_Output and change its variable name
    % First, delete existing block if it was created with the old name to avoid error
    if ~isempty(find_system(modelName,'SearchDepth',1,'Name','ToWs_Puissance_Reelle'))
        delete_block([modelName '/ToWs_Puissance_Reelle']);
    end
    add_block('simulink/Sinks/Scope',[modelName '/ToWs_PID_Output'], ...
        'Position',[700 120 750 150]); % Replaced To Workspace with Scope
    safeAddLine(modelName,'PID/1','ToWs_PID_Output/1'); % Old safeAddLine(modelName,'PID/1','PID_Out/1'); -- wait, PID_Out is a separate block.

    % Ensure PID_Out is distinct if it serves a different purpose or rename it if it's redundant
    % Original PID_Out was:
    % add_block('simulink/Sinks/To Workspace',[modelName '/PID_Out'], ...
    %    'VariableName','pid_output','SaveFormat','StructureWithTime','Position',[700 120 750 150]);
    % safeAddLine(modelName,'PID/1','PID_Out/1');
    % This is exactly what we are modifying. So the old 'PID_Out' becomes 'ToWs_PID_Output'
    % And the old 'ToWs_Puissance_Reelle' which also logged PID/1 is now effectively removed by not adding it again.

    add_block('simulink/Sinks/Scope',[modelName '/ToWs_Puissance_Predite'], ...
        'Position',[700 160 750 190]); % Replaced To Workspace with Scope
    safeAddLine(modelName,'RNN_Predictor/1','ToWs_Puissance_Predite/1');

    % Remove the old ToWs_Puissance_Reelle block if it exists by its specific name
    if ~isempty(find_system(modelName,'SearchDepth',1,'Name','ToWs_Puissance_Reelle'))
        delete_block([modelName '/ToWs_Puissance_Reelle']);
    end
    % And remove the line that connected to it (if it was different from PID_Out's connection)
    % The original script had:
    % add_block('simulink/Sinks/To Workspace',[modelName '/ToWs_Puissance_Reelle'], ...
    % 'VariableName','puissance_reelle','SaveFormat','StructureWithTime','Position',[700 200 750 230]);
    % safeAddLine(modelName,'PID/1','ToWs_Puissance_Reelle/1');
    % This block is effectively being replaced by the new ToWs_Applied_Control_Power, but that logs the switch output.
    % The old ToWs_PID_Out is being renamed to ToWs_PID_Output.
    % So, we need to make sure we are not trying to create ToWs_Puissance_Reelle anymore.

    % Add new logger for the actual applied power (output of the switch)
    add_block('simulink/Sinks/Scope',[modelName '/ToWs_Applied_Control_Power'], ...
        'Position',[700 200 750 230]); % Replaced To Workspace with Scope
    safeAddLine(modelName,'Control_Mode_Switch/1','ToWs_Applied_Control_Power/1');

    % Step 10: Simulation Params
    set_param(modelName, 'Solver', 'ode15s', 'MaxStep', '0.01', 'StopTime', '100');
    save_system(modelName);
    open_system(modelName);
    disp('✅ Modèle généré avec succès : Toyota_CHR_Climate_Model_V2 (Adaptive Heating & Cooling)');

    % --- Add From Workspace blocks for physical effects and connect to Vehicle_Dynamics ---

    % Define the new effect names and their order for Vehicle_Dynamics (starting from port 2)
    effect_names = {'intensite_solaire', 'difference_temperature', 'nomber_de_pasagere', 'puisance_d_equipement', 'debit_d_air', 'temperature_intern', 'temperature_externe'};

    for i = 1:length(effect_names)
        blk_name = ['From_' effect_names{i}];
        add_block('simulink/Sources/From Workspace', [modelName '/' blk_name], ...
            'VariableName', effect_names{i}, ...
            'Position', [50 50*i+300 150 50*i+320]);
        % Connect to Vehicle_Dynamics input port (input ports are numbered 2 to 8, since 1 is control_signal)
        if i <= 7
            add_line(modelName, [blk_name '/1'], ['Vehicle_Dynamics/' num2str(i+1)], 'autorouting', 'on');
        end
    end

    % Set sample time for all MATLAB Function blocks to 1 second
    matlabFcnBlocks = find_system(modelName, 'BlockType', 'MATLABFcn');
    for i = 1:length(matlabFcnBlocks)
        set_param(matlabFcnBlocks{i}, 'SampleTime', '1');
    end

    % Add Scope to monitor RNN output
    add_block('simulink/Sinks/Scope', [modelName '/RNN_Output_Scope'], 'Position', [800 160 850 190]);
    add_line(modelName, 'RNN_Predictor/1', 'RNN_Output_Scope/1');

    % Add To Workspace to log RNN output
    add_block('simulink/Sinks/Scope', [modelName '/ToWs_RNN_Output'], ...
        'Position',[800 200 850 230]); % Replaced To Workspace with Scope
    add_line(modelName, 'RNN_Predictor/1', 'ToWs_RNN_Output/1');
end

% Helper Functions remain unchanged (safeDeleteBlock, safeAddLine, delete_lines)
%% --- Fonctions auxiliaires intégrées ---

% 🔧 safeDeleteBlock - Supprime un bloc s'il existe
function safeDeleteBlock(modelName, blockName)
    fullName = [modelName '/' blockName];
    if bdIsLoaded(modelName) && ~isempty(find_system(modelName, 'SearchDepth', 1, 'Name', blockName))
        try
            delete_block(fullName);
        catch ME
            warning('⚠️ Impossible de supprimer le bloc %s: %s', fullName, ME.message);
        end
    else
        disp(['ℹ️ Bloc "' blockName '" non trouvé, sauté.']);
    end
end
function delete_all_lines(blockPath)
    lines = get_param(blockPath, 'Lines');
    if isfield(lines, 'Line')
        for i = 1:numel(lines.Line)
            try
                delete_line(lines.Line(i).Handle);
            catch
                % ignore invalid lines
            end
        end
    end
end

% 🔧 safeAddLine - Évite les erreurs si la connexion existe déjà
function safeAddLine(modelName, src, dst)
    try
        add_line(modelName, src, dst, 'autorouting', 'on');
    catch
        % Ignore les erreurs de connexion en double
    end
end

% 🔧 delete_lines - Supprime toutes les connexions dans un sous-système
function delete_lines(subsystem)
    lines = get_param(subsystem, 'Lines');
    if isstruct(lines)
        for i = 1:length(lines)
            try
                delete_line(subsystem, lines(i).Name);
            catch
                continue;
            end
        end
    end
end