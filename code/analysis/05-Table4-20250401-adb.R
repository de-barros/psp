# ==========================================================================
# 05-Table4 — causal-forest heterogeneity. Prints as Appendix Table A4.
# PROPOSED REVISION (2026-07-08): expand the displayed rows to the full
# pre-registered covariate set (PAP Table 4 shell, "following Dinarte et al.
# 2024"), keeping the current column format and the extra tests.
#
# Rows now follow the PAP order (no importance sorting):
#   Panel A: Female; Bottom/Middle two/Top quartile (within-grade, one row each);
#            Grade 1..6 (one row each); Baseline score; Grade point average;
#            Ever repeated; Ever qualified for Tayssir.
#   Panel B: Number of teachers; Urban; Regional development; Total enrollment;
#            Female students (%); Tayssir beneficiaries (%); Social security
#            beneficiaries (%); Average grade-6 exam score.
#
# Rendering (all subgroups are a single 0/1 indicator, so the BLP intercept is a
# saturated subgroup mean == average_treatment_effect(cf, subset=indicator)):
#   binary  -> two rows (Yes / No)
#   level   -> one row  (exhaustive categoricals: quartiles, grades)
#   cont    -> two rows (Low / High) split at the covariate's sample median
# For each row: variable importance | subgroup indicator | subgroup CATE + SE
# (best_linear_projection intercept) | weak-group share | strong-group share |
# difference. Bottom block: AIPW group-average ITT (weak/strong/diff) + a single
# sequential cross-fold RATE p-value (AUTOC). One joint forest.
#
# Writes:
#   output/tables/tablea4_forest.txt   <- the LaTeX-ready table body
#   $eltemp/temp8.csv                  <- forest output (back-compat / 06)
#   $eltemp/forest_*.{csv,png}         <- forest diagnostics
#
# DiD specifics (NOT the RCT pieces of the TaRL source): grf estimates the
# propensity from X; clustering is at the matched pair; Y is the residualized
# change score from 01-Testscores.
# ==========================================================================

rm(list = ls())

library(grf)
library(tidyverse)
library(cowplot)
library(haven)

source("code/_setup.R")

num_cores <- max(1L, parallel::detectCores() - 1L)

################################################################################
# Helpers (sequential cross-fold RATE; ported from the TaRL Table A3 builder)
################################################################################

# Cluster-respecting fold assignment (greedy balance by cluster size).
make_cluster_folds <- function(cluster, K = 5, seed = 1839) {
  set.seed(seed)
  cluster <- as.vector(cluster)
  u <- unique(cluster)
  sizes <- as.integer(table(cluster)[as.character(u)])
  o <- order(sizes, decreasing = TRUE); u <- u[o]; sizes <- sizes[o]
  fold_sizes <- rep(0L, K); fold_of_cluster <- integer(length(u))
  for (i in seq_along(u)) {
    k <- which.min(fold_sizes)
    fold_of_cluster[i] <- k
    fold_sizes[k] <- fold_sizes[k] + sizes[i]
  }
  names(fold_of_cluster) <- as.character(u)
  as.integer(fold_of_cluster[as.character(cluster)])
}

