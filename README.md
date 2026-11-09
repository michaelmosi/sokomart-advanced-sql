# SokoMart Kenya Advanced SQL

Name: michael-mosi
Cohort 9, Day 1, 9 November 2026

## How to run

1. Load the SokoMart database from the project package. From the package's `database/` folder:

   ```bash
   psql -d postgres -f 01_create_database.sql
   psql -d luxdevhq_cohort9_advanced_sql -f 02_create_schema.sql
   psql -d luxdevhq_cohort9_advanced_sql -f 03_create_tables.sql
   psql -d luxdevhq_cohort9_advanced_sql -f 04_insert_data.sql
   psql -d luxdevhq_cohort9_advanced_sql -f 05_indexes.sql
   psql -d luxdevhq_cohort9_advanced_sql -f 06_validation.sql
   ```

2. Run the SQL files in order:

   ```bash
   psql -d luxdevhq_cohort9_advanced_sql -f sql/00_practice_drills.sql
   psql -d luxdevhq_cohort9_advanced_sql -f sql/01_section_a.sql
   ```

## Results

| Q | File | Rows | Screenshot |
|---|---|---|---|
| 1 | `sql/01_section_a.sql` | 1,432 above average (of 4,358 buyers in 2025) | [q01](screenshots/q01_big_spenders_2025.png) |
| 2 | `sql/01_section_a.sql` | 104 | [q02](screenshots/q02_premium_products.png) |
| 3 | `sql/01_section_a.sql` | 10 | [q03](screenshots/q03_monthly_pnl_2026.png) |
| 4 | `sql/01_section_a.sql` | 346 (196 bought all five categories) | [q04](screenshots/q04_nakuru_cross_category.png) |
| 5 | `sql/01_section_a.sql` | 18 | [q05](screenshots/q05_never_ordered_products.png) |

## Business insights and recommendations

- **A third of the customers bring in three-quarters of the revenue.** 1,432 of the 4,358 customers
  who bought in 2025 (33%) spent above the average of KES 118,775. Together they made **76.3% of
  2025's KES 517.6M revenue**. The top spender, Tabitha Njeru (Nairobi), spent KES 1.99M (Q1).
  *Recommendation:* invite these 1,432 customers to the loyalty launch first, and track the group's
  revenue every month.
- **January and August are the peak months of 2026, and February and June the quietest.** Revenue
  was KES 57.8M in January and KES 57.6M in August (both back-to-school months), against KES 37.8M in
  February and KES 39.0M in June. That is a 53% swing (Q3). *Recommendation:* build stock of school and
  electronics lines 4 to 6 weeks before January and August, and run promotions in February and June.
- **Margins are steady at about 18 to 19.7%.** Every month from January to October 2026 kept a gross
  margin between 17.97% (June) and 19.65% (May) (Q3), so the swings in profit come from sales volume,
  not pricing. *Recommendation:* put growth effort into volume in the quiet months rather than cutting
  prices.
- **Nakuru is ready for bundles.** 346 Nakuru customers already buy from 3 or more departments, and
  **196 of them buy from all five** (Q4). Nakuru has 418 customers and KES 74.8M of completed revenue
  (D10). *Recommendation:* run the bundle campaign in Nakuru first and measure basket size against
  a control county.
- **18 products have never been ordered** (Q5). Seven of them are active new arrivals listed in
  October 2026, which is normal. The other **11 are out of stock or discontinued** and still take up
  catalogue space. *Recommendation:* remove the discontinued items from the catalogue, decide whether
  to restock or drop the out-of-stock ones, and check the new arrivals again after 60 days.
- **104 of 283 active products (37%) are priced above their category average** (Q2).
  Electronics (29) and Groceries (28) have the most. *Recommendation:* in Section C, compare these
  premium products' sales with the rest of their category to see if the premium price costs sales.

**First change I would make:** start the loyalty programme for the 1,432 above-average 2025
customers. They bring in three-quarters of revenue, so keeping even a few more of them adds more
than any other single action.
