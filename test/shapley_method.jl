using Copulas, Distributions, Combinatorics, LinearAlgebra, Random, GlobalSensitivity
using Test, OrdinaryDiffEq

Random.seed!(1234)

function ishi(X)
    A = 7
    B = 0.1
    sin(X[1]) + A * sin(X[2])^2 + B * X[3]^4 * sin(X[1])
end

function ishi_batch(X)
    A = 7
    B = 0.1
    @. sin(X[:, 1]) + A * sin(X[:, 2])^2 + B * X[:, 3]^4 * sin(X[:, 1])
end

function linear(X)
    sum(X)
end

######################### Test ishi #########################

n_perms = -1;
n_var = 10_000;
n_outer = 1000;
n_inner = 3;
dim = 4;
margins = (Uniform(-pi, pi), Uniform(-pi, pi), Uniform(-pi, pi), Uniform(-pi, pi));
dependency_matrix = Matrix{Int}(I, dim, dim);
C = GaussianCopula(dependency_matrix);
input_distribution = SklarDist(C, margins);

method = Shapley(
    n_perms = n_perms,
    n_var = n_var,
    n_outer = n_outer,
    n_inner = n_inner);

#---> non batch
@time result = gsa(ishi, method, input_distribution, batch = false)


@test result.shapley_effects[1]≈0.43813841765976547 atol=1e-1
@test result.shapley_effects[2]≈0.44673952698721386 atol=1e-1
@test result.shapley_effects[3]≈0.11634276455093187 atol=1e-1
@test result.shapley_effects[4]≈0.0 atol=1e-1
#<---- non batch

#---> batch
result = gsa(ishi_batch, method, input_distribution, batch = true);

@test result.shapley_effects[1]≈0.44080027198796035 atol=1e-1
@test result.shapley_effects[2]≈0.43029987176805085 atol=1e-1
@test result.shapley_effects[3]≈0.12324991215327467 atol=1e-1
@test result.shapley_effects[4]≈0.0 atol=1e-1
#<--- batch

d = 3
mu = zeros(d)
sig = [1, 1, 2]
ro = 0.9
Cormat = [1 0 0; 0 1 ro; 0 ro 1]
Covmat = (sig * transpose(sig)) .* Cormat

margins = [Normal(mu[i], sig[i]) for i in 1:d]
copula = GaussianCopula((sig * transpose(sig)) .* Cormat)
input_distribution = SklarDist(copula, margins)

result = gsa(linear, method, input_distribution, batch = false)

@test result.shapley_effects[1]≈0.1017596 atol=1e-1
@test result.shapley_effects[2]≈0.4155602 atol=1e-1
@test result.shapley_effects[3]≈0.4826802 atol=1e-1

function ishi_linear(X)
    A = 7
    B = 0.1
    [sin(X[1]) + A * sin(X[2])^2 + B * X[3]^4 * sin(X[1]), A * X[1] + B * X[2]]
end

function ishi_linear_batch(X)
    A = 7
    B = 0.1
    @. [sin(X[:, 1]) + A * sin(X[:, 2])^2 + B * X[:, 3]^4 * sin(X[:, 1]), A * X[:, 1] + B * X[:, 2]]
end

n_perms = -1;
n_var = 10_000;
n_outer = 1000;
n_inner = 3;
dim = 4;
margins = (Uniform(-pi, pi), Uniform(-pi, pi), Uniform(-pi, pi), Uniform(-pi, pi));
dependency_matrix = Matrix{Int}(I, dim, dim);
C = GaussianCopula(dependency_matrix);
input_distribution = SklarDist(C, margins);


method = Shapley(n_perms = n_perms,
                 n_var = n_var,
                 n_outer = n_outer,
                 n_inner = n_inner);
result = gsa(ishi_linear, method, input_distribution, batch = false)

@test result.shapley_effects[1, :]≈[0.450531, 0.446184, 0.104663, -0.00137857] atol=1e-2
@test result.shapley_effects[2, :]≈[0.984416, -0.00046631, 0.00230789, 0.0137428] atol=1e-2

function f(du, u, p, t)
    du[1] = p[1] * u[1] - p[2] * u[1] * u[2] #prey
    du[2] = -p[3] * u[2] + p[4] * u[1] * u[2] #predator
end

u0 = [1.0; 1.0]
tspan = (0.0, 10.0)
p = [1.5, 1.0, 3.0, 1.0]
prob = ODEProblem(f, u0, tspan, p)
t = collect(range(0, stop = 10, length = 200))

f1 = let prob = prob, t = t
    function (p)
        prob1 = remake(prob; p = p)
        sol = solve(prob1, Tsit5(); saveat = t)
        return sol
    end
end

n_perms = -1;
n_var = 10_0;
n_outer = 10;
n_inner = 3;
dim = 4;
margins = (Uniform(1, 5), Uniform(1, 5), Uniform(1, 5), Uniform(1, 5));
dependency_matrix = Matrix{Int}(I, dim, dim);
C = GaussianCopula(dependency_matrix);
input_distribution = SklarDist(C, margins);
m = gsa(f1, method, input_distribution)
