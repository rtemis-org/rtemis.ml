# rtemis.ml-package.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

#' @name rtemis.ml-package
#'
#' @title rtemis.ml: Performance Metrics for Classification
#'
#' @description
#' Computes the area under the ROC curve and the average precision of binary
#' classifiers, and their one-vs-rest values for each class of a multiclass
#' outcome. The computations are implemented in the 'rtemis' 'Rust' crate.
#'
#' @section Binary outcomes:
#' [roc_auc()], [average_precision()].
#'
#' @section Multiclass outcomes:
#' [roc_auc_ovr()], [average_precision_ovr()].
#'
#' @keywords internal
"_PACKAGE"
