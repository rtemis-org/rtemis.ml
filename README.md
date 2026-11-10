# rtemis.ml

R bindings to the [`rtemis`](https://crates.io/crates/rtemis) Rust crate ([rtemis-org/rtemis-rs](https://github.com/rtemis-org/rtemis-rs)). Each function reads R vectors and matrices in place, checks them against the R interface, and reports errors with R argument names and one-based positions.

## Classification performance metrics

| Function | `reference` | `scores` | Returns |
|---|---|---|---|
| `roc_auc(reference, scores)` | integer 0/1 | double vector | area under the ROC curve |
| `average_precision(reference, scores)` | integer 0/1 | double vector | area under the stepwise precision-recall curve |
| `roc_auc_ovr(reference, scores)` | factor | double matrix, one column per level | one-vs-rest AUC per class |
| `average_precision_ovr(reference, scores)` | factor | double matrix, one column per level | one-vs-rest average precision per class |

`reference` holds the reference label of each case. `scores` holds any score where a higher value indicates the positive class, or the column's class for one-vs-rest, such as predicted probabilities; the metrics depend on the scores only through their order. The scores are sorted once per problem and the inputs are read without copying; extra memory is 8 bytes per case.

```r
library(rtemis.ml)
roc_auc(c(0L, 0L, 1L, 1L), c(0.1, 0.4, 0.35, 0.8))
#> [1] 0.75
```

## Installation

Building from source requires Cargo and rustc 1.71 or later (<https://www.rust-lang.org/tools/install>).

## Development

The R package depends on the `rtemis` crate from crates.io. To build against a local checkout of [rtemis-rs](https://github.com/rtemis-org/rtemis-rs), set `RTEMIS_CRATE_PATH` to the crate directory before installing, for example in `~/.Renviron`:

```sh
RTEMIS_CRATE_PATH=~/Code/rtemis-rs/crates/rtemis
```

`tools/config.R` then passes Cargo a `patch.crates-io` override for the build.

| Command | Action |
|---|---|
| `just document` | Compile, regenerate `R/extendr-wrappers.R`, and run roxygen2 |
| `just test` | Run the testthat tests |
| `just rust-check` | Run rustfmt, clippy, and the Rust tests of the binding crate |
| `just bench` | Compare speed, memory, and agreement with lightAUC, ROCR, pROC, and rtemis.draw |
| `just vendor` | Vendor the Rust crates into `src/rust/vendor.tar.xz` and write `LICENSE.note` and `inst/AUTHORS` |
| `just check-cran` | Build and run `R CMD check --as-cran` |

## License

[BSD-3-Clause](LICENSE.md).
