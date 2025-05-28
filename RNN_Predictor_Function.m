function y = RNN_Predictor_Function(u, X_min, X_max, Y_min, Y_max)
%#codegen

%% Initializations for code generation
y = 0; % Initialize output

%% Protection against division by zero
epsilon = 1e-6;
range_x = X_max(:) - X_min(:);
range_x(abs(range_x) < epsilon) = epsilon;

%% Input Normalization (mapminmax from training)
x_norm = (u(:) - X_min(:)) ./ range_x;

%% Persistent delay states for RNN
persistent ai1 ai2
if isempty(ai1)
    ai1 = zeros(20, 2); % Layer 1 delay states
end
if isempty(ai2)
    ai2 = zeros(10, 2); % Layer 2 delay states
end

%% Call RNN prediction function
[y_norm, ai1, ai2] = predictRNN(x_norm, ai1, ai2);

%% Denormalize output
y = double(y_norm) * (Y_max - Y_min) + Y_min;

% Clamp output to a physically reasonable range to prevent runaway values
% Adjust the range as needed for your system
y = max(min(y, 1), -1);

end