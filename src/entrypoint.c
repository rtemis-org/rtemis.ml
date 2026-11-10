// R calls R_init_rtemis_ml when it loads the package. Forwarding the call to
// the Rust registration routine references the static library, so the linker
// keeps it.

void R_init_rtemis_ml_extendr(void *dll);
void register_extendr_panic_hook(void);

void R_init_rtemis_ml(void *dll) {
    register_extendr_panic_hook();
    R_init_rtemis_ml_extendr(dll);
}