# Sequential cross-fold RATE test (cluster folds), per the grf vignette.
rate_sequential_cluster <- function(X, Y, W, clusters,
                                    num.folds = 5, seed = 1839,
                                    num.trees = 2000, min.node.size = 5,
                                    ci.group.size = 2, target = "AUTOC") {
  n <- nrow(X)
  fold.id <- make_cluster_folds(clusters, K = num.folds, seed = seed)
  samples.by.fold <- split(seq_len(n), fold.id)

  set.seed(seed)
  nuisance <- causal_forest(X, Y, W, clusters = clusters,
                            num.trees = num.trees, min.node.size = min.node.size,
                            ci.group.size = ci.group.size, num.threads = num_cores)
  DR.scores <- get_scores(nuisance)

  t.stats <- numeric(0)
  for (k in 2:num.folds) {
    train <- unlist(samples.by.fold[1:(k - 1)], use.names = FALSE)
    test  <- samples.by.fold[[k]]
    set.seed(seed + 1000 + k)
    cate <- causal_forest(X[train, , drop = FALSE], Y[train], W[train],
                          clusters = clusters[train],
                          num.trees = num.trees, min.node.size = min.node.size,
                          ci.group.size = ci.group.size, num.threads = num_cores)
    cate.hat.test <- predict(cate, X[test, , drop = FALSE])$predictions
    rate.fold <- rank_average_treatment_effect.fit(DR.scores[test], cate.hat.test,
                                                   target = target)
    t.stats <- c(t.stats, rate.fold$estimate / rate.fold$std.err)
  }
  T_agg <- sum(t.stats) / sqrt(num.folds - 1)
  list(T_agg = T_agg, p_value_two_sided = 2 * pnorm(-abs(T_agg)))
}

# Robust writer for grf coeftest-style matrices.
.wrcoef <- function(obj, path) {
  m <- as.matrix(obj)
  o <- data.frame(term = rownames(m), check.names = FALSE)
  for (j in seq_len(ncol(m))) o[[colnames(m)[j]]] <- m[, j]
  write.csv(o, path, row.names = FALSE)
}

################################################################################
# 1. Causal forest on test-score change residuals
################################################################################

students_program <- read_dta(file.path(eltemp, "temp7.dta"))

# X = the pre-registered covariate set. All are already forest covariates except
# gpa, which 01-Testscores now retains in temp7 (was previously dropped).
pupil_vars  <- c("female", "top", "middle", "bottom",
                 paste0("grade", 1:6), "bl_theta", "gpa", "repeated", "tayssir")
school_vars <- c("n_teachers", "urban", "regional_dev", "total_enrolled7_sum",
                 "perc_female", "perc_tayssir", "perc_ssbenef", "avg_score7_mu")
x_vars <- c(pupil_vars, school_vars)
stopifnot(all(x_vars %in% names(students_program)))

X    <- data.matrix(students_program[x_vars])   # numeric matrix; NAs kept for grf's MIA
Y    <- as.numeric(students_program$res)
W    <- as.numeric(students_program$treated)
# Cluster on the matched PAIR (randomization unit), not the school.
clus <- as.numeric(students_program$pair_id)
stopifnot(!anyNA(Y), !anyNA(W), all(W %in% c(0, 1)))   # X may carry NAs (grf MIA)

# Design check (informational): each pair should be two schools, one treated.
.sch <- unique(students_program[c("pair_id", "school_id", "treated")])
.chk <- tapply(.sch$treated, .sch$pair_id, function(t) length(t) == 2L && sum(t) == 1L)
if (!isTRUE(all(.chk))) warning(sprintf("%d of %d pairs are not 1-treated-of-2-schools.",
                                        sum(!.chk), length(.chk)))

ss <- 1839
set.seed(ss)
# No W.hat argument: grf estimates the propensity from X (a regression forest).
cf <- causal_forest(X = X, Y = Y, W = W,
                    num.trees = 50000, clusters = clus, ci.group.size = 2,
                    num.threads = num_cores, seed = ss)

# Out-of-bag predictions (no newdata => OOB), with variance.
preds <- predict(cf, estimate.variance = TRUE)
students_program$preds         <- preds$predictions
students_program$sqrt          <- sqrt(preds$variance.estimates)
students_program$excesserror   <- preds$excess.error
students_program$debiasederror <- preds$debiased.error

tau.hat <- preds$predictions
strong  <- tau.hat > median(tau.hat)            # strong = top half of OOB CATE
weak    <- !strong
students_program$hi_predicted_cate <- as.integer(strong)

