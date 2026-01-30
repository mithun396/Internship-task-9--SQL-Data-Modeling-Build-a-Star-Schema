-- task9_star_schema.sql
-- Star Schema for (Global Superstore compatible)

/* =============================
   1) DIMENSION TABLES
   ============================= */

CREATE TABLE dim_date (
    date_id        INT PRIMARY KEY,
    full_date      DATE NOT NULL,
    year           INT,
    quarter        INT,
    month          INT,
    month_name     VARCHAR(20),
    day            INT
);

CREATE TABLE dim_customer (
    customer_id    SERIAL PRIMARY KEY,
    customer_name  VARCHAR(255),
    segment        VARCHAR(100)
);

CREATE TABLE dim_product (
    product_id     SERIAL PRIMARY KEY,
    product_name   VARCHAR(255),
    category       VARCHAR(100),
    sub_category   VARCHAR(100)
);

CREATE TABLE dim_region (
    region_id      SERIAL PRIMARY KEY,
    region         VARCHAR(100),
    country        VARCHAR(100),
    state          VARCHAR(100),
    city           VARCHAR(100)
);

/* =============================
   2) FACT TABLE
   ============================= */

CREATE TABLE fact_sales (
    sales_id       SERIAL PRIMARY KEY,
    date_id        INT REFERENCES dim_date(date_id),
    customer_id    INT REFERENCES dim_customer(customer_id),
    product_id     INT REFERENCES dim_product(product_id),
    region_id      INT REFERENCES dim_region(region_id),
    order_id       VARCHAR(50),
    quantity       INT,
    sales_amount   NUMERIC(12,2),
    profit         NUMERIC(12,2)
);

/* =============================
   3) POPULATE DIMENSIONS
   (Assuming raw table: orders_raw)
   ============================= */

-- Date Dimension
INSERT INTO dim_date (date_id, full_date, year, quarter, month, month_name, day)
SELECT DISTINCT
    TO_CHAR(order_date, 'YYYYMMDD')::INT AS date_id,
    order_date,
    EXTRACT(YEAR FROM order_date),
    EXTRACT(QUARTER FROM order_date),
    EXTRACT(MONTH FROM order_date),
    TO_CHAR(order_date, 'Month'),
    EXTRACT(DAY FROM order_date)
FROM orders_raw;

-- Customer Dimension
INSERT INTO dim_customer (customer_name, segment)
SELECT DISTINCT customer_name, segment
FROM orders_raw;

-- Product Dimension
INSERT INTO dim_product (product_name, category, sub_category)
SELECT DISTINCT product_name, category, sub_category
FROM orders_raw;

-- Region Dimension
INSERT INTO dim_region (region, country, state, city)
SELECT DISTINCT region, country, state, city
FROM orders_raw;

/* =============================
   4) POPULATE FACT TABLE
   ============================= */

INSERT INTO fact_sales (
    date_id, customer_id, product_id, region_id,
    order_id, quantity, sales_amount, profit
)
SELECT
    TO_CHAR(o.order_date, 'YYYYMMDD')::INT,
    c.customer_id,
    p.product_id,
    r.region_id,
    o.order_id,
    o.quantity,
    o.sales,
    o.profit
FROM orders_raw o
JOIN dim_customer c ON o.customer_name = c.customer_name
JOIN dim_product p ON o.product_name = p.product_name
JOIN dim_region r ON o.region = r.region
                AND o.country = r.country
                AND o.state = r.state
                AND o.city = r.city;

/* =============================
   5) INDEXES
   ============================= */

CREATE INDEX idx_fact_date ON fact_sales(date_id);
CREATE INDEX idx_fact_customer ON fact_sales(customer_id);
CREATE INDEX idx_fact_product ON fact_sales(product_id);
CREATE INDEX idx_fact_region ON fact_sales(region_id);

/* =============================
   6) ANALYTICS QUERIES
   ============================= */

-- Total Sales by Category
SELECT p.category, SUM(f.sales_amount) AS total_sales
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
GROUP BY p.category;

-- Monthly Sales Trend
SELECT d.year, d.month, SUM(f.sales_amount) AS monthly_sales
FROM fact_sales f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- Top 10 Customers by Sales
SELECT c.customer_name, SUM(f.sales_amount) AS total_sales
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.customer_name
ORDER BY total_sales DESC
LIMIT 10;

/* =============================
   7) VALIDATION CHECKS
   ============================= */

-- Fact vs Raw count
SELECT (SELECT COUNT(*) FROM orders_raw) AS raw_count,
       (SELECT COUNT(*) FROM fact_sales) AS fact_count;

-- Missing foreign key matches
SELECT COUNT(*) AS missing_keys
FROM fact_sales
WHERE customer_id IS NULL
   OR product_id IS NULL
   OR region_id IS NULL
   OR date_id IS NULL;
