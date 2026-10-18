# 🧹 Global Tech Layoffs — SQL Data Cleaning Pipeline

## 📌 Project Overview
Raw data is rarely ready for analysis or machine learning. In this project, I built an end-to-end **SQL data cleaning pipeline** in **MySQL** using a global dataset of corporate layoffs. The goal was to transform messy, unformatted raw records into a reliable, standardized table ready for Exploratory Data Analysis (EDA) and BI dashboarding.

🔗 **[View Full SQL Script (`data_cleaning.sql`)](./data_cleaning.sql)**

---

## 🛠️ Tech Stack & SQL Skills Demonstrated
* **Database:** MySQL 8.0 (MySQL Workbench)
* **Key Techniques:** 
  * Staging Tables Architecture (preserving raw data integrity)
  * Common Table Expressions (`WITH` / CTEs)
  * Window Functions (`ROW_NUMBER() OVER(PARTITION BY ...)`)
  * String Manipulation (`TRIM`, `LIKE`, `TRAILING`)
  * Date Parsing & Type Conversion (`STR_TO_DATE`, `ALTER TABLE MODIFY COLUMN`)
  * Relational Data Imputation (`SELF JOIN` to populate missing values)

---

## 🔄 Data Cleaning Workflow

### 1. Staging Environment Setup
Instead of modifying the raw `layoffs` table directly, I created staging tables (`layoffs_staging` and `layoffs_staging2`) to ensure safe data transformations and easy rollback if needed.

### 2. Identifying & Removing Duplicates
Because the dataset lacked a unique primary key (`id`), standard duplicate checks weren't enough. I used a **CTE combined with `ROW_NUMBER()`** partitioned across all columns to flag duplicate rows (`row_num > 1`) and safely removed them via a physical staging table.

```sql
WITH duplicate_cte AS (
    SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, 
                     percentage_laid_off, `date`, stage, country, funds_raised_millions
    ) AS row_num
    FROM layoffs_staging
)
SELECT * FROM duplicate_cte WHERE row_num > 1;
```

### 3. Data Standardization
I standardized inconsistent string values across multiple columns and converted raw text dates into proper SQL `DATE` format so time-series analysis could be performed accurately.

* **Company Names:** Removed leading and trailing whitespace using `TRIM(company)`.
* **Industry Consolidation:** Unified inconsistent naming conventions (e.g., merged `'Crypto Currency'` and `'CryptoCurrency'` into `'Crypto'`).
* **Location Cleanup:** Stripped trailing punctuation errors (e.g., `'United States.'` to `'United States'`) using `TRIM(TRAILING '.' FROM country)`.
* **Date Formatting:** Converted the `date` column from raw `TEXT` (`MM/DD/YYYY`) into a native SQL `DATE` data type using `STR_TO_DATE()`.

```sql
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;
```

### 4. Handling NULL & Blank Values (Imputation)
Some companies had missing (`NULL` or blank `''`) values in the `industry` column in one record, while having the industry properly listed in another layoff record. I standardized blanks to `NULL` and executed a **`SELF JOIN`** on `company` to automatically populate missing industries.

```sql
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;
```

### 5. Removing Unusable Records & Helper Columns
Finally, I filtered out records where **both** `total_laid_off` and `percentage_laid_off` were `NULL` (as they provide no quantitative value for layoff analysis) and dropped the temporary `row_num` helper column to finalize the table schema.

```sql
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;
```

---

## 📊 Final Result
The dataset is now completely free of duplicates, properly typed (`DATE`, `INT`, standardized `TEXT`), and ready for downstream Exploratory Data Analysis (EDA) or visualization.