# Doubly robust (AIPW) group ATEs in each half.
ate_strong <- average_treatment_effect(cf, subset = strong)
ate_weak   <- average_treatment_effect(cf, subset = weak)
students_program$ate_hi    <- ate_strong[["estimate"]]
students_program$ate_hi_se <- ate_strong[["std.err"]]
students_program$ate_lo    <- ate_weak[["estimate"]]
students_program$ate_lo_se <- ate_weak[["std.err"]]
gate_diff    <- ate_strong[["estimate"]] - ate_weak[["estimate"]]
gate_diff_se <- sqrt(ate_strong[["std.err"]]^2 + ate_weak[["std.err"]]^2)

write.csv(students_program, file = file.path(eltemp, "temp8.csv"), row.names = FALSE)

################################################################################
# 2. Sequential cross-fold RATE (AUTOC) p-value
################################################################################
Xm <- as.matrix(X); storage.mode(Xm) <- "double"
rate_cv <- tryCatch(
  rate_sequential_cluster(Xm, Y, W, clusters = clus,
                          num.folds = 5, seed = ss, num.trees = 2000),
  error = function(e) { message("sequential RATE failed: ", conditionMessage(e)); NULL })
rate_p <- if (is.null(rate_cv)) NA_real_ else rate_cv$p_value_two_sided
cat(sprintf("\nSequential cross-fold RATE p-value: %s\n",
            ifelse(is.na(rate_p), "NA", sprintf("%.4f", rate_p))))

################################################################################
# 3. Build Table A4 (TaRL Table A3 format) -> output/tables/tablea4_forest.txt
################################################################################

imp <- as.numeric(variable_importance(cf)); names(imp) <- colnames(cf$X.orig)

# Per-subgroup CATE + SE from a best_linear_projection intercept, evaluated over
# the observations where the row's indicator is observed. The indicator is a
# single 0/1 column, so the projection is SATURATED and the intercept-at-(1-ind)=0
# equals the AIPW subgroup mean E[tau | ind==1] (cross-checked against
# average_treatment_effect below).
blp_int <- function(ind, keep) {
  A <- matrix(1 - as.numeric(ind), ncol = 1)   # intercept sits at ind==1
  A[!keep, ] <- 0                              # placeholder rows, excluded by subset
  b <- best_linear_projection(cf, A, subset = which(keep))
  c(est = b["(Intercept)", "Estimate"], se = b["(Intercept)", "Std. Error"])
}
# Share of a subgroup within each CATE half: P(ind==1 | weak), P(ind==1 | strong).
shr <- function(ind) c(weak   = mean(ind[weak]   == 1, na.rm = TRUE),
                       strong = mean(ind[strong] == 1, na.rm = TRUE))

fmt_imp <- function(v) if (is.na(v)) "" else sprintf("%.3f", v)
# q-value formatter (same convention as the RATE cell).
fmt_q <- function(v) if (is.na(v)) "--" else if (v < 0.001) "$<$0.001" else sprintf("%.3f", v)

# Column (8) test: does the CATE differ across a characteristic's groups? The slope
# of a doubly-robust best linear projection of the forest's OOB CATEs on a single
# 0/1 contrast (grf handles the DR scores and matched-pair clustering). The slope
# equals the difference in the two subgroup CATEs shown in column (3); its p-value
# is Benjamini-Yekutieli adjusted across the 15 characteristics below.
blp_slope <- function(ind, sub) {
  A <- matrix(as.numeric(ind), ncol = 1)
  A[-sub, ] <- 0                          # rows outside the subset are ignored; avoid NA
  b <- best_linear_projection(cf, A, subset = sub)
  c(est = unname(b[2, 1]), p = unname(b[2, 4]))   # row 2 = slope; cols: Est, SE, t, Pr(>|t|)
}

