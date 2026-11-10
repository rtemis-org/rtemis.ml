# test-classification_metrics.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

# %% References ----
# AUC by comparing every positive-negative pair, with ties counted as one half.
ref_auc <- function(reference, scores) {
  if (length(unique(reference)) < 2L) {
    return(NaN)
  }
  d <- outer(
    scores[reference == 1L],
    scores[reference == 0L],
    "-"
  )
  mean((d > 0) + 0.5 * (d == 0))
}

# AP with each distinct score as one threshold, as in rtemis.draw::pr_vertices().
ref_ap <- function(reference, scores) {
  if (!any(reference == 1L)) {
    return(NaN)
  }
  ord <- order(scores, decreasing = TRUE)
  score <- scores[ord]
  response <- reference[ord] == 1L
  ends <- c(which(diff(score) != 0), length(score))
  tp <- cumsum(response)[ends]
  sum(diff(c(0, tp / sum(response))) * tp / ends)
}

random_binary <- function(n, ties) {
  reference <- sample(0:1, n, replace = TRUE)
  scores <- if (ties) round(runif(n), 1) else runif(n)
  list(reference = reference, scores = scores)
}

random_multiclass <- function(n, k, ties) {
  reference <- factor(
    sample(letters[seq_len(k)], n, replace = TRUE),
    levels = letters[seq_len(k)]
  )
  p <- matrix(runif(n * k), n, k)
  p <- p / rowSums(p)
  if (ties) {
    p <- round(p, 1)
  }
  list(reference = reference, scores = p)
}


# %% roc_auc ----
test_that("auc() returns known values", {
  expect_identical(roc_auc(c(0L, 0L, 1L, 1L), c(0.1, 0.4, 0.35, 0.8)), 0.75)
  expect_identical(roc_auc(c(0L, 0L, 1L, 1L), c(0.1, 0.2, 0.8, 0.9)), 1)
  expect_identical(roc_auc(c(1L, 1L, 0L, 0L), c(0.1, 0.2, 0.8, 0.9)), 0)
  expect_identical(roc_auc(c(0L, 1L, 0L, 1L), rep(0.5, 4)), 0.5)
  expect_identical(roc_auc(c(1L, 0L, 1L, 0L), c(0.5, 0.5, 0.9, 0.1)), 0.875)
})

test_that("auc() and average_precision() match references with and without ties", {
  set.seed(2026)
  for (i in seq_len(60)) {
    d <- random_binary(sample(2:500, 1), ties = i %% 2 == 0)
    expect_equal(
      roc_auc(d[["reference"]], d[["scores"]]),
      ref_auc(d[["reference"]], d[["scores"]]),
      tolerance = 1e-12
    )
    expect_equal(
      average_precision(d[["reference"]], d[["scores"]]),
      ref_ap(d[["reference"]], d[["scores"]]),
      tolerance = 1e-12
    )
  }
})


# %% average_precision ----
test_that("average_precision() returns known values", {
  expect_equal(
    average_precision(c(0L, 0L, 1L, 1L), c(0.1, 0.4, 0.35, 0.8)),
    5 / 6
  )
  expect_identical(average_precision(c(0L, 1L, 0L, 1L), rep(0.5, 4)), 0.5)
  expect_identical(
    average_precision(c(1L, 0L, 0L, 0L), c(0.1, 0.2, 0.3, 0.4)),
    0.25
  )
})

test_that("undefined metrics are NaN", {
  expect_identical(roc_auc(c(1L, 1L), c(0.2, 0.9)), NaN)
  expect_identical(roc_auc(integer(), numeric()), NaN)
  expect_identical(average_precision(c(0L, 0L), c(0.2, 0.9)), NaN)
  expect_identical(average_precision(c(1L, 1L), c(0.2, 0.9)), 1)
})

test_that("binary metrics reject invalid input", {
  for (f in list(roc_auc, average_precision)) {
    expect_error(f(c(0L, 1L), 0.5), "differ in length")
    expect_error(f(c(0L, 2L), c(0.1, 0.2)), "is 2 at position 2")
    expect_error(f(c(0L, NA), c(0.1, 0.2)), "NA at position 2")
    expect_error(f(c(0L, 1L), c(0.1, NA)), "NA or NaN at position 2")
    expect_error(f(c(0L, 1L), c(0.1, NaN)), "NA or NaN at position 2")
    expect_error(f(c(0, 1), c(0.1, 0.2)), "integer vector")
    expect_error(f(c(0L, 1L), 1:2), "double vector")
  }
})


# %% roc_auc_ovr, average_precision_ovr ----
test_that("one-vs-rest metrics match the binary references per class", {
  set.seed(2027)
  for (i in seq_len(30)) {
    d <- random_multiclass(
      sample(3:300, 1),
      k = sample(2:5, 1),
      ties = i %% 2 == 0
    )
    lv <- levels(d[["reference"]])
    expected_auc <- vapply(
      seq_along(lv),
      function(j) {
        ref_auc(
          as.integer(d[["reference"]] == lv[j]),
          d[["scores"]][, j]
        )
      },
      numeric(1)
    )
    expected_ap <- vapply(
      seq_along(lv),
      function(j) {
        ref_ap(
          as.integer(d[["reference"]] == lv[j]),
          d[["scores"]][, j]
        )
      },
      numeric(1)
    )
    expect_equal(
      roc_auc_ovr(d[["reference"]], d[["scores"]]),
      setNames(expected_auc, lv),
      tolerance = 1e-12
    )
    expect_equal(
      average_precision_ovr(d[["reference"]], d[["scores"]]),
      setNames(expected_ap, lv),
      tolerance = 1e-12
    )
  }
})

test_that("one-vs-rest metrics are NaN for an absent class", {
  reference <- factor(c("a", "b", "a"), levels = c("a", "b", "c"))
  p <- matrix(c(0.8, 0.1, 0.7, 0.1, 0.8, 0.2, 0.1, 0.1, 0.1), 3L)
  expect_identical(roc_auc_ovr(reference, p), c(a = 1, b = 1, c = NaN))
  expect_identical(
    average_precision_ovr(reference, p),
    c(a = 1, b = 1, c = NaN)
  )
})

test_that("one-vs-rest metrics reject invalid input", {
  reference <- factor(c("a", "b", "c"))
  p <- diag(3)
  for (f in list(roc_auc_ovr, average_precision_ovr)) {
    expect_error(f(c(1L, 2L, 3L), p), "must be a factor")
    expect_error(f(factor(c("a", NA, "c")), p), "NA at position 2")
    expect_error(f(reference, c(0.1, 0.2, 0.3)), "double matrix")
    expect_error(f(reference, p[, 1:2]), "3 rows and 3 columns")
    p_na <- p
    p_na[2L, 3L] <- NA
    expect_error(f(reference, p_na), "row 2, column 3")
  }
})
