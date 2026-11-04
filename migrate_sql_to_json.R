# migrate_sqlite_to_json.R
# One-time: copies owners, schedule, and teams from the old SQLite database into
# the JSON store, one season at a time. Needs DBI and RSQLite installed locally
# (the pipeline itself no longer does). From the repo root:
#
#   Rscript tools/migrate_sqlite_to_json.R data/league.sqlite
#
# Afterwards, run weekly.R and compare rankings.json with the old output before
# deleting the database. Delete this script once you are done with it.
#
# UNTESTED.

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
})

source(here::here("pipeline", "store.R"))

args <- commandArgs(trailingOnly = TRUE)
db_path <- if (length(args)) args[1] else here::here("data", "league.sqlite")
con <- dbConnect(SQLite(), db_path)
on.exit(dbDisconnect(con))

seasons <- dbGetQuery(con, "SELECT DISTINCT season FROM teams ORDER BY season")$season

for (s in seasons) {
  message("Season ", s)
  
  for (tbl_name in c("owners", "schedule")) {
    df <- dbGetQuery(con, sprintf("SELECT * FROM %s WHERE season = %d", tbl_name, s))
    write_store_json(df, file.path(store_dir(s), paste0(tbl_name, ".json")))
  }
  
  teams <- dbGetQuery(con, sprintf("SELECT * FROM teams WHERE season = %d", s))
  for (w in sort(unique(teams$week))) {
    write_teams_week(filter(teams, week == w), s, w)
  }
}

message("Done. Check data/{season}/ before removing the database.")