module PFTDPW

using ParticleFilters # WeightedParticleBelief
using POMDPSimulators # RolloutSimulator
using POMDPPolicies
using POMDPs
using Parameters # @with_kw
using Random # Random.GLOBAL_RNG
using BeliefUpdaters # NothingUpdater
using D3Trees
using POMDPModelTools

export
    PFTDPWTree
    PFTDPWSolver
    PFTDPWPlanner

@with_kw mutable struct PFTDPWTree{S,A,O}
    Nh::Vector{Int} = Int[]
    Nha::Vector{Int} = Int[] # Number of times a history-action node has been visited
    Qha::Vector{Float64} = Float64[] # Map ba node to associated Q value

    b::Vector{WeightedParticleBelief{S}} = WeightedParticleBelief{S}[]
    b_children::Vector{Vector{Tuple{A,Int}}} = Vector{Tuple{A,Int}}[] # b_idx => [(a,ba_idx), ...]
    b_rewards::Vector{Float64} = Float64[] # Map b' node index to immediate reward associated with trajectory bao where b' = τ(bao)

    bao_children::Dict{Tuple{Int,O},Int} = Dict{Tuple{Int,O},Int}() # (ba_idx,O) => bp_idx
    ba_children::Vector{Vector{Int}} = Vector{Int}[] # Number of keys (ba_idx,O) under some ba node in ba_children (for PW)

    n_b::Int = 0
    n_ba::Int = 0

    function PFTDPWTree{S,A,O}(sz::Int) where {S,A,O}
        sz = min(sz, 100_000)
        return new(
            sizehint!(Int[], sz),
            sizehint!(Int[], sz),
            sizehint!(Float64[], sz),

            sizehint!(WeightedParticleBelief{S}[], sz),
            sizehint!(Vector{Tuple{A,Int}}[], sz),
            sizehint!(Float64[], sz),

            sizehint!(Dict{Tuple{Int,O},Int}(), sz),
            sizehint!(Vector{Int}[], sz),

            0,
            0
            )
    end
end

@with_kw struct PFTDPWSolver{RNG<:AbstractRNG, UPD <:Updater} <: Solver
    max_depth::Int = 20
    n_particles::Int = 100
    c::Float64 = 1.0
    k_o::Float64 = 10.0
    alpha_o::Float64 = 0.0 # Observation Progressive widening parameter
    k_a::Float64 = 5.0
    alpha_a::Float64 = 0.0 # Action Progressive widening parameter
    tree_queries::Int = 1_000
    max_time::Float64 = Inf # (seconds)
    rng::RNG = Random.GLOBAL_RNG # parameteric type
    updater::UPD = NothingUpdater()
    check_repeat_obs::Bool = true
end

struct RandomRollout{A} <: Policy
    actions::A
end

RandomRollout(pomdp::POMDP) = RandomRollout(actions(pomdp))

POMDPs.action(p::RandomRollout,b) = rand(p.actions)

mutable struct PFTDPWPlanner{M<:POMDP, SOL<:PFTDPWSolver, TREE<:PFTDPWTree, P<:Policy} <: Policy
    pomdp::M
    sol::SOL
    tree::TREE
    rollout_policy::P
end

PFTDPWPlanner(pomdp::POMDP,sol::PFTDPWSolver,tree::PFTDPWTree) = PFTDPWPlanner(pomdp, sol, tree, RandomRollout(pomdp))

include("ProgressiveWidening.jl")
include("Generator.jl")
include("TreeConstruction.jl")
include("main.jl")

end # module
