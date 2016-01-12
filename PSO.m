function [xBest, fBest, info, dataLog] = PSO(objFun, x0, xLow, xUpp, options)
% [xBest, fBest, info, dataLog] = PSO(objFun, x0, xLow, xUpp, options)
%
% Particle Swarm Optimization
%
% This function minimizes OBJFUN using a variant of particle swarm
% optimization. The optimization uses an initial guess X0, and searches
% over a search space bounded by XLOW and XUPP.
%
% INPUTS:
%   objFun = objective function handle:
%       f = objFun(x)
%           x = [n, m] = search point in n-dimensional space (for m points)
%           f = [1, m] = objective function value, for each of m points
%   x0 = [n, 1] = initial search location
%   xLow = [n, 1] = lower bounds on search space
%   xUpp = [n, 1] = upper bounds on search space
%   options = option struct. All fields are optional, with defaults:
%       .alpha = 0.6 = search weight on current search direction
%       .beta = 0.9 = search weight on global best
%       .gamma = 0.9 = search weight on local best
%       .nPopulation = m = 3*n = population count
%       .maxIter = 100 = maximum number of generations
%       .flagMinimize = true = minimize objective
%           --> Set to false to maximize objective
%       .guessWeight = 0.5;  trade-off for initialization; range (0.1,0.9)
%           --> 0.1  heavy weight on initial guess (x0)
%           --> 0.9  heavy weight on random initialization [xLow, xUpp]
%       .plotFun = function handle for plotting progress
%           plotFun( dataLog(iter), iter )
%           --> See OUTPUTS for details about dataLog
%           --> Leave empty to omit plotting (faster)
%
% OUTPUTS:
%   xBest = [n, 1] = best point ever found
%   fBest = [1, 1] = value of best point found
%   info = output struct with solver info
%       .input = copy of solver inputs:
%           .objFun
%           .x0
%           .xLow
%           .xUpp
%           .options
%       .exitFlag = how did optimization finish
%           1 = reached max iteration count
%       .X_Global = [n,iter] = best point in each generation
%       .F_Global = [1,iter] = value of the best point ever
%       .I_Global = [1,iter] = index of the best point ever
%       .X_Best_Var = [n,iter] = variance in best point along each dim
%       .X_Var = [n,iter] = variance in current search along each dim
%       .X_Best_Mean = [n,iter] = mean in best point along each dim
%       .X_Mean = [n,iter] = mean in current search along each dim
%       .F_Best_Var = [1,iter] = variance in the best val at each gen
%       .F_Var = [1,iter] = variance in the current val at each gen
%       .F_Best_Mean = [1,iter] = mean of the population best value
%       .F_Mean = [1,iter] = mean of the current population value
%
%
%   dataLog(iter) = struct array with data from each iteration
%       .X = [n,m] = current position of each particle
%       .V = [n,m] = current "velocity" of each particle
%       .F = [1,m] = value of each particle
%       .X_Best = [n,m] = best point for each particle
%       .F_Best = [1,m] = value of the best point for each particle
%       .X_Global = [n,1] = best point ever (over all particles)
%       .F_Global = [1,1] = value of the best point ever
%       .I_Global = [1,1] = index of the best point ever
%
% Dependencies:
%   --> mergeOptions()
%   --> makeStruct()
%
% References:
%   
%   http://www.scholarpedia.org/article/Particle_swarm_optimization
%
%   Clerc and Kennedy (2002)


%%%% Basic input validation:
[n, m] = size(x0);
if m ~= 1
    error('x0 is not a valid size! Must be a column vector.')
end
[nRow, nCol] = size(xLow);
if nRow ~= n || nCol ~= 1
    error(['xLow is not a valid size! Must be [' num2str(n) ', 1]']);
end
[nRow, nCol] = size(xUpp);
if nRow ~= n || nCol ~= 1
    error(['xUpp is not a valid size! Must be [' num2str(n) ', 1]']);
end


%%%% Options Struct:
default.alpha = 0.6; %search weight on current search direction
default.beta = 0.9; %search weight on global best
default.gamma = 0.9; %search weight on local best
default.nPopulation = 3*n; % 3*n = population count
default.maxIter = 100; % maximum number of generations
default.xDelMax = xUpp - xLow;  %Maximnum position update;
default.guessWeight = 0.5;  % on range (0.1, 0.9);  0 = ignore guess,  1 = start at guess
default.plotFun = [];   % Handle to a function for plotting the progress
default.flagMinimize = true;  %true for minimization, false for maximization
if nargin == 5  % user provided options struct!
    options = mergeOptions(default,options);
else  % no user-defined options. Use defaults.
    options = default;
end


