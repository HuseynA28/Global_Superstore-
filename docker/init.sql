-- Runs automatically the FIRST time the MySQL container starts.
-- Creates the three layers of our data warehouse.

CREATE DATABASE IF NOT EXISTS bronze;   -- raw data, exactly as received
CREATE DATABASE IF NOT EXISTS silver;   -- cleaned and merged data
CREATE DATABASE IF NOT EXISTS gold;     -- star schema, views, ML results (Power BI reads this)

GRANT ALL PRIVILEGES ON bronze.* TO 'de_user'@'%';
GRANT ALL PRIVILEGES ON silver.* TO 'de_user'@'%';
GRANT ALL PRIVILEGES ON gold.*   TO 'de_user'@'%';
FLUSH PRIVILEGES;
