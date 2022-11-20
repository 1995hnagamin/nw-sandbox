import LinearAlgebra
using Printf
import IterTools
import Statistics

#=
    NRM: ノーマル
    FIR: ほのお
    WTR: みず
    ELC: でんき
    GRS: くさ
    ICE: こおり
    FGT: かくとう
    PSN: どく
    GRD: じめん
    FLY: ひこう
    PSY: エスパー
    BUG: むし
    RCK: いわ
    GHT: ゴースト
    DRG: ドラゴン
    DRK: あく
    STL: はがね
    FRY: フェアリー
=#
ALLTYPE_ABBREVS = [ # all types
    "---",
    "NRM", "FIR", "WTR", "ELC", "GRS",
    "ICE", "FGT", "PSN", "GRD", "FLY",
    "PSY", "BUG", "RCK", "GHT", "DRG",
    "DRK", "STL", "FRY"
]
NALLTYPES = length(ALLTYPE_ABBREVS)

ALTYIDX = Dict{String, Int}()
for (i, type) in enumerate(ALLTYPE_ABBREVS)
    ALTYIDX[type] = i
end

TYPE_CHART = [
    #    N  F  W  E  G    I  F  P  G  F    P  B  R  G  D    D  S  F
    #    R  I  T  L  R    C  G  S  R  L    S  U  C  H  R    R  T  R
    #    M  R  R  C  S    E  T  N  D  Y    Y  G  K  T  G    K  L  Y

    0    0  0  0  0  0    0  0  0  0  0    0  0  0  0  0    0  0  0;

    1    1  1  1  1  1    1  1  1  1  1    1  1 .5  0  1    1 .5  1;    # NRM
    1    1 .5 .5  1  2    2  1  1  1  1    1  2 .5  1 .5    1  2  1;    # FIR
    1    1  2 .5  1 .5    1  1  1  2  1    1  1  2  1 .5    1  1  1;    # WTR
    1    1  1  2 .5 .5    1  1  1  0  2    1  1  1  1 .5    1  1  1;    # ELC
    1    1 .5  2  1 .5    1  1 .5  2 .5    1 .5  2  1 .5    1 .5  1;    # GRS

    1    1 .5 .5  1  2   .5  1  1  2  2    1  1  1  1  2    1 .5  1;    # ICE
    1    2  1  1  1  1    2  1 .5  1 .5   .5 .5  2  0  1    2  2 .5;    # FGT
    1    1  1  1  1  2    1  1 .5 .5  1    1  1 .5 .5  1    1  0  2;    # PSN
    1    1  2  1  2 .5    1  1  2  1  0    1 .5  2  1  1    1  2  1;    # GRD
    1    1  1  1 .5  2    1  2  1  1  1    1  2 .5  1  1    1 .5  1;    # FLY

    1    1  1  1  1  1    1  2  2  1  1   .5  1  1  1  1    0 .5  1;    # PSY
    1    1 .5  1  1  2    1 .5 .5  1 .5    2  1  1 .5  1    2 .5 .5;    # BUG
    1    1  2  1  1  1    2 .5  1 .5  2    1  2  1  1  1    1 .5  1;    # RCK
    1    0  1  1  1  1    1  1  1  1  1    2  1  1  2  1   .5  1  1;    # GHT
    1    1  1  1  1  1    1  1  1  1  1    1  1  1  1  2    1 .5  0;    # DRG

    1    1  1  1  1  1    1 .5  1  1  1    2  1  1  2  1   .5  1 .5;    # DRK
    1    1 .5 .5 .5  1    2  1  1  1  1    1  1  2  1  1    1 .5  2;    # STL
    1    1 .5  1  1  1    1  2 .5  1  1    1  1  1  1  2    2 .5  1     # FRY
]

TYPE_ABBREVS = [
    "---",
    "WTR", "ELC", "GRD", "FLY"
]
NTYPES = length(TYPE_ABBREVS)

M = Matrix{Float64}(undef, NTYPES, NTYPES)
for i = 1:NTYPES
    ti = ALTYIDX[TYPE_ABBREVS[i]]
    for j = 1:NTYPES
        tj = ALTYIDX[TYPE_ABBREVS[j]]
        M[i, j] = TYPE_CHART[ti, tj]
    end
end

# effectiveness of a move of type tm
eff(tm, (ty1, ty2)) = M[tm, ty1] * M[tm, ty2]

NULLT = 1
isvalid(ty) = (ty != NULLT)

teff(tm, (t1, t2, tx)) = isvalid(tx) ? eff(tm, (NULLT, tx)) : eff(tm, (t1, t2))

function maxeff((s1, s2, sx), (t1, t2, tx))
    tty = isvalid(tx) ? (NULLT, tx) : (t1, t2)
    multiplier(s) = eff(s, tty) * (s == sx ? 2 : 1.5)

    max(multiplier(s1), multiplier(s2), eff(sx, tty)*1.5)
end

sz = NTYPES * (NTYPES-1) ÷ 2 * NTYPES