%%% Options validation:
if options.guessWeight < 0.1
    options.guessWeight = 0.1;
    disp('WARNING: options.guessWeight must be on range (0.1, 0.9)');
elseif options.guessWeight > 0.9
    options.guessWeight = 0.9;
    disp('WARNING: options.guessWeight must be on range (0.1, 0.9)');
end


%%%% Minimize vs Maximize:
if options.flagMinimize
    optFun = @min;
else
    optFun = @max;
end


%%%% Initialize the population

% Sample two random points in the search space for each particle
m = options.nPopulation;  %population size
X1 = xLow*ones(1,m) + ((xUpp-xLow)*ones(1,m)).*rand(n,m);
X2 = xLow*ones(1,m) + ((xUpp-xLow)*ones(1,m)).*rand(n,m);

% Move initial points towards initial guess, by convex combination
w = options.guessWeight;  %for initialization
X0 = x0*ones(1,m);
X1 = w*X0 + (1-w)*X1;
X2 = w*X0 + (1-w)*X2;

% Bounds on search position and updates:
X_Low = xLow*ones(1,m);
X_Upp = xUpp*ones(1,m);

% Initialize population:
X = X1;     % Initial position of the population
V = X2-X1;  % Initial "velocity" of the population
F = objFun(X);  % Function value at each particle in the population

X_Best = X;  % Best point, for each particle in the population
F_Best = F;  % Value of best point, for each particle in the population

[F_Global, I_Global] = optFun(F_Best); % Value of best point ever, over all points
X_Global = X(:, I_Global); % Best point ever, over all  points


%%%% Allocate memory for the dataLog
maxIter = options.maxIter;
dataLog(maxIter) = makeStruct(X, V, F, X_Best, F_Best, X_Global, F_Global, I_Global);


%%%% Allocate memory for info
info.X_Global = zeros(n,maxIter);
info.F_Global = zeros(1,maxIter);
info.I_Global = zeros(1,maxIter);
info.X_Best_Var = zeros(n,maxIter);
info.F_Best_Var = zeros(1,maxIter);
info.X_Best_Mean = zeros(n,maxIter);
info.F_Best_Mean = zeros(1,maxIter);
info.X_Var = zeros(n,maxIter);
info.F_Var = zeros(1,maxIter);
info.X_Mean = zeros(n,maxIter);
info.F_Mean = zeros(1,maxIter);
info.iter = 1:maxIter;

%%%% MAIN LOOP:
for iter = 1:maxIter
    
    %%% Compute new generation of points:
    if iter > 1   % Then do an update on each particle
        
        r1 = rand(n,m);
        r2 = rand(n,m);
        V =  ...   %Update equations
            options.alpha*V + ...    % Current search direction
            options.beta*r1.*((X_Global*ones(1,m))-X) + ...  % Global direction
            options.gamma*r2.*(X_Best-X);    % Local best direction
        X_New = X + V;  % Update position
        X = max(min(X_New, X_Upp), X_Low);   % Clamp position to bounds  
        
        F = objFun(X);   %Evaluate
        
        F_Best_New = optFun(F_Best, F);   %Compute the best point
        idxUpdate = F_Best_New ~= F_Best;  % Which indicies updated?
        X_Best(:,idxUpdate) = X(:,idxUpdate);  %Copy over new best points
        F_Best = F_Best_New;
        [F_Global, I_Global] = optFun(F_Best); % Value of best point ever, over all points
        X_Global = X(:, I_Global); % Best point ever, over all  points
        
    end
    
    %%% Log Data
    dataLog(iter) = makeStruct(X, V, F, X_Best, F_Best, X_Global, F_Global, I_Global);
    info.X_Global(:,iter) = X_Global;
    info.F_Global(iter) = F_Global;
    info.I_Global(iter) = I_Global;
    info.X_Var(:,iter) = var(X, 0, 2);
    info.X_Best_Var(:,iter) = var(X_Best, 0, 2);
    info.X_Mean(:,iter) = mean(X, 2);
    info.X_Best_Mean(:,iter) = mean(X_Best, 2);
    info.F_Var(1,iter) = var(F);
    info.F_Best_Var(1,iter) = var(F_Best);
    info.F_Mean(1,iter) = mean(F);
    info.F_Best_Mean(1,iter) = mean(F_Best);
    
    %%% Plot
    if ~isempty(options.plotFun)
        options.plotFun(dataLog(iter), iter);
    end
    
end

xBest = info.X_Global(:,end);
fBest = info.F_Global(end);
info.exitFlag = 1;   %1 == reached maximum iteration
info.input = makeStruct(objFun, x0, xLow, xUpp, options);  %Copy inputs

end






