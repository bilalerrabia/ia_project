clc; clear; close all;

%% === Étape 1 : Charger les données ===
disp('Etape 1/5 : Chargement des données...');
try
    data_path = 'toyota_chr_energy_consumption.csv';
    data = readtable(data_path, 'VariableNamingRule', 'preserve');
    disp('Noms de colonnes chargés :');
    disp(data.Properties.VariableNames);
    % Injecter la puissance réelle dans Simulink (pour comparaison future)
assignin('base', 'puissance_reelle', struct('time', (0:height(data)-1)', ...
    'signals', struct('values', data.puissance_climatisation, 'dimensions', 1)));

catch
    error('Echec du chargement des données. Verifiez le chemin du fichier.');
end

% Définir les variables d'entrée et la cible
input_vars = {'debit d''air', 'temperature intern', 'nomber de pasagere', ...
              'temperature conssigne', 'intensite solaire', 'puisance d''equipement', ...
              'mass d''air', 'vitesse de voiture', 'temperature externe', ...
              'humidite', 'difference_temperature', 'Qsolaire', ...
              'Qparois', 'Qinterne', 'Qair', 'Qtotale'};
X = data{:, input_vars}';
Y = data.('puissance_climatisation')';


%% === Étape 2 : Normalisation et injection dans Simulink ===
disp('Etape 2/5 : Normalisation des données...');
X_min = min(X, [], 2);
X_max = max(X, [], 2);
Y_min = min(Y);
Y_max = max(Y);

% Normalisation
X_norm = (X - X_min) ./ (X_max - X_min);
Y_norm = (Y - Y_min) / (Y_max - Y_min);

X_seq = con2seq(X_norm);
Y_seq = con2seq(Y_norm);

% Injection au format From Workspace (Simulink)
assignin('base', 'u_input', struct('time', 0, 'signals', struct('values', X(:,1)', 'dimensions', 16)));
assignin('base', 'X_min', struct('time', 0, 'signals', struct('values', X_min', 'dimensions', 16)));
assignin('base', 'X_max', struct('time', 0, 'signals', struct('values', X_max', 'dimensions', 16)));
assignin('base', 'Y_min', struct('time', 0, 'signals', struct('values', Y_min, 'dimensions', 1)));
assignin('base', 'Y_max', struct('time', 0, 'signals', struct('values', Y_max, 'dimensions', 1)));

disp('\u2714\ufe0f Paramètres injectés dans Simulink.');

%% === Étape 3 : Entraînement du RNN ===
disp('Etape 3/5 : Entrainement du RNN...');
net = layrecnet(1:2, [20 10]);
net.trainFcn = 'trainlm';
net.performFcn = 'mse';
net.divideParam.trainRatio = 0.7;
net.divideParam.valRatio = 0.15;
net.divideParam.testRatio = 0.15;

[net, tr] = train(net, X_seq, Y_seq);

% Sauvegarde
save('climate_control_model.mat', 'net', 'X_min', 'X_max', 'Y_min', 'Y_max');
disp('\u2714\ufe0f Modèle RNN sauvegardé.');

%% === Étape 4 : Génération de la fonction pour Simulink ===
disp('Etape 4/5 : Generation de la fonction pour Simulink...');
genFunction(net, 'predictRNN', 'MatrixOnly', 'yes');
disp('\u2714\ufe0f Fonction predictRNN.m générée.');

%% === Étape 5 : Création du modèle Simulink (Partie 1) ===
disp('Etape 5/5 : Lancement de la generation du modèle...');
generate_Climate_Model_V2();

disp('\u27a1\ufe0f Ensuite, exécute la commande suivante : generate_Climate_Model_Part2();');