# Emit ONE table row for a single 0/1 subgroup indicator. qcell = the covariate's
# Benjamini-Yekutieli q-value string, shown once (on the covariate's first row).
emit_one <- function(rowlabel, impcell, side, ind, keep, qcell = "") {
  c8 <- blp_int(ind, keep)
  s  <- shr(as.numeric(ind) == 1)
  # console diagnostic: subgroup size and number of matched-pair clusters
  n_i <- sum(as.numeric(ind) == 1 & keep, na.rm = TRUE)
  n_c <- length(unique(clus[which(as.numeric(ind) == 1 & keep)]))
  cat(sprintf("  [%s / %s] n=%d clusters=%d CATE=%.3f (%.3f)\n",
              trimws(rowlabel), side, n_i, n_c, c8["est"], c8["se"]))
  if (n_i < 30L || n_c < 5L)
    warning(sprintf("thin subgroup '%s/%s': n=%d clusters=%d", trimws(rowlabel), side, n_i, n_c))
  sprintf("%s && %s && %s && %.3f & %.3f && %.3f & %.3f & %.3f && %s \\\\",
          rowlabel, impcell, side, c8["est"], c8["se"],
          s["weak"], s["strong"], s["strong"] - s["weak"], qcell)
}

# Emit the row(s) for one covariate spec. The Benjamini-Yekutieli q-value is one per
# characteristic, printed once on the block's anchor row (spec$qanchor); for grade and
# the baseline quartile that anchor row carries a single contrast (see qdef below).
emit_rows <- function(spec) {
  x  <- as.numeric(students_program[[spec$var]])
  ok <- !is.na(x)
  impv <- imp[[spec$var]]
  qc   <- if (isTRUE(spec$qanchor)) fmt_q(q_by[[spec$qkey]]) else ""
  if (spec$type == "binary") {
    c(emit_one(spec$label, fmt_imp(impv), "Yes", x == 1, ok, qc),
      emit_one("",         "",           "No",  x == 0, ok))
  } else if (spec$type == "level") {
    emit_one(spec$label, fmt_imp(impv), "", x == 1, ok, qc)   # qc is "" unless this is the block's anchor row
  } else if (spec$type == "cont") {
    med <- median(x, na.rm = TRUE)
    lo  <- x <  med
    hi  <- x >= med
    c(emit_one(spec$label, fmt_imp(impv), "Low",  lo, ok, qc),
      emit_one("",         "",           "High", hi, ok))
  } else stop("unknown spec type: ", spec$type)
}

# Panels in the PRE-REGISTERED order (no importance sorting).
panel_student <- list(
  list(label = "Female",                     type = "binary", var = "female",   qkey = "female",   qanchor = TRUE),
  list(label = "Bottom quartile",            type = "level",  var = "bottom",   qkey = "quartile", qanchor = TRUE),
  list(label = "Middle two quartiles",       type = "level",  var = "middle",   qkey = "quartile", qanchor = FALSE),
  list(label = "Top quartile",               type = "level",  var = "top",      qkey = "quartile", qanchor = FALSE),
  list(label = "Grade 1",                    type = "level",  var = "grade1",   qkey = "grade",    qanchor = TRUE),
  list(label = "Grade 2",                    type = "level",  var = "grade2",   qkey = "grade",    qanchor = FALSE),
  list(label = "Grade 3",                    type = "level",  var = "grade3",   qkey = "grade",    qanchor = FALSE),
  list(label = "Grade 4",                    type = "level",  var = "grade4",   qkey = "grade",    qanchor = FALSE),
  list(label = "Grade 5",                    type = "level",  var = "grade5",   qkey = "grade",    qanchor = FALSE),
  list(label = "Grade 6",                    type = "level",  var = "grade6",   qkey = "grade",    qanchor = FALSE),
  list(label = "Baseline score",             type = "cont",   var = "bl_theta", qkey = "bl_theta", qanchor = TRUE),
  list(label = "Grade point average",        type = "cont",   var = "gpa",      qkey = "gpa",      qanchor = TRUE),
  list(label = "Ever repeated",              type = "binary", var = "repeated", qkey = "repeated", qanchor = TRUE),
  list(label = "Ever qualified for Tayssir", type = "binary", var = "tayssir",  qkey = "tayssir",  qanchor = TRUE)
)
panel_school <- list(
  list(label = "Number of teachers",              type = "cont",   var = "n_teachers",          qkey = "n_teachers",          qanchor = TRUE),
  list(label = "Urban",                           type = "binary", var = "urban",               qkey = "urban",               qanchor = TRUE),
  list(label = "Regional development",            type = "binary", var = "regional_dev",        qkey = "regional_dev",        qanchor = TRUE),
  list(label = "Total enrollment (2021/22)",      type = "cont",   var = "total_enrolled7_sum", qkey = "total_enrolled7_sum", qanchor = TRUE),
  list(label = "Female students (\\%)",           type = "cont",   var = "perc_female",         qkey = "perc_female",         qanchor = TRUE),
  list(label = "Tayssir beneficiaries (\\%)",     type = "cont",   var = "perc_tayssir",        qkey = "perc_tayssir",        qanchor = TRUE),
  list(label = "Social security beneficiaries (\\%)", type = "cont", var = "perc_ssbenef",      qkey = "perc_ssbenef",        qanchor = TRUE),
  list(label = "Average grade-6 exam score",      type = "cont",   var = "avg_score7_mu",       qkey = "avg_score7_mu",       qanchor = TRUE)
)

