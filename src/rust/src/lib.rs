//! R bindings of the `rtemis` crate for the R package rtemis.ml.
//!
//! Each module converts R objects to the slices the `rtemis` crate takes,
//! checks the R input contract, and reports errors with R argument names and
//! one-based positions.
//!
//! The crate is `rtemis-ml-r`, internal to the R package. The extendr module
//! is `rtemis_ml` because R calls the package's initialization routine
//! `R_init_rtemis_ml` (see `entrypoint.c`), named after the R package.

use extendr_api::prelude::*;

mod classification_metrics;

extendr_module! {
    mod rtemis_ml;
    use classification_metrics;
}
