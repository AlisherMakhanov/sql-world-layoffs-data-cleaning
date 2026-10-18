-- ============================================================================
-- DATA CLEANING PROJECT: Global Tech Layoffs Dataset (MySQL)
-- ============================================================================
-- Description: End-to-end SQL data cleaning pipeline transforming raw 
--              layoffs data into an analysis-ready dataset.
-- Steps:
--   1. Create Staging Tables (preserve raw data)
--   2. Identify & Remove Duplicates (using CTE & ROW_NUMBER)
--   3. Standardize Data (Strings, Categories, and Date formatting)
--   4. Handle NULL and Blank Values (Data Imputation via SELF JOIN)
--   5. Remove Redundant Rows and Helper Columns
-- ============================================================================

-- Initial check of raw data
SELECT * 
FROM layoffs;

-- ============================================================================
-- STEP 1: Create Staging Table
-- Never work directly on raw tables. Create a staging copy first.
-- ============================================================================

CREATE TABLE layoffs_staging
LIKE layoffs;

INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

-- ============================================================================
-- STEP 2: Remove Duplicates
-- Since there is no unique ID column, we partition across all columns.
-- ============================================================================

-- 2.1 Identify duplicate records using CTE and ROW_NUMBER()
WITH duplicate_cte AS (
    SELECT *,
    ROW_NUMBER() OVER(
        PARTITION BY company, location, industry, total_laid_off, 
                     percentage_laid_off, `date`, stage, country, funds_raised_millions
    ) AS row_num
    FROM layoffs_staging
)
SELECT * 
FROM duplicate_cte
WHERE row_num > 1;

-- Verify a specific duplicate case (e.g., 'Casper')
SELECT *
FROM layoffs_staging
WHERE company = 'Casper';

-- 2.2 In MySQL, we cannot delete directly from a CTE. 
-- We create a second staging table that includes `row_num` as a physical column.
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off, 
                 percentage_laid_off, `date`, stage, country, funds_raised_millions
) AS row_num
FROM layoffs_staging;

-- Delete identified duplicates (where row_num > 1)
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- ============================================================================
-- STEP 3: Standardize Data
-- Clean up whitespace, unify category names, and convert date types.
-- ============================================================================

-- 3.1 Trim leading/trailing spaces in company names
SELECT company, TRIM(company)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

-- 3.2 Standardize industry names (e.g., 'Crypto', 'Crypto Currency', 'CryptoCurrency' -> 'Crypto')
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- 3.3 Clean up trailing periods in country names (e.g., 'United States.' -> 'United States')
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- 3.4 Convert `date` column from text string (MM/DD/YYYY) to standard SQL DATE format
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- ============================================================================
-- STEP 4: Handle NULL and Blank Values
-- ============================================================================

-- 4.1 Check for missing values in `industry`
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL 
   OR industry = '';

-- Convert blank strings ('') to NULL to simplify joins
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Preview self-join matches where another record of the same company has the industry populated
SELECT t1.company, t1.industry AS missing_industry, t2.industry AS populated_industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Populate missing `industry` values using SELF JOIN
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Verify remaining cases (e.g., 'Bally''s Interactive' has only 1 row, so no match to populate from)
SELECT *
FROM layoffs_staging2
WHERE company LIKE 'Bally%';

-- ============================================================================
-- STEP 5: Remove Unusable Rows and Helper Columns
-- ============================================================================

-- 5.1 Identify and remove rows where both `total_laid_off` and `percentage_laid_off` are NULL
-- (These records hold no analytical value for layoff metrics)
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- 5.2 Drop the temporary `row_num` column used for deduplication
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- Final check of the cleaned dataset
SELECT *
FROM layoffs_staging2;