# Guard: every displayed variable must be a forest covariate (has importance).
disp_vars <- vapply(c(panel_student, panel_school), function(s) s$var, character(1))
stopifnot(all(disp_vars %in% names(imp)))

# Column (8): for each of the 15 characteristics, the DR best-linear-projection
# slope-p that the CATE differs across its groups, Benjamini-Yekutieli adjusted
# (p.adjust "BY"; pre-registered for this exploratory forest heterogeneity). Binary
# and median-split characteristics use their two groups; the two multi-category ones
# use a single pre-specified contrast: grades 1-3 vs 4-6, and the top vs bottom
# baseline quartile (bottom-or-top subsample, mirroring Table 2, Panel C).
sp      <- students_program
medhi   <- function(v) { x <- as.numeric(sp[[v]]); as.numeric(x >= median(x, na.rm = TRUE)) }
obsidx  <- function(v) which(!is.na(as.numeric(sp[[v]])))
gradeUp <- as.numeric(sp$grade4 == 1 | sp$grade5 == 1 | sp$grade6 == 1)
qdef <- list(
  female   = list(ind = as.numeric(sp$female == 1),   sub = obsidx("female")),
  quartile = list(ind = as.numeric(sp$top == 1),      sub = which(sp$bottom == 1 | sp$top == 1)),
  grade    = list(ind = gradeUp,                      sub = which(!is.na(gradeUp))),
  bl_theta = list(ind = medhi("bl_theta"),            sub = obsidx("bl_theta")),
  gpa      = list(ind = medhi("gpa"),                 sub = obsidx("gpa")),
  repeated = list(ind = as.numeric(sp$repeated == 1), sub = obsidx("repeated")),
  tayssir  = list(ind = as.numeric(sp$tayssir == 1),  sub = obsidx("tayssir")),
  n_teachers          = list(ind = medhi("n_teachers"),              sub = obsidx("n_teachers")),
  urban               = list(ind = as.numeric(sp$urban == 1),        sub = obsidx("urban")),
  regional_dev        = list(ind = as.numeric(sp$regional_dev == 1), sub = obsidx("regional_dev")),
  total_enrolled7_sum = list(ind = medhi("total_enrolled7_sum"),     sub = obsidx("total_enrolled7_sum")),
  perc_female         = list(ind = medhi("perc_female"),             sub = obsidx("perc_female")),
  perc_tayssir        = list(ind = medhi("perc_tayssir"),            sub = obsidx("perc_tayssir")),
  perc_ssbenef        = list(ind = medhi("perc_ssbenef"),            sub = obsidx("perc_ssbenef")),
  avg_score7_mu       = list(ind = medhi("avg_score7_mu"),           sub = obsidx("avg_score7_mu"))
)
qres  <- lapply(qdef, function(z) blp_slope(z$ind, z$sub))
raw_p <- vapply(qres, function(z) z[["p"]], numeric(1))
q_by  <- setNames(as.list(p.adjust(raw_p, method = "BY")), names(qdef))
cat("\nCATE-difference test (DR-BLP slope; est ~ column-3 gap; raw p; BY q):\n")
for (k in names(qdef))
  cat(sprintf("  %-22s est=%+.3f  p=%.4f  q(BY)=%.4f\n",
              k, qres[[k]][["est"]], raw_p[[k]], q_by[[k]]))

