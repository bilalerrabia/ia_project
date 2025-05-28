function generate_Climate_Model_V2()
    modelName = 'Toyota_CHR_Climate_Model_V2';
    % Close the model if it already exists in memory
    if bdIsLoaded(modelName)
        close_system(modelName, 0); % Close without saving
    end
    % إنشاء نموذج Simulink جديد
    new_system(modelName);
    open_system(modelName);
    
    % إضافة الكتل الأساسية
    add_block('simulink/Sources/From Workspace', [modelName '/Input_u'], ...
        'VariableName', 'u_input', 'Position', [50 50 100 80]);
    add_block('simulink/Sources/From Workspace', [modelName '/X_min'], ...
        'VariableName', 'X_min', 'Position', [50 100 100 130]);
    add_block('simulink/Sources/From Workspace', [modelName '/X_max'], ...
        'VariableName', 'X_max', 'Position', [50 150 100 180]);
    add_block('simulink/Sources/From Workspace', [modelName '/Y_min'], ...
        'VariableName', 'Y_min', 'Position', [50 200 100 230]);
    add_block('simulink/Sources/From Workspace', [modelName '/Y_max'], ...
        'VariableName', 'Y_max', 'Position', [50 250 100 280]);
    
    % إضافة كتلة RNN
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
        [modelName '/RNN_Predictor'], 'Position', [300 150 400 200]);
    
    % إضافة PID
    add_block('simulink/Continuous/PID Controller', [modelName '/PID'], ...
        'Position', [300 250 400 300]);
    
    % حفظ النموذج
    save_system(modelName);
    disp('✅ النموذج الأولي تم إنشاؤه بنجاح');
end