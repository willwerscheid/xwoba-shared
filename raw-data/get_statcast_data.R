library(baseballr)
library(tidyverse)

# To download data for different seasons, update these variables: ----------

season <- "2024"
# The following two variables can be used for very early season games like the 
#   Seoul or Tokyo series. For seasons without such series, just set the start 
#   and end date to be Opening Day:
first_games_start <- "2024-03-20"
first_games_end <- "2024-03-21"
# The next two variables should capture the date range for all other MLB games:
next_games_start <- "2024-03-28"
next_games_end <- "2024-10-30"

# Request data from the Statcast server one day at a time: -----------

all_res <- statcast_search(first_games_start, first_games_end) # Seoul series (first games)
next_date <- as.Date(next_games_start)
while (next_date <= next_games_end) {
  cat("Downloading data for", as.character(next_date), "\n")
  next_res <- statcast_search(next_date, next_date)
  if (nrow(next_res) > 0) {
    all_res <- all_res |> bind_rows(next_res)
  }
  next_date <- next_date + 1
  Sys.sleep(rexp(3))
}

# Check that all dates downloaded successfully:
table(all_res$game_type)

# Type of Game. E = Exhibition, S = Spring Training, R = Regular Season, 
# F = Wild Card, D = Divisional Series, L = League Championship Series, W = World Series

## Filter out spring training and exhibition games: ----------
all_res1 <- all_res |>
  filter(game_type != "S", game_type != "E")

saveRDS(all_res1, paste0("./Data/statcast", season, "all.rds"))

## Filter out playoffs (MLB doesn't use playoff games in xwOBA calculations): ----------
all_res2 <- all_res1 |>
  filter(game_type == "R")

saveRDS(all_res2, paste0("./Data/statcast", season, "regularseason.rds"))