panel_header <- function(title) sprintf("\\textbf{%s} & & & & & & & & & & & & & \\\\", title)
emit_panel   <- function(title, specs) c(panel_header(title), unlist(lapply(specs, emit_rows)))

lines <- c(
  emit_panel("Panel A: Student characteristics", panel_student),
  "\\midrule",
  emit_panel("Panel B: School characteristics", panel_school),
  "\\midrule",
  sprintf("Group-average ITT effect && && && && & %.3f & %.3f & %.3f && \\\\",
          ate_weak[["estimate"]], ate_strong[["estimate"]], gate_diff),
  sprintf(" && && && && & (%.3f) & (%.3f) & (%.3f) && \\\\",
          ate_weak[["std.err"]], ate_strong[["std.err"]], gate_diff_se),
  sprintf("RATE $p$-value && && && && & & & %s && \\\\",
          ifelse(is.na(rate_p), "--",
                 ifelse(rate_p < 0.001, "$<$0.001", sprintf("%.3f", rate_p)))))

writeLines(lines, file.path(tabdir, "tablea4_forest.txt"))
cat("\nTable A4 written to output/tables/tablea4_forest.txt:\n")
cat(lines, sep = "\n"); cat("\n")

################################################################################
# 3b. Soft cross-check: BLP intercept == AIPW subgroup ATE (saturated indicator)
################################################################################
try({
  chk <- function(ind, keep) {
    ss_ <- which(as.numeric(ind) == 1 & keep)
    a   <- average_treatment_effect(cf, subset = ss_)[["estimate"]]
    b   <- blp_int(ind, keep)["est"]
    abs(a - b)
  }
  d_fem  <- chk(students_program$female == 1, !is.na(students_program$female))
  d_top  <- chk(students_program$top    == 1, !is.na(students_program$top))
  cat(sprintf("\nCross-check |BLP intercept - AIPW ATE|: female=%.2e, top-quartile=%.2e\n",
              d_fem, d_top))
  if (max(d_fem, d_top) > 1e-3)
    warning("BLP intercept and AIPW subgroup ATE diverge > 1e-3; check saturation/labels.")
})

################################################################################
# 4. Forest diagnostics (best-effort; saved to $eltemp; not paper exhibits)
################################################################################
try({
  impd <- data.frame(variable = names(imp), importance = imp)
  impd <- impd[order(-impd$importance), ]
  write.csv(impd, file.path(eltemp, "forest_variable_importance.csv"), row.names = FALSE)
})
try({ cal <- test_calibration(cf); print(cal)
      .wrcoef(cal, file.path(eltemp, "forest_test_calibration.csv")) })
try({ blp <- best_linear_projection(cf, X, subset = which(complete.cases(X))); print(blp)
      .wrcoef(blp, file.path(eltemp, "forest_blp_joint.csv")) })
try({
  rate_oob <- rank_average_treatment_effect(cf, tau.hat, target = "AUTOC")
  write.csv(data.frame(estimate = rate_oob$estimate, std.err = rate_oob$std.err),
            file.path(eltemp, "forest_rate_oob.csv"), row.names = FALSE)
  png(file.path(eltemp, "forest_rate_autoc.png"))
  plot(rate_oob, xlab = "Treated fraction"); dev.off()
})

cat("\n05-Table4 complete.\n")
