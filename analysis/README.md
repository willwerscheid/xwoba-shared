TODO:

  - Try to reverse engineer MLB's xwOBA model
    - Decide which of our models matches best (regression or multinomial; kNN, GAM, or xgboost).
    - Re-run using 3 (5?) years of data.
    - See whether we can get closer by adding sprint speed.
  - See whether incorporating spray angle improves year-to-year predictive performance (Riley, Khue, Jack).
  - Develop park-specific xwOBA models (Haley, Justin, Chris G; Luke, Chris A).
     - Need to deal with smaller sample sizes.
         - Might be enough to collect more data.
     - Quality of home-team defense is a confounder.
         - Control for team defense by looking at opponents' hitting outcomes home and away?
         - Ignore home-team defense by looking at team's hitting outcomes home and away?
         - Model *differences* in outcomes (using GAMs?), just looking at games that a team played in.
     - Calculate park-specific xwOBAs for each player; see who gains and loses the most in each park (relative to baseline).
