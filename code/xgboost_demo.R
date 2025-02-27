library(tidyverse)
library(xgboost)

statcast <- readRDS("data/statcast2024.rds")
statcast <- statcast |>
  select(launch_speed, launch_angle, woba_value) |>
  drop_na()

# Convert to xgboost's preferred format 
dmatrix <- xgb.DMatrix(
  data = as.matrix(select(statcast, launch_speed, launch_angle)),
  label = pull(statcast, woba_value)
)

# Run xgboost.
bst50 <- xgboost(
  data = dmatrix,
  max_depth = 2,
  eta = 1, 
  nrounds = 50,
  objective = "reg:squarederror"
)

# Will be used to make predictions:
pred_df <- statcast |>
  select(-woba_value) |>
  distinct()
# Try to fill in some "holes":
pred_df <- pred_df |>
  bind_rows(pred_df |> mutate(launch_angle = launch_angle - 1)) |>
  bind_rows(pred_df |> mutate(launch_angle = launch_angle + 1)) |>
  bind_rows(pred_df |> mutate(launch_speed = launch_speed - 1)) |>
  bind_rows(pred_df |> mutate(launch_speed = launch_speed + 1)) |>
  distinct()

visualize_fit <- function(bst) {
  pred_df <- pred_df |>
    mutate(pred = predict(bst, as.matrix(pred_df)))
  p <- ggplot(pred_df, aes(launch_speed, launch_angle)) + 
    geom_tile(aes(fill = pred), width = 1, height = 1) +
    scale_fill_viridis_c(option = "plasma") 
  return(p)
}
visualize_fit(bst50)

# Try more rounds:
bst100 <- xgboost(
  data = dmatrix,
  max_depth = 2,
  eta = 1, 
  nrounds = 100,
  objective = "reg:squarederror"
)
visualize_fit(bst100)

bst500 <- xgboost(
  data = dmatrix,
  max_depth = 2,
  eta = 1, 
  nrounds = 500,
  objective = "reg:squarederror"
)
visualize_fit(bst500)

# Use cross validation to select the number of rounds:
params <- list(
  max_depth = 2,
  eta = 1, 
  objective = "reg:squarederror"
)
cvres <- xgb.cv(
  params,
  data = dmatrix,
  nrounds = 500,
  nfold = 5,
  metrics = "rmse"
)
ggplot(cvres$evaluation_log, aes(iter, test_rmse_mean)) +
  geom_line()
ggplot(cvres$evaluation_log |> filter(iter > 200), aes(iter, test_rmse_mean)) +
  geom_line()
ggplot(cvres$evaluation_log |> filter(iter > 200), aes(x = iter)) +
  geom_line(aes(y = test_rmse_mean)) + 
  geom_line(aes(y = test_rmse_mean - 2 * test_rmse_std), linetype = "dashed") +
  geom_line(aes(y = test_rmse_mean + 2 * test_rmse_std), linetype = "dashed")
ggplot(cvres$evaluation_log |> filter(iter > 100), aes(x = iter)) +
  geom_line(aes(y = test_rmse_mean)) + 
  geom_hline(aes(yintercept = min(test_rmse_mean + 2 * test_rmse_std)), linetype = "dashed")

# Add a monotonic constraint so that we aren't rewarding hitters for hitting the ball softly:
mono_params <- list(
  max_depth = 2,
  eta = 0.2, 
  objective = "reg:squarederror",
  monotone_constraints = c(1, 0)
)
mono_cvres <- xgb.cv(
  mono_params,
  data = dmatrix,
  nrounds = 400,
  nfold = 5,
  metrics = "rmse"
)

ggplot(mono_cvres$evaluation_log |> filter(iter > 50), aes(iter, test_rmse_mean)) +
  geom_line()
bst_monotonic <- xgboost(
  data = dmatrix,
  max_depth = 2,
  eta = 0.2, 
  nrounds = 150,
  objective = "reg:squarederror",
  monotone_constraints = c(1, 0)
)
visualize_fit(bst_monotonic)

# Look at effect of eta:
bst_monotonic_large_eta <- xgboost(
  data = dmatrix,
  max_depth = 2,
  eta = 1, 
  nrounds = 150,
  objective = "reg:squarederror",
  monotone_constraints = c(1, 0)
)
visualize_fit(bst_monotonic_large_eta)

# Could also fit multinomial model:
statcast <- readRDS("data/statcast2024.rds")
statcast <- statcast |>
  mutate(total_bases = case_when(
    events == "single" ~ 1,
    events == "double" ~ 2,
    events == "triple" ~ 3,
    events == "home_run" ~ 4,
    TRUE ~ 0
  )) |>
  select(launch_speed, launch_angle, total_bases) |>
  drop_na()

dmatrix <- xgb.DMatrix(
  data = as.matrix(select(statcast, launch_speed, launch_angle)),
  label = pull(statcast, total_bases)
)
params <- list(
  max_depth = 2,
  eta = 1, 
  objective = "multi:softprob",
  num_class = 5
)
multi_cvres <- xgb.cv(params, dmatrix, nrounds = 200, nfold = 5)
ggplot(multi_cvres$evaluation_log |> filter(iter > 20), aes(iter, test_mlogloss_mean)) +
  geom_line()

bst_multi <- xgboost(
  data = dmatrix,
  params = params,
  nrounds = 100
)

# Predictions are returned as one long vector:
preds <- predict(bst_multi, as.matrix(pred_df))
length(preds) / nrow(pred_df)
round(preds[1:5], 4)
# Convert to predicted wOBA:
preds <- matrix(preds, ncol = 5, byrow = TRUE)
# 2024 wOBA constants (see https://www.fangraphs.com/guts.aspx)
preds <- preds %*% c(0, .882, 1.254, 1.590, 2.050) 

pred_df <- pred_df |>
  mutate(pred = preds[, 1])
ggplot(pred_df, aes(launch_speed, launch_angle)) + 
  geom_tile(aes(fill = pred), width = 1, height = 1) +
  scale_fill_viridis_c(option = "plasma") 
