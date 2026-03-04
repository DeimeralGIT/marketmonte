import 'dart:math';

/// ─────────────────────────────────────────────────────────────────────────────
/// Regime Detection Service — Student-t HMM + Particle Filter Engine
/// ─────────────────────────────────────────────────────────────────────────────
/// Implements:
///   1. Hidden Markov Model with Student-t emissions and Baum-Welch EM
///   2. Particle Filter for real-time volatility adaptation
///   3. Regime persistence adjustment via entropy
///   4. Regime-aware State-Space Monte Carlo with Student-t innovations
///      and full path tracking (max/min/drawdown for barrier pricing)
///
/// Three volatility regimes:
///   0 = Low volatility  (calm / mean-reverting)
///   1 = Medium volatility (trending / normal)
///   2 = High volatility  (crisis / turbulent)
/// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════════
// Mathematical utilities
// ═══════════════════════════════════════════════════════════════════════════════

/// Log-gamma via Lanczos approximation (g = 7, n = 9).
double _logGamma(double z) {
  const coeffs = <double>[
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (z < 0.5) {
    return log(pi / sin(pi * z)) - _logGamma(1 - z);
  }
  final w = z - 1.0;
  double x = coeffs[0];
  for (int i = 1; i < coeffs.length; i++) {
    x += coeffs[i] / (w + i);
  }
  final t = w + 7.5; // g + 0.5
  return 0.5 * log(2 * pi) + (w + 0.5) * log(t) - t + log(x);
}

/// Log-PDF of the Student-t distribution.
///   x   – observation
///   mu  – location
///   s   – scale (> 0)
///   nu  – degrees of freedom (> 2)
double _logStudentT(double x, double mu, double s, double nu) {
  final sigma = s.clamp(1e-8, double.infinity);
  final z = (x - mu) / sigma;
  return _logGamma((nu + 1) / 2) -
      _logGamma(nu / 2) -
      0.5 * log(nu * pi) -
      log(sigma) -
      ((nu + 1) / 2) * log(1 + z * z / nu);
}

/// Standard-normal variate via Box-Muller.
double _normalRandom(Random rng) {
  final u1 = rng.nextDouble().clamp(1e-15, 1.0);
  final u2 = rng.nextDouble();
  return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
}

/// Gamma(shape, 1) variate via Marsaglia-Tsang (shape ≥ 1).
double _gammaRandom(double shape, Random rng) {
  if (shape < 1.0) {
    return _gammaRandom(shape + 1.0, rng) *
        pow(rng.nextDouble().clamp(1e-15, 1.0), 1.0 / shape);
  }
  final d = shape - 1.0 / 3.0;
  final c = 1.0 / sqrt(9.0 * d);
  while (true) {
    double x, v;
    do {
      x = _normalRandom(rng);
      v = 1.0 + c * x;
    } while (v <= 0);
    v = v * v * v;
    final u = rng.nextDouble();
    if (u < 1.0 - 0.0331 * (x * x) * (x * x)) return d * v;
    if (log(u.clamp(1e-300, 1.0)) < 0.5 * x * x + d * (1 - v + log(v))) {
      return d * v;
    }
  }
}

/// Student-t variate: T = Z × √(ν / χ²(ν)) where χ² = 2 Gamma(ν/2).
double _studentTRandom(double nu, Random rng) {
  final z = _normalRandom(rng);
  final chi2 = 2.0 * _gammaRandom(nu / 2.0, rng);
  return z * sqrt(nu / chi2.clamp(1e-15, double.infinity));
}

/// Log-sum-exp for numerical stability.
double _logSumExp(List<double> values) {
  final maxVal = values.reduce(max);
  if (maxVal == double.negativeInfinity) return double.negativeInfinity;
  double sumExp = 0.0;
  for (final v in values) {
    sumExp += exp(v - maxVal);
  }
  return maxVal + log(sumExp);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data classes
// ═══════════════════════════════════════════════════════════════════════════════

/// Parameters for each HMM regime.
class RegimeParams {
  final double mean; // location (μ)
  final double std; // scale (σ)
  final double nu; // degrees of freedom (ν, > 2)

  const RegimeParams({required this.mean, required this.std, required this.nu});

  @override
  String toString() =>
      'RegimeParams(μ=${mean.toStringAsFixed(6)}, '
      'σ=${std.toStringAsFixed(6)}, ν=${nu.toStringAsFixed(2)})';
}

/// Per-path simulation result for barrier pricing.
class PathResult {
  final double finalPrice;
  final double maxPrice;
  final double minPrice;
  final double maxDrawdown; // max peak-to-trough as fraction

  const PathResult({
    required this.finalPrice,
    required this.maxPrice,
    required this.minPrice,
    required this.maxDrawdown,
  });
}

/// Full result from the HMM + Particle Filter pipeline.
class RegimeDetectionResult {
  final List<RegimeParams> regimeParams;
  final List<List<double>> transitionMatrix;
  final List<List<double>> persistenceMatrix; // A' with sticky boost
  final List<double> currentRegimeProbs;
  final int currentRegime;
  final List<int> stateSequence;
  final List<double> initialProbs;
  final double regimeEntropy;

  const RegimeDetectionResult({
    required this.regimeParams,
    required this.transitionMatrix,
    required this.persistenceMatrix,
    required this.currentRegimeProbs,
    required this.currentRegime,
    required this.stateSequence,
    required this.initialProbs,
    required this.regimeEntropy,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hidden Markov Model — Student-t emissions, Baum-Welch (EM)
// ═══════════════════════════════════════════════════════════════════════════════

class StudentTHMM {
  final int nStates;
  late List<double> initProbs;
  late List<List<double>> A; // transition matrix
  late List<double> means;
  late List<double> stds;
  late List<double> nus; // degrees of freedom per state

  /// Drift shrinkage toward zero (0 = no shrinkage, 1 = force zero drift).
  final double driftShrinkage;

  StudentTHMM({this.nStates = 3, this.driftShrinkage = 0.8});

  /// Grid of ν values to search during M-step.
  static const _nuGrid = <double>[2.5, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0, 30.0];

  /// Initialise parameters from data.
  void initialise(List<double> observations) {
    final sorted = List<double>.from(observations)..sort();
    final n = sorted.length;

    means = List<double>.filled(nStates, 0.0);
    stds = List<double>.filled(nStates, 0.0);
    nus = List<double>.filled(nStates, 5.0); // default ν

    for (int s = 0; s < nStates; s++) {
      final start = (n * s / nStates).floor();
      final end = (n * (s + 1) / nStates).floor();
      final bucket = sorted.sublist(start, end);
      final m = bucket.reduce((a, b) => a + b) / bucket.length;
      final v =
          bucket.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) /
          bucket.length;
      means[s] = m;
      stds[s] = sqrt(v).clamp(1e-6, double.infinity);

      // Estimate ν from excess kurtosis: kurtosis = 6/(ν-4) for ν>4
      if (bucket.length > 10) {
        final std4 = stds[s] * stds[s] * stds[s] * stds[s];
        if (std4 > 1e-30) {
          final m4 =
              bucket.map((x) => pow(x - m, 4)).reduce((a, b) => a + b) /
              bucket.length;
          final kurt = m4 / std4 - 3.0; // excess kurtosis
          if (kurt > 0.1) {
            nus[s] = (6.0 / kurt + 4.0).clamp(2.5, 50.0);
          } else {
            nus[s] = 30.0; // near-Gaussian
          }
        }
      }
    }

    initProbs = List<double>.filled(nStates, 1.0 / nStates);
    A = List.generate(nStates, (i) {
      return List.generate(nStates, (j) => i == j ? 0.7 : 0.3 / (nStates - 1));
    });
  }

  // ── Forward algorithm (log-space) ────────────────────────────────
  List<List<double>> _forward(List<double> obs) {
    final T = obs.length;
    final logAlpha = List.generate(
      T,
      (_) => List<double>.filled(nStates, double.negativeInfinity),
    );

    for (int s = 0; s < nStates; s++) {
      logAlpha[0][s] =
          log(initProbs[s].clamp(1e-300, 1.0)) +
          _logStudentT(obs[0], means[s], stds[s], nus[s]);
    }

    for (int t = 1; t < T; t++) {
      for (int j = 0; j < nStates; j++) {
        final terms = <double>[];
        for (int i = 0; i < nStates; i++) {
          terms.add(logAlpha[t - 1][i] + log(A[i][j].clamp(1e-300, 1.0)));
        }
        logAlpha[t][j] =
            _logSumExp(terms) + _logStudentT(obs[t], means[j], stds[j], nus[j]);
      }
    }
    return logAlpha;
  }

  // ── Backward algorithm (log-space) ───────────────────────────────
  List<List<double>> _backward(List<double> obs) {
    final T = obs.length;
    final logBeta = List.generate(
      T,
      (_) => List<double>.filled(nStates, double.negativeInfinity),
    );

    for (int s = 0; s < nStates; s++) {
      logBeta[T - 1][s] = 0.0;
    }

    for (int t = T - 2; t >= 0; t--) {
      for (int i = 0; i < nStates; i++) {
        final terms = <double>[];
        for (int j = 0; j < nStates; j++) {
          terms.add(
            log(A[i][j].clamp(1e-300, 1.0)) +
                _logStudentT(obs[t + 1], means[j], stds[j], nus[j]) +
                logBeta[t + 1][j],
          );
        }
        logBeta[t][i] = _logSumExp(terms);
      }
    }
    return logBeta;
  }

  // ── Baum-Welch (EM) with Student-t ECME ──────────────────────────
  void fit(List<double> observations, {int maxIter = 30, double tol = 1e-4}) {
    initialise(observations);
    final T = observations.length;
    double prevLogLik = double.negativeInfinity;

    for (int iter = 0; iter < maxIter; iter++) {
      final logAlpha = _forward(observations);
      final logBeta = _backward(observations);

      final logLik = _logSumExp(logAlpha[T - 1]);
      if ((logLik - prevLogLik).abs() < tol && iter > 2) break;
      prevLogLik = logLik;

      // ── E-step: γ[t][s] and ξ accumulation ──
      final gamma = List.generate(T, (_) => List<double>.filled(nStates, 0.0));
      for (int t = 0; t < T; t++) {
        final logGammaRaw = <double>[];
        for (int s = 0; s < nStates; s++) {
          logGammaRaw.add(logAlpha[t][s] + logBeta[t][s]);
        }
        final logNorm = _logSumExp(logGammaRaw);
        for (int s = 0; s < nStates; s++) {
          gamma[t][s] = exp(logGammaRaw[s] - logNorm).clamp(1e-300, 1.0);
        }
      }

      final xiSum = List.generate(
        nStates,
        (_) => List<double>.filled(nStates, 0.0),
      );
      for (int t = 0; t < T - 1; t++) {
        final logTerms = <List<double>>[];
        final allTerms = <double>[];
        for (int i = 0; i < nStates; i++) {
          for (int j = 0; j < nStates; j++) {
            final v =
                logAlpha[t][i] +
                log(A[i][j].clamp(1e-300, 1.0)) +
                _logStudentT(observations[t + 1], means[j], stds[j], nus[j]) +
                logBeta[t + 1][j];
            logTerms.add([i.toDouble(), j.toDouble(), v]);
            allTerms.add(v);
          }
        }
        final logNorm = _logSumExp(allTerms);
        for (final term in logTerms) {
          xiSum[term[0].toInt()][term[1].toInt()] += exp(
            term[2] - logNorm,
          ).clamp(0, 1.0);
        }
      }

      // ── M-step ──

      // Update π
      double piSum = 0.0;
      for (int s = 0; s < nStates; s++) {
        piSum += gamma[0][s];
      }
      for (int s = 0; s < nStates; s++) {
        initProbs[s] = (gamma[0][s] / piSum).clamp(1e-6, 1.0);
      }

      // Update A
      for (int i = 0; i < nStates; i++) {
        double rowSum = 0.0;
        for (int j = 0; j < nStates; j++) {
          rowSum += xiSum[i][j];
        }
        for (int j = 0; j < nStates; j++) {
          A[i][j] = rowSum > 0
              ? (xiSum[i][j] / rowSum).clamp(1e-6, 1.0)
              : 1.0 / nStates;
        }
        final rSum = A[i].reduce((a, b) => a + b);
        for (int j = 0; j < nStates; j++) {
          A[i][j] /= rSum;
        }
      }

      // Update emission parameters with Student-t ECME
      for (int s = 0; s < nStates; s++) {
        // Compute auxiliary weights ũ_tk = (ν+1) / (ν + z²)
        final uWeights = List<double>.filled(T, 0.0);
        for (int t = 0; t < T; t++) {
          final z =
              (observations[t] - means[s]) /
              stds[s].clamp(1e-8, double.infinity);
          uWeights[t] = (nus[s] + 1) / (nus[s] + z * z);
        }

        // Weighted mean (with drift shrinkage toward 0)
        double gammaUSum = 0.0;
        double gammaUXSum = 0.0;
        for (int t = 0; t < T; t++) {
          gammaUSum += gamma[t][s] * uWeights[t];
          gammaUXSum += gamma[t][s] * uWeights[t] * observations[t];
        }
        final rawMean = gammaUSum > 0 ? gammaUXSum / gammaUSum : means[s];
        means[s] = (1 - driftShrinkage) * rawMean; // shrink toward 0

        // Weighted variance
        double gammaSum = 0.0;
        double gammaUVarSum = 0.0;
        for (int t = 0; t < T; t++) {
          gammaSum += gamma[t][s];
          gammaUVarSum +=
              gamma[t][s] *
              uWeights[t] *
              (observations[t] - means[s]) *
              (observations[t] - means[s]);
        }
        stds[s] = gammaSum > 0
            ? sqrt(gammaUVarSum / gammaSum).clamp(1e-6, double.infinity)
            : stds[s];

        // Grid search for ν (profile log-likelihood)
        double bestNuLL = double.negativeInfinity;
        double bestNu = nus[s];
        for (final nuCandidate in _nuGrid) {
          double ll = 0.0;
          for (int t = 0; t < T; t++) {
            ll +=
                gamma[t][s] *
                _logStudentT(observations[t], means[s], stds[s], nuCandidate);
          }
          if (ll > bestNuLL) {
            bestNuLL = ll;
            bestNu = nuCandidate;
          }
        }
        nus[s] = bestNu;
      }

      _sortRegimesByVolatility();
    }
  }

  /// Re-order states so index 0 = lowest vol → consistent labelling.
  void _sortRegimesByVolatility() {
    final indices = List.generate(nStates, (i) => i);
    indices.sort((a, b) => stds[a].compareTo(stds[b]));

    bool sorted = true;
    for (int i = 0; i < nStates; i++) {
      if (indices[i] != i) {
        sorted = false;
        break;
      }
    }
    if (sorted) return;

    final newMeans = List<double>.from(means);
    final newStds = List<double>.from(stds);
    final newNus = List<double>.from(nus);
    final newPi = List<double>.from(initProbs);
    final newA = List.generate(
      nStates,
      (_) => List<double>.filled(nStates, 0.0),
    );

    for (int newI = 0; newI < nStates; newI++) {
      final oldI = indices[newI];
      newMeans[newI] = means[oldI];
      newStds[newI] = stds[oldI];
      newNus[newI] = nus[oldI];
      newPi[newI] = initProbs[oldI];
      for (int newJ = 0; newJ < nStates; newJ++) {
        newA[newI][newJ] = A[indices[newI]][indices[newJ]];
      }
    }
    means = newMeans;
    stds = newStds;
    nus = newNus;
    initProbs = newPi;
    A = newA;
  }

  // ── Viterbi decoding ─────────────────────────────────────────────
  List<int> viterbi(List<double> observations) {
    final T = observations.length;
    final logDelta = List.generate(
      T,
      (_) => List<double>.filled(nStates, double.negativeInfinity),
    );
    final psi = List.generate(T, (_) => List<int>.filled(nStates, 0));

    for (int s = 0; s < nStates; s++) {
      logDelta[0][s] =
          log(initProbs[s].clamp(1e-300, 1.0)) +
          _logStudentT(observations[0], means[s], stds[s], nus[s]);
    }

    for (int t = 1; t < T; t++) {
      for (int j = 0; j < nStates; j++) {
        double bestVal = double.negativeInfinity;
        int bestI = 0;
        for (int i = 0; i < nStates; i++) {
          final v = logDelta[t - 1][i] + log(A[i][j].clamp(1e-300, 1.0));
          if (v > bestVal) {
            bestVal = v;
            bestI = i;
          }
        }
        logDelta[t][j] =
            bestVal + _logStudentT(observations[t], means[j], stds[j], nus[j]);
        psi[t][j] = bestI;
      }
    }

    final states = List<int>.filled(T, 0);
    double bestFinal = double.negativeInfinity;
    for (int s = 0; s < nStates; s++) {
      if (logDelta[T - 1][s] > bestFinal) {
        bestFinal = logDelta[T - 1][s];
        states[T - 1] = s;
      }
    }
    for (int t = T - 2; t >= 0; t--) {
      states[t] = psi[t + 1][states[t + 1]];
    }
    return states;
  }

  /// Get filtered state probabilities from the last forward time-step.
  List<double> currentStateProbabilities(List<double> observations) {
    final logAlpha = _forward(observations);
    final T = observations.length;
    final lastAlpha = logAlpha[T - 1];
    final logNorm = _logSumExp(lastAlpha);
    return List.generate(nStates, (s) {
      return exp(lastAlpha[s] - logNorm).clamp(0.0, 1.0);
    });
  }

  List<RegimeParams> get regimeParameters {
    return List.generate(nStates, (s) {
      return RegimeParams(mean: means[s], std: stds[s], nu: nus[s]);
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Particle Filter (volatility adaptation, Student-t weights)
// ═══════════════════════════════════════════════════════════════════════════════

class _Particle {
  int regime;
  double volScale;
  double weight;

  _Particle({required this.regime, this.volScale = 1.0, this.weight = 1.0});

  _Particle copy() =>
      _Particle(regime: regime, volScale: volScale, weight: weight);
}

class ParticleFilter {
  final int nParticles;
  final int nStates;
  final List<List<double>> transitionMatrix;
  final List<double> regimeMeans;
  final List<double> regimeStds;
  final List<double> regimeNus;
  final Random _rng;

  late List<_Particle> _particles;

  ParticleFilter({
    this.nParticles = 500,
    required this.nStates,
    required this.transitionMatrix,
    required this.regimeMeans,
    required this.regimeStds,
    required this.regimeNus,
    int seed = 42,
  }) : _rng = Random(seed) {
    _initParticles();
  }

  void _initParticles() {
    _particles = List.generate(nParticles, (i) {
      return _Particle(
        regime: i % nStates,
        volScale: 1.0,
        weight: 1.0 / nParticles,
      );
    });
  }

  /// Update particles with a new observation (log-return).
  void update(double observation) {
    // 1. Propagate: regime transition + volScale evolution
    for (final p in _particles) {
      // Regime transition
      final u = _rng.nextDouble();
      double cumProb = 0.0;
      for (int j = 0; j < nStates; j++) {
        cumProb += transitionMatrix[p.regime][j];
        if (u <= cumProb) {
          p.regime = j;
          break;
        }
      }

      // Vol scale evolution (mean-reverting to 1.0)
      p.volScale = (0.92 * p.volScale + 0.08 * 1.0 + 0.03 * _normalRandom(_rng))
          .clamp(0.5, 2.5);
    }

    // 2. Weight using Student-t likelihood
    double maxLogW = double.negativeInfinity;
    final logWeights = <double>[];
    for (final p in _particles) {
      final mu = regimeMeans[p.regime];
      final sigma = (regimeStds[p.regime] * p.volScale).clamp(
        1e-8,
        double.infinity,
      );
      final nu = regimeNus[p.regime];
      final logW =
          log(p.weight.clamp(1e-300, double.infinity)) +
          _logStudentT(observation, mu, sigma, nu);
      logWeights.add(logW);
      if (logW > maxLogW) maxLogW = logW;
    }

    double sumW = 0.0;
    for (int i = 0; i < nParticles; i++) {
      _particles[i].weight = exp(logWeights[i] - maxLogW);
      sumW += _particles[i].weight;
    }
    for (final p in _particles) {
      p.weight /= sumW;
    }

    // 3. Resample if ESS too low
    if (_effectiveSampleSize() < nParticles * 0.5) {
      _systematicResample();
    }
  }

  double _effectiveSampleSize() {
    double sumSqW = 0.0;
    for (final p in _particles) {
      sumSqW += p.weight * p.weight;
    }
    return sumSqW > 0 ? 1.0 / sumSqW : 0.0;
  }

  void _systematicResample() {
    final cumWeights = <double>[];
    double cum = 0.0;
    for (final p in _particles) {
      cum += p.weight;
      cumWeights.add(cum);
    }

    final newParticles = <_Particle>[];
    final step = 1.0 / nParticles;
    var u = _rng.nextDouble() * step;

    int j = 0;
    for (int i = 0; i < nParticles; i++) {
      while (j < nParticles - 1 && cumWeights[j] < u) {
        j++;
      }
      final np = _particles[j].copy();
      np.weight = 1.0 / nParticles;
      newParticles.add(np);
      u += step;
    }
    _particles = newParticles;
  }

  /// Weighted regime probabilities from current particle set.
  List<double> getRegimeProbabilities() {
    final probs = List<double>.filled(nStates, 0.0);
    for (final p in _particles) {
      probs[p.regime] += p.weight;
    }
    final total = probs.reduce((a, b) => a + b);
    if (total > 0) {
      for (int i = 0; i < nStates; i++) {
        probs[i] /= total;
      }
    }
    return probs;
  }

  /// Weighted mean volScale.
  double getVolScaleMean() {
    double wVol = 0.0;
    for (final p in _particles) {
      wVol += p.weight * p.volScale;
    }
    return wVol;
  }

  /// Weighted std of volScale.
  double getVolScaleStd() {
    final mean = getVolScaleMean();
    double wVar = 0.0;
    for (final p in _particles) {
      wVar += p.weight * (p.volScale - mean) * (p.volScale - mean);
    }
    return sqrt(wVar);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Regime-Aware State-Space Monte Carlo Simulator
// ═══════════════════════════════════════════════════════════════════════════════

class RegimeAwareSimulator {
  final List<RegimeParams> regimeParams;
  final List<List<double>> transitionMatrix; // persistence-adjusted A'
  final int nStates;

  RegimeAwareSimulator({
    required this.regimeParams,
    required this.transitionMatrix,
  }) : nStates = regimeParams.length;

  /// Simulate a single regime-switching price path and track barriers.
  PathResult simulatePath({
    required double startPrice,
    required int steps,
    required int startRegime,
    required double volScale,
    required Random rng,
  }) {
    double price = startPrice;
    double maxPrice = startPrice;
    double minPrice = startPrice;
    double peak = startPrice;
    double maxDrawdown = 0.0;
    int regime = startRegime;

    for (int t = 0; t < steps; t++) {
      // Regime transition using persistence-adjusted matrix
      final u = rng.nextDouble();
      double cumProb = 0.0;
      for (int j = 0; j < nStates; j++) {
        cumProb += transitionMatrix[regime][j];
        if (u <= cumProb) {
          regime = j;
          break;
        }
      }

      // Student-t innovation
      final mu = regimeParams[regime].mean;
      final sigma = (regimeParams[regime].std * volScale).clamp(
        1e-8,
        double.infinity,
      );
      final nu = regimeParams[regime].nu;
      final innovation = _studentTRandom(nu, rng);
      final logReturn = (mu - 0.5 * sigma * sigma) + sigma * innovation;
      price *= exp(logReturn);

      // Track barriers
      if (price > maxPrice) maxPrice = price;
      if (price < minPrice) minPrice = price;
      if (price > peak) peak = price;
      final dd = (peak - price) / peak;
      if (dd > maxDrawdown) maxDrawdown = dd;
    }

    return PathResult(
      finalPrice: price,
      maxPrice: maxPrice,
      minPrice: minPrice,
      maxDrawdown: maxDrawdown,
    );
  }

  /// Run full Monte Carlo simulation. Returns path results sorted by finalPrice.
  List<PathResult> simulate({
    required double startPrice,
    required int steps,
    required List<double> regimeProbs,
    required double volScale,
    int numSimulations = 10000,
    int seed = 42,
  }) {
    final rng = Random(seed);
    final paths = <PathResult>[];

    // Pre-compute cumulative regime probabilities
    final cumRegimeProbs = <double>[];
    double cum = 0.0;
    for (final p in regimeProbs) {
      cum += p;
      cumRegimeProbs.add(cum);
    }

    for (int i = 0; i < numSimulations; i++) {
      // Sample starting regime
      final u = rng.nextDouble();
      int startRegime = 0;
      for (int j = 0; j < nStates; j++) {
        if (u <= cumRegimeProbs[j]) {
          startRegime = j;
          break;
        }
      }

      paths.add(
        simulatePath(
          startPrice: startPrice,
          steps: steps,
          startRegime: startRegime,
          volScale: volScale,
          rng: rng,
        ),
      );
    }

    paths.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
    return paths;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top-level orchestrator
// ═══════════════════════════════════════════════════════════════════════════════

class RegimeDetectionService {
  static const int _nStates = 3;

  /// Compute regime entropy: −Σ π_k ln(π_k).
  static double _entropy(List<double> probs) {
    double h = 0.0;
    for (final p in probs) {
      if (p > 1e-15) h -= p * log(p);
    }
    return h;
  }

  /// Build persistence-adjusted transition matrix A'.
  /// Boosts diagonal (self-transition) based on regime certainty.
  static List<List<double>> _persistenceAdjust(
    List<List<double>> A,
    double entropy,
    int nStates,
  ) {
    // Max entropy for 3 states = ln(3) ≈ 1.099
    final maxEntropy = log(nStates.toDouble());
    final normEntropy = maxEntropy > 0
        ? (entropy / maxEntropy).clamp(0.0, 1.0)
        : 1.0;

    // persistenceBoost is high when entropy is low (regime is certain)
    final persistenceBoost = 0.10 * (1.0 - normEntropy);

    final aPrime = List.generate(nStates, (i) => List<double>.from(A[i]));

    for (int i = 0; i < nStates; i++) {
      aPrime[i][i] = (A[i][i] + persistenceBoost).clamp(0.0, 0.98);
      // Renormalize row
      double offDiagSum = 0.0;
      for (int j = 0; j < nStates; j++) {
        if (j != i) offDiagSum += A[i][j];
      }
      final remaining = 1.0 - aPrime[i][i];
      for (int j = 0; j < nStates; j++) {
        if (j != i) {
          aPrime[i][j] = offDiagSum > 0
              ? A[i][j] / offDiagSum * remaining
              : remaining / (nStates - 1);
        }
      }
    }
    return aPrime;
  }

  /// Run the full HMM + Particle Filter pipeline on log-returns.
  static RegimeDetectionResult detect(List<double> logReturns) {
    // 1. Fit Student-t HMM
    final hmm = StudentTHMM(nStates: _nStates, driftShrinkage: 0.8);
    hmm.fit(logReturns, maxIter: 30);

    // 2. Viterbi decoding
    final stateSeq = hmm.viterbi(logReturns);

    // 3. Forward-filtered current state probs
    final hmmProbs = hmm.currentStateProbabilities(logReturns);

    // 4. Particle filter for refined real-time estimate
    final pf = ParticleFilter(
      nParticles: 500,
      nStates: _nStates,
      transitionMatrix: hmm.A,
      regimeMeans: hmm.means,
      regimeStds: hmm.stds,
      regimeNus: hmm.nus,
      seed: 42,
    );

    final pfWindow = logReturns.length > 50
        ? logReturns.sublist(logReturns.length - 50)
        : logReturns;
    for (final obs in pfWindow) {
      pf.update(obs);
    }

    final pfProbs = pf.getRegimeProbabilities();

    // 5. Blend: 70% HMM + 30% PF (spec §6.2)
    final blendedProbs = List<double>.filled(_nStates, 0.0);
    double bSum = 0.0;
    for (int s = 0; s < _nStates; s++) {
      blendedProbs[s] = 0.7 * hmmProbs[s] + 0.3 * pfProbs[s];
      bSum += blendedProbs[s];
    }
    for (int s = 0; s < _nStates; s++) {
      blendedProbs[s] /= bSum;
    }

    // Determine most likely regime
    int bestRegime = 0;
    for (int s = 1; s < _nStates; s++) {
      if (blendedProbs[s] > blendedProbs[bestRegime]) bestRegime = s;
    }

    // 6. Regime entropy
    final entropy = _entropy(blendedProbs);

    // 7. Persistence-adjusted transition matrix
    final persistenceMatrix = _persistenceAdjust(hmm.A, entropy, _nStates);

    return RegimeDetectionResult(
      regimeParams: hmm.regimeParameters,
      transitionMatrix: hmm.A,
      persistenceMatrix: persistenceMatrix,
      currentRegimeProbs: blendedProbs,
      currentRegime: bestRegime,
      stateSequence: stateSeq,
      initialProbs: hmm.initProbs,
      regimeEntropy: entropy,
    );
  }
}
