//! R bindings for the classification metrics in
//! [`rtemis::ml::metrics::classification`].
//!
//! Each function borrows the R vectors in place, checks the R input contract,
//! and reports errors with R argument names and one-based positions.

use extendr_api::prelude::*;
use extendr_api::Result;
use rtemis::ml::metrics::classification::{self as core, MetricError, RankedScores};

/// Area under the ROC curve
///
/// Computes the area under the receiver operating characteristic (ROC) curve
/// of a binary classifier: the probability that a randomly chosen positive
/// case receives a higher score than a randomly chosen negative case, with
/// ties counted as one half.
///
/// The AUC depends on the scores only through their order, so any score where
/// a higher value indicates the positive class gives the same result as its
/// predicted probability. The inputs are read in place, without copying. Extra
/// memory is 8 bytes per case, and time is O(n log n).
///
/// @param reference Integer \{0, 1\}: Reference label of each case, `1L` for
///   the positive class and `0L` for the negative class.
/// @param scores Numeric: Score of each case, where a higher value indicates
///   the positive class, such as the predicted probability of the positive
///   class. A double vector the same length as `reference`.
///
/// @return Double: the AUC, between 0 and 1. `NaN` when `reference` contains
///   only one class or is empty. An error is raised when the lengths differ,
///   when `reference` contains a value other than 0 or 1, including `NA`, or
///   when `scores` contains `NA` or `NaN`.
///
/// @seealso [roc_auc_ovr()] for multiclass outcomes, [average_precision()] for
///   the area under the precision-recall curve.
///
/// @examples
/// roc_auc(c(0L, 0L, 1L, 1L), c(0.1, 0.4, 0.35, 0.8))
/// @export
#[extendr]
fn roc_auc(reference: Robj, scores: Robj) -> Result<f64> {
    binary_ranked(&reference, &scores).map(|r| r.roc_auc())
}

/// Average precision
///
/// Computes the average precision (AP) of a binary classifier: the area under
/// the stepwise precision-recall curve. Each distinct score is one threshold,
/// and the cases tied at it enter together. Thresholds are numbered from the
/// highest score down; with recall \eqn{R_k} and precision \eqn{P_k} at
/// threshold \eqn{k}, \eqn{AP = \sum_k (R_k - R_{k-1}) P_k}, with
/// \eqn{R_0 = 0}.
///
/// The AP depends on the scores only through their order. The value of a
/// classifier that scores independently of the reference labels is expected
/// to be near the prevalence of the positive class. The inputs are read in
/// place, without copying. Extra memory is 8 bytes per case, and time is
/// O(n log n).
///
/// @inheritParams roc_auc
///
/// @return Double: the AP, between 0 and 1. `NaN` when `reference` contains no
///   positive case; 1 when it contains no negative case. Errors as
///   [roc_auc()].
///
/// @seealso [average_precision_ovr()] for multiclass outcomes, [roc_auc()] for
///   the area under the ROC curve.
///
/// @examples
/// average_precision(c(0L, 0L, 1L, 1L), c(0.1, 0.4, 0.35, 0.8))
/// @export
#[extendr]
fn average_precision(reference: Robj, scores: Robj) -> Result<f64> {
    binary_ranked(&reference, &scores).map(|r| r.average_precision())
}

/// One-vs-rest area under the ROC curve
///
/// Computes, for each class of a multiclass outcome, the AUC of that class
/// against all other classes, as [roc_auc()] does for a binary outcome. The
/// macro-averaged AUC is the mean of the result.
///
/// The inputs are read in place, without copying. Extra memory is 8 bytes per
/// case, reused across classes, and time is O(k n log n) for k classes.
///
/// @param reference Factor: Reference label of each case.
/// @param scores Numeric matrix: Score of each case for each class, where a
///   higher value indicates that class, such as the predicted class
///   probabilities. A double matrix with one row per case and one column per
///   level of `reference`, in level order.
///
/// @return Named double vector: the AUC of each class, named by the levels of
///   `reference`. `NaN` for a class that is absent or is the only class
///   present. An error is raised when `reference` is not a factor or contains
///   `NA`, when the dimensions of `scores` do not match, or when `scores`
///   contains `NA` or `NaN`.
///
/// @seealso [average_precision_ovr()]
///
/// @examples
/// reference <- factor(c("a", "b", "c", "a"))
/// scores <- matrix(
///   c(0.8, 0.1, 0.1, 0.6, 0.1, 0.7, 0.2, 0.2, 0.1, 0.2, 0.7, 0.2),
///   ncol = 3L
/// )
/// roc_auc_ovr(reference, scores)
/// @export
#[extendr]
fn roc_auc_ovr(reference: Robj, scores: Robj) -> Result<Robj> {
    one_vs_rest(&reference, &scores, core::roc_auc_ovr)
}

