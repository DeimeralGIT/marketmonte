# Regime Detection (Layer 1)

> **Layer 1 — Student-t Hidden Markov Model with Baum-Welch EM**
> **File:** `lib/services/regime_detection_service.dart` (class `StudentTHMM`, class `RegimeDetectionService`)
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Purpose

Classifies observed hourly log-returns into one of three discrete volatility regimes using a **Student-t Hidden Markov Model** (HMM) fitted via **Baum-Welch Expectation-Maximization** with an ECME M-step. Student-t emission distributions provide robustness to fat-tailed return distributions typical of cryptocurrency markets. Regime probabilities are further refined by blending with the Particle Filter output (70% HMM / 30% PF).

---

## 2. Three Regimes

States are re-sorted by scale (sigma) after each EM iteration so that index ordering is consistent:

| Index | Label | Description |
|-------|-------|-------------|
| 0 | Low Volatility | Calm, mean-reverting — smallest sigma |
| 1 | Medium Volatility | Trending, normal — middle sigma |
| 2 | High Volatility | Turbulent, crisis — largest sigma |

Each state has three learned parameters:
- **mu** — location (drift), shrunk toward zero by factor 0.8
- **sigma** — scale (volatility)
- **nu** — degrees of freedom (tail heaviness)

---

## 3. Model Specification

### 3.1 Emission Distribution

Each state emits observations from a Student-t distribution:

```
p(x | state=s) = StudentT(x; mu_s, sigma_s, nu_s)
```

Log-PDF:

```
log p(x | mu, sigma, nu) = logGamma((nu+1)/2)
                         - logGamma(nu/2)
                         - 0.5 * log(nu * pi)
                         - log(sigma)
                         - ((nu+1)/2) * log(1 + z^2/nu)

where z = (x - mu) / sigma
```

`logGamma` is computed via Lanczos approximation (g=7, n=9 coefficients).

### 3.2 Transition Matrix

Initial transition matrix:

```
A[i][j] = 0.7  if i == j  (self-transition)
         = 0.3 / (K-1)   otherwise

where K = 3 states
```

Learned during EM via xi-accumulation (see section 5).

### 3.3 Initial State Distribution

Uniform: `pi = [1/3, 1/3, 1/3]`.

---

## 4. Initialization

Before EM, parameters are initialized from data:

1. Sort all log-returns
2. Split into K=3 equal-sized buckets
3. For each bucket s:
   - `mu_s` = bucket mean
   - `sigma_s` = bucket standard deviation (population)
   - `nu_s` estimated from excess kurtosis: `nu = 6/kurtosis + 4` (clamped [2.5, 50])
   - If kurtosis <= 0.1, set `nu = 30` (near-Gaussian)

---

## 5. Baum-Welch EM with Student-t ECME

The model is fitted using the Baum-Welch algorithm. All forward-backward computations are performed in **log-space** for numerical stability.

### 5.1 Forward Algorithm

```
logAlpha[0][s] = log(pi_s) + log p(obs[0] | state=s)

logAlpha[t][j] = logSumExp_i(logAlpha[t-1][i] + log A[i][j])
               + log p(obs[t] | state=j)
```

### 5.2 Backward Algorithm

```
logBeta[T-1][s] = 0    (for all s)

logBeta[t][i] = logSumExp_j(log A[i][j] + log p(obs[t+1] | state=j) + logBeta[t+1][j])
```

### 5.3 E-Step

**Gamma (state occupancy):**
```
gamma[t][s] = exp(logAlpha[t][s] + logBeta[t][s] - logNormalizer)
```

**Xi (transition counts):**
```
xi[i][j] += exp(logAlpha[t][i] + log A[i][j]
              + log p(obs[t+1] | j) + logBeta[t+1][j] - logNormalizer)
```

### 5.4 M-Step (ECME for Student-t)

**Initial probabilities:**
```
pi_s = gamma[0][s] / sum(gamma[0])
```

**Transition matrix:**
```
A[i][j] = xiSum[i][j] / sum_j(xiSum[i][j])
```
Row-normalized, each element clamped to [1e-6, 1.0].

**Emission parameters (Student-t ECME):**

For each state s:

1. **Auxiliary weights:** `u_t = (nu + 1) / (nu + z_t^2)` where `z_t = (obs_t - mu_s) / sigma_s`

2. **Weighted mean (with drift shrinkage):**
   ```
   rawMean = sum(gamma[t] * u_t * obs_t) / sum(gamma[t] * u_t)
   mu_s = (1 - 0.8) * rawMean    // 0.8 drift shrinkage toward zero
   ```