CTYIDX = Dict{Tuple{Int, Int, Int}, Int}()
CTYREV = Vector{Tuple{Int,Int,Int}}(undef, sz)
for (i, ((t1, t2), tx)) in enumerate(IterTools.product(IterTools.subsets(1:NTYPES, Val{2}()), 1:NTYPES))
    CTYIDX[t1, t2, tx] = i
    CTYREV[i] = (t1, t2, tx)
end

T = ones(sz, sz) / sz

importance = ones(1, sz) / sz
cezarom = ones(1, sz) / sz
for iter = 1:100
    global importance, cezarom
    expect = Vector{Float64}(undef, sz)
    for idx in 1:sz
        (t1, t2, s) = CTYREV[idx]
        ptot = importance[CTYIDX[t1, t2, NULLT]] # no terastal
        ex = ptot * eff(s, (t1, t2))
        for tx = 1:NTYPES
            p = importance[CTYIDX[t1, t2, tx]]
            ptot += p
            ex += p * eff(s, (NULLT, tx)) # terastal tx
        end
        ex /= ptot
        expect[idx] = ex
    end
    function select((s1, s2, sx), (t1, t2))
        stab(s) = (s == sx ? 2 : 1.5)
        cands = sort([
            (stab(s1)*expect[CTYIDX[t1, t2, s1]], s1),
            (stab(s2)*expect[CTYIDX[t1, t2, s2]], s2),
            (1.5*expect[CTYIDX[t1, t2, sx]], sx)
        ], rev=true)
        return cands[1][2]
    end
    A = zeros(sz, sz)
    for j = 1:sz
        tty = CTYREV[j]
        (t1, t2, tx) = tty
        for i = 1:sz
            sty = CTYREV[i]
            (s1, s2, sx) = sty
            wst = max(1.5/8, teff(select((s1, s2, sx), (t1, t2)), tty))
            wts = max(1.5/8, teff(select((t1, t2, tx), (s1, s2)), sty))
            weight = log(2, wts/wst)
            if weight > 0
                A[i, j] = weight
            end
        end
    end
    S = zeros(sz, sz)
    for i = 1:sz
        S[i, :] = A[i, :]/sum(A[i,:])
    end
    G = 0.85*S + 0.15*T
    new_importance = importance * G
    new_cezarom = cezarom * iter / (iter + 1) + new_importance / (iter + 1)
    diff = LinearAlgebra.norm1(new_cezarom - cezarom)/sz
    println(diff)
    importance = new_importance
    cezarom = new_cezarom
    #=
    result = sort([(scores[i], ctyrev[i]) for i in 1:sz], rev=true)
    @printf("[Top 5]\n")
    for i = 1:5
        score, (t1, t2, tx) = result[i]
        if t1 == "---"
            t1, t2 = t2, t1
        end
        @printf("%02d: %s / %s (%s) ... %.10f\n", i, t1, t2, tx, score)
    end
    =#
end

scores = cezarom / maximum(cezarom) * 100
result = sort([(scores[i], CTYREV[i]) for i in 1:sz], rev=true)

@printf("[Top 30]\n")
for i = 1:30
    score, (t1, t2, tx) = result[i]
    if t1 == NULLT
        t1, t2 = t2, t1
    end
    @printf("%02d: %s / %s (%s) ... %.10f\n", i, TYPE_ABBREVS[t1], TYPE_ABBREVS[t2], TYPE_ABBREVS[tx], score)
end

open("pokerank.csv", "w") do csv
    @printf(csv, "# Type 1, Type 2, Tera Type, Score, Importance\n")
    for row in result
        score, (t1, t2, tx) = row
        imp = cezarom[CTYIDX[t1, t2, tx]]
        if t1 == NULLT
            t1, t2 = t2, t1
        end
        @printf(csv, "%s,%s,%s,%.10f,%.10f\n", TYPE_ABBREVS[t1], TYPE_ABBREVS[t2], TYPE_ABBREVS[tx], imp, score)
    end
end

ttscore = [
    [ scores[CTYIDX[t1, t2, tx]] for (t1, t2) in IterTools.subsets(1:NTYPES, Val{2}())]
    for tx in 1:NTYPES
]

ttas = sort([(Statistics.mean(ttscore[tx]), tx) for tx in 1:NTYPES], rev=true)

@printf("\n[Tera Type average score]\n")
for (score, ty) in ttas
    @printf("%s: %.10f\n", TYPE_ABBREVS[ty], score)
end

open("ttas.csv", "w") do csv
    @printf(csv, "# Tera Type, mean, std, min, 25%%, 50%%, 75%%, max\n")
    for row in ttas
        mean, tx = row
        std = Statistics.std(ttscore[tx])
        qnt = Statistics.quantile(ttscore[tx], [0.25, 0.5, 0.75])
        minm = minimum(ttscore[tx])
        maxm = maximum(ttscore[tx])
        @printf(csv, "%s,%.10f,%.10f,%.10f,%.10f,%.10f,%.10f,%.10f\n",
            TYPE_ABBREVS[tx], mean,std,minm,qnt[1],qnt[2],qnt[3],maxm)
    end
end
