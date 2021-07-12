function GenBelief(
    planner::PFTDPWPlanner,
    pomdp::POMDP{S,A,O},
    b::PFTBelief{S},
    a::A
    )::Tuple{PFTBelief, O, Float64} where {S,A,O}

    rng = planner.sol.rng
    N = n_particles(b)
    weighted_return = 0.0

    p_idx = non_terminal_sample(rng, pomdp, b)

    sample_s = particle(b, p_idx)
    sample_sp, sample_obs, sample_r = @gen(:sp,:o,:r)(pomdp, sample_s, a, rng)

    return GenBelief(
        planner,
        pomdp,
        b,
        a,
        sample_obs,
        p_idx,
        sample_sp,
        sample_r
    )
end

function GenBelief(
    planner::PFTDPWPlanner,
    pomdp::POMDP{S,A,O},
    b::PFTBelief{S},
    a::A,
    o::O,
    p_idx::Int,
    sample_sp::S,
    sample_r::Float64
    ) where {S,A,O}

    rng = planner.sol.rng
    N = n_particles(b)
    weighted_return = 0.0

    bp_particles, bp_weights = gen_empty_belief(planner, N, S)
    bp_terminal_ws = 0.0

    for (i,(s,w)) in enumerate(weighted_particles(b))
        # Propagation
        if i == p_idx
            (sp, r) = sample_sp, sample_r
        else
            if !isterminal(pomdp, s)
                (sp, r) = @gen(:sp,:r)(pomdp, s, a, rng)
            else
                (sp,r) = (s, 0.0)
            end
        end

        # Reweighting
        @inbounds begin
            bp_particles[i] = sp
            w = weight(b, i)
            bp_weights[i] = w*pdf(POMDPs.observation(pomdp, s, a, sp), o)
        end

        weighted_return += r*w
    end

    if !iszero(sum(bp_weights))
        normalize!(bp_weights, 1)
    else
        fill!(bp_weights, inv(N))
    end

    bp = PFTBelief(bp_particles, bp_weights, pomdp)

    return bp::PFTBelief{S}, o::O, weighted_return::Float64
end

function gen_empty_belief(planner::PFTDPWPlanner, N::Int, ::Type{S}) where {S}
    cache = planner.cache
    cache.count += 1
    if cache.count <= cache.max_size
        return cache.particles[cache.count]::Vector{S}, cache.weights[cache.count]::Vector{Float64}
    else
        return Vector{S}(undef, N), Vector{Float64}(undef, N)
    end
end

function incremental_avg(Qhat::Float64, Q::Float64, N::Int)
    return Qhat + (Q - Qhat)/N
end