/// One-vs-rest average precision
///
/// Computes, for each class of a multiclass outcome, the average precision of
/// that class against all other classes, as [average_precision()] does for a
/// binary outcome. The macro-averaged AP is the mean of the result.
///
/// The inputs are read in place, without copying. Extra memory is 8 bytes per
/// case, reused across classes, and time is O(k n log n) for k classes.
///
/// @inheritParams roc_auc_ovr
///
/// @return Named double vector: the AP of each class, named by the levels of
///   `reference`. `NaN` for a class that is absent. Errors as
///   [roc_auc_ovr()].
///
/// @seealso [roc_auc_ovr()]
///
/// @examples
/// reference <- factor(c("a", "b", "c", "a"))
/// scores <- matrix(
///   c(0.8, 0.1, 0.1, 0.6, 0.1, 0.7, 0.2, 0.2, 0.1, 0.2, 0.7, 0.2),
///   ncol = 3L
/// )
/// average_precision_ovr(reference, scores)
/// @export
#[extendr]
fn average_precision_ovr(reference: Robj, scores: Robj) -> Result<Robj> {
    one_vs_rest(&reference, &scores, core::average_precision_ovr)
}

/// Ranks a binary problem from an integer 0/1 `reference` and double `scores`.
fn binary_ranked(reference: &Robj, scores: &Robj) -> Result<RankedScores> {
    let reference = reference
        .as_integer_slice()
        .ok_or_else(|| error("`reference` must be an integer vector"))?;
    if let Some(i) = reference.iter().position(|&l| l != 0 && l != 1) {
        return Err(if reference[i] == i32::MIN {
            error(format!("`reference` is NA at position {}", i + 1))
        } else {
            error(format!(
                "`reference` is {} at position {}; values must be 0 or 1",
                reference[i],
                i + 1
            ))
        });
    }
    let scores = scores
        .as_real_slice()
        .ok_or_else(|| error("`scores` must be a double vector"))?;
    RankedScores::new(reference, scores, 1).map_err(|e| match e {
        MetricError::LengthMismatch { expected, found } => error(format!(
            "`reference` and `scores` differ in length ({expected} and {found})"
        )),
        MetricError::NanScore { index } => {
            error(format!("`scores` is NA or NaN at position {}", index + 1))
        }
        other => error(other.to_string()),
    })
}

/// A one-vs-rest metric of the core, applied to R factor codes.
type OvrMetric = fn(&[i32], &[f64], &[i32]) -> std::result::Result<Vec<f64>, MetricError>;

/// Validates a factor and a matching score matrix, then applies a one-vs-rest
/// metric with the factor codes `1..=k` as classes and names the result by
/// the factor levels.
fn one_vs_rest(reference: &Robj, scores: &Robj, metric: OvrMetric) -> Result<Robj> {
    if !reference.is_factor() {
        return Err(error("`reference` must be a factor"));
    }
    let levels: Vec<&str> = reference.levels().map(|l| l.collect()).unwrap_or_default();
    let codes = reference
        .as_integer_slice()
        .ok_or_else(|| error("`reference` must be a factor"))?;
    if let Some(i) = codes.iter().position(|&code| code == i32::MIN) {
        return Err(error(format!("`reference` is NA at position {}", i + 1)));
    }

    // `nrows()` and `ncols()` call `Rf_nrows()` and `Rf_ncols()`, which raise
    // an R error for non-vector input, so the matrix check comes first.
    if !scores.is_matrix() {
        return Err(error("`scores` must be a double matrix"));
    }
    let (n, k) = (codes.len(), levels.len());
    let (n_rows, n_cols) = (scores.nrows(), scores.ncols());
    let scores = scores
        .as_real_slice()
        .ok_or_else(|| error("`scores` must be a double matrix"))?;
    if n_rows != n || n_cols != k {
        return Err(error(format!(
            "`scores` must have {n} rows and {k} columns, one per level of \
             `reference`; found {n_rows} rows and {n_cols} columns"
        )));
    }

    let classes: Vec<i32> = (1..=k as i32).collect();
    let values = metric(codes, scores, &classes).map_err(|e| match e {
        MetricError::NanScore { index } => error(format!(
            "`scores` is NA or NaN at row {}, column {}",
            index % n + 1,
            index / n + 1
        )),
        other => error(other.to_string()),
    })?;
    let mut out = Robj::from(values);
    out.set_names(levels)?;
    Ok(out)
}

fn error(message: impl Into<String>) -> Error {
    Error::Other(message.into())
}

extendr_module! {
    mod classification_metrics;
    fn roc_auc;
    fn average_precision;
    fn roc_auc_ovr;
    fn average_precision_ovr;
}
