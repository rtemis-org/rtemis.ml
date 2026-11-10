# classification-metrics.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

# Compares the rtemis.ml classification metrics with the backends rtemis uses:
# lightAUC and ROCR for binary AUC, rtemis.draw::pr_vertices() for average
# precision, and pROC for one-vs-rest AUC. Reports agreement, median time,
# and peak memory. Requires bench, lightAUC, ROCR, pROC, and rtemis.draw.
# Run from the package root: Rscript tools/bench/classification-metrics.R

library(rtemis.ml)

# %% Data ----
make_binary <- function(n, ties = FALSE, seed = 2026L) {
  set.seed(seed)
  reference <- rbinom(n, 1L, 0.3)
  scores <- plogis(reference + rnorm(n))
  if (ties) {
    scores <- round(scores, 2)
  }
  list(reference = as.integer(reference), scores = scores)
}

make_multiclass <- function(n, k = 5L, seed = 2026L) {
  set.seed(seed)
  reference <- factor(sample(letters[seq_len(k)], n, replace = TRUE))
  logits <- matrix(rnorm(n * k), n, k)
  logits[cbind(seq_len(n), as.integer(reference))] <-
    logits[cbind(seq_len(n), as.integer(reference))] + 1
  scores <- exp(logits) / rowSums(exp(logits))
  list(reference = reference, scores = scores)
}


# %% Backends ----
backends <- list(
  roc_auc = list(
    rtemis.ml = function(d) roc_auc(d[["reference"]], d[["scores"]]),
    lightAUC = function(d) {
      lightAUC::lightAUC(
        probs = d[["scores"]],
        actuals = d[["reference"]]
      )
    },
    ROCR = function(d) {
      pred <- ROCR::prediction(d[["scores"]], d[["reference"]])
      ROCR::performance(pred, "auc")@y.values[[1]]
    }
  ),
  ap = list(
    rtemis.ml = function(d) {
      average_precision(d[["reference"]], d[["scores"]])
    },
    rtemis.draw = function(d) {
      x <- rtemis.draw::roc_probabilities(
        factor(d[["reference"]], levels = 0:1),
        d[["scores"]]
      )
      rtemis.draw::pr_vertices(x)[["ap"]][[1L]]
    }
  ),
  roc_auc_ovr = list(
    rtemis.ml = function(d) {
      unname(roc_auc_ovr(d[["reference"]], d[["scores"]]))
    },
    pROC = function(d) {
      lv <- levels(d[["reference"]])
      vapply(
        seq_along(lv),
        function(j) {
          r <- pROC::roc(
            d[["reference"]] == lv[j],
            d[["scores"]][, j],
            levels = c(FALSE, TRUE),
            direction = "<",
            quiet = TRUE
          )
          as.numeric(r[["auc"]])
        },
        numeric(1)
      )
    }
  ),
  ap_ovr = list(
    rtemis.ml = function(d) {
      unname(average_precision_ovr(d[["reference"]], d[["scores"]]))
    },
    rtemis.draw = function(d) {
      x <- rtemis.draw::roc_probabilities(
        d[["reference"]],
        d[["scores"]]
      )
      r <- rtemis.draw::pr_vertices(x)
      r[["ap"]][!duplicated(r[["class"]])]
    }
  )
)
data_for <- function(metric, n, ties = FALSE) {
  if (grepl("ovr", metric)) make_multiclass(n) else make_binary(n, ties)
}


# %% Agreement ----
cat("\n== Agreement: maximum absolute difference from rtemis.ml ==\n")
for (metric in names(backends)) {
  for (n in c(100L, 10000L, 1000000L)) {
    d <- data_for(metric, n, ties = TRUE)
    values <- lapply(backends[[metric]], function(f) f(d))
    diffs <- vapply(
      values[-1L],
      function(v) max(abs(v - values[["rtemis.ml"]])),
      numeric(1)
    )
    cat(sprintf(
      "%-8s n = %7d: %s\n",
      metric,
      n,
      paste(sprintf("%s %.1e", names(diffs), diffs), collapse = "; ")
    ))
  }
}


# %% Speed ----
cat("\n== Speed: median time; ratio to rtemis.ml ==\n")
sizes <- list(
  roc_auc = c(1000L, 100000L, 1000000L, 10000000L),
  ap = c(1000L, 100000L, 1000000L, 10000000L),
  roc_auc_ovr = c(1000L, 100000L, 1000000L),
  ap_ovr = c(1000L, 100000L, 1000000L)
)
results <- list()
for (metric in names(backends)) {
  for (n in sizes[[metric]]) {
    d <- data_for(metric, n)
    use <- names(backends[[metric]])
    if (n > 1000000L) {
      use <- setdiff(use, "ROCR")
    }
    exprs <- lapply(use, function(b) bquote(backends[[.(metric)]][[.(b)]](d)))
    names(exprs) <- use
    bm <- bench::mark(
      exprs = exprs,
      check = FALSE,
      min_iterations = 3L,
      max_iterations = if (n >= 1000000L) 10L else 100L,
      filter_gc = FALSE
    )
    results[[length(results) + 1L]] <- data.frame(
      metric = metric,
      n = n,
      backend = use,
      median = format(bm[["median"]]),
      ratio = round(
        as.numeric(bm[["median"]]) / as.numeric(bm[["median"]][1L]),
        1
      )
    )
  }
}
print(do.call(rbind, results), row.names = FALSE)


# %% Peak memory ----
# Each backend runs in a fresh R process on the same data. The process's peak
# resident set size, minus that of a process that only creates the data, is
# the memory the backend adds. bench::mark() tracks only R allocations, so it
# misses memory allocated in C++ or Rust.
cat("\n== Peak memory above the data (MB) ==\n")
setup_file <- tempfile(fileext = ".R")
writeLines(
  c(
    "library(rtemis.ml)",
    paste("make_binary <-", paste(deparse(make_binary), collapse = "\n")),
    paste(
      "make_multiclass <-",
      paste(deparse(make_multiclass), collapse = "\n")
    ),
    paste("data_for <-", paste(deparse(data_for), collapse = "\n")),
    paste("backends <-", paste(deparse(backends), collapse = "\n"))
  ),
  setup_file
)
peak_rss_mb <- function(metric, backend, n) {
  code <- sprintf(
    "source('%s'); d <- data_for('%s', %d); if ('%s' != 'none') invisible(backends[['%s']][['%s']](d))",
    setup_file,
    metric,
    n,
    backend,
    metric,
    backend
  )
  out <- system2(
    "/usr/bin/time",
    c("-l", file.path(R.home("bin"), "Rscript"), "-e", shQuote(code)),
    stdout = TRUE,
    stderr = TRUE
  )
  line <- grep("maximum resident set size", out, value = TRUE)
  as.numeric(sub("^\\s*(\\d+).*", "\\1", line)) / 2^20
}
memory_sizes <- c(
  roc_auc = 10000000L,
  ap = 10000000L,
  roc_auc_ovr = 1000000L,
  ap_ovr = 1000000L
)
for (metric in names(backends)) {
  n <- memory_sizes[[metric]]
  baseline <- peak_rss_mb(metric, "none", n)
  for (b in names(backends[[metric]])) {
    cat(sprintf(
      "%-8s n = %8d  %-12s %8.1f\n",
      metric,
      n,
      b,
      peak_rss_mb(metric, b, n) - baseline
    ))
  }
}
unlink(setup_file)