3. **Weighted variance:**
   ```
   sigma_s = sqrt(sum(gamma[t] * u_t * (obs_t - mu_s)^2) / sum(gamma[t]))
   ```
   Clamped to [1e-6, infinity).

4. **Degrees of freedom (nu) via profile log-likelihood grid search:**
   ```
   nu_s = argmax_{nu in {2.5, 3, 4, 5, 7, 10, 15, 30}}
          sum_t(gamma[t][s] * log p(obs_t | mu_s, sigma_s, nu))
   ```

### 5.5 State Re-Sorting

After each EM iteration, states are re-sorted by ascending sigma so that index 0 always corresponds to the lowest-volatility regime. The transition matrix, initial probabilities, and all emission parameters are permuted accordingly.

### 5.6 Convergence

- **Max iterations:** 30
- **Tolerance:** Absolute change in log-likelihood < 1e-4 (checked after iteration 2)

---

## 6. Viterbi Decoding

After EM convergence, the most likely state sequence is recovered via the Viterbi algorithm (log-space):

```
logDelta[0][s] = log(pi_s) + log p(obs[0] | state=s)

logDelta[t][j] = max_i(logDelta[t-1][i] + log A[i][j])
               + log p(obs[t] | state=j)

psi[t][j] = argmax_i(logDelta[t-1][i] + log A[i][j])
```

Backtracking from `argmax_s(logDelta[T-1][s])` yields the state sequence.

---

## 7. HMM-PF Blending

The final regime probabilities are a **weighted blend** of HMM forward-filtered probabilities and Particle Filter (Layer 2) probabilities:

```
blendedProbs[s] = 0.7 * hmmProbs[s] + 0.3 * pfProbs[s]
```

Re-normalized to sum to 1.0. The regime with the highest blended probability is selected as the current regime.

This blending is performed in `RegimeDetectionService.detect()`.

---

## 8. Entropy and Persistence Adjustment

**Shannon entropy** of the blended regime probabilities:

```
H = -sum(p_s * ln(p_s))    for s in {0, 1, 2}
```

Used to construct the **persistence-adjusted transition matrix** A':

```
normalizedEntropy = H / ln(3)
persistenceBoost = 0.10 * (1 - normalizedEntropy)

A'[i][i] = clamp(A[i][i] + persistenceBoost, 0, 0.98)
A'[i][j] = A[i][j] / offDiagSum * (1 - A'[i][i])   for j != i
```

When the regime is **certain** (low entropy), the diagonal of A' is boosted, making regime transitions stickier. When **uncertain** (high entropy, near-uniform), no boost is applied.

A' is consumed by the Monte Carlo simulator (Layer 3) for regime-switching path generation.

---

## 9. Outputs

| Output | Type | Consumed By |
|--------|------|-------------|
| `regimeParams` | `List<RegimeParams>` (mu, sigma, nu per state) | Layer 2 (PF weights), Layer 3 (MC innovations) |
| `transitionMatrix` | `List<List<double>>` (A) | Layer 2 (PF regime transitions) |
| `persistenceMatrix` | `List<List<double>>` (A') | Layer 3 (MC regime transitions) |
| `currentRegimeProbs` | `List<double>` (blended) | Layer 3 (MC start regime sampling), Layer 4 (regime selection) |
| `currentRegime` | `int` (0/1/2) | Layer 4 (entry discount selection) |
| `stateSequence` | `List<int>` (Viterbi) | Diagnostic / display |
| `regimeEntropy` | `double` | UI display (entropy %), persistence calculation |

---

## 10. Default Behavior

If insufficient data is available (< 50 log-returns):
- Analysis returns empty result with default MEDIUM regime
- No positions are generated

---

## Configuration Constants

| Constant | Value | Description |
|----------|-------|-------------|
| HMM states (K) | 3 | LOW, MEDIUM, HIGH |
| Emission | Student-t | Heavy-tailed, ECME M-step |
| Drift shrinkage | 0.8 | Shrinks learned drift toward zero |
| nu grid | {2.5, 3, 4, 5, 7, 10, 15, 30} | Profile log-likelihood search |
| Self-transition init | 0.7 | Initial diagonal of A |
| Max EM iterations | 30 | Convergence limit |
| EM tolerance | 1e-4 | Log-likelihood convergence |
| Persistence multiplier | 0.10 | Entropy-gated diagonal boost |
| Max self-transition | 0.98 | A' diagonal cap |
| Blending ratio | 70% HMM / 30% PF | Final regime probabilities |
| Min returns required | 50 | Below this, default MEDIUM |
