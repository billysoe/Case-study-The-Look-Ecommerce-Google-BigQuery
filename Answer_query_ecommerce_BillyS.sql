/*
--1. Market Growth & Financial Health (The Growth)
Kategori ini bertujuan memberikan gambaran besar mengenai kesehatan bisnis secara finansial.
Sub-point A: Revenue & Profitability Trend
-Analisa pertumbuhan bulanan (Month-over-Month) untuk melihat apakah bisnis sedang naik atau melandai.
-Menghitung Gross Profit Margin per kategori produk (menggunakan sale_price vs cost).

Sub-point B: Order Life Cycle Analysis
-Berapa persentase pesanan yang berakhir dengan status Cancelled atau Returned?
-Dampak finansial dari tingginya angka pengembalian barang (lost revenue analysis).

Sub-point C: Average Order Value (AOV)
Apakah pelanggan cenderung belanja lebih banyak per transaksi dari waktu ke waktu?

2. Customer Behavior & Segmentation (The People)
Kategori ini mencoba memahami siapa pelanggan kita dan bagaimana loyalitas mereka.
Sub-point A: Retention Rate & Churn
-Persentase pelanggan yang melakukan pembelian kedua (Repeat Purchase Rate).

Sub-point B: Geographic Hotspots
Pemetaan negara atau kota dengan konsentrasi user tertinggi.

Sub-point C: Demographic Insights
Analisis preferensi belanja berdasarkan jenis kelamin dan usia untuk membantu tim Marketing melakukan targeted advertising.

3. Product Performance (The Goods)
Kategori ini fokus pada apa yang dijual dan bagaimana mengoptimalkan stok.

-BCG Matrics - Top & Bottom Performing Categories
Produk "Superstar" (Volume tinggi, margin tinggi) vs Produk "Zombie" (low sales volume,low margin).
*/


--answer 1 Sub A-1  YoY Growth
WITH totalrev_year as
    (SELECT 
        FORMAT_TIMESTAMP('%Y', created_at) AS year, -- Hasil: '2021-11'
        ROUND(SUM(sale_price),2) AS revenue
    FROM `bigquery-public-data.thelook_ecommerce.order_items`
    WHERE status IN ('Processing', 'Shipped', 'Complete')
    GROUP BY 1
    ORDER BY 1 DESC)
,
revenue_with_lag AS (
  -- Langkah 2: Ambil data revenue bulan lalu untuk dibandingkan
  SELECT 
    year,
    revenue,
    LAG(revenue) OVER (ORDER BY year) AS last_year_revenue
  FROM totalrev_year
)
SELECT 
  year,
  revenue AS current_year_revenue,
  last_year_revenue,
  ROUND(((revenue - last_year_revenue) / last_year_revenue) * 100, 2) AS yoy_growth_pct
FROM revenue_with_lag
ORDER BY year DESC;


--alternate ans 1 Sub A-1 : kalau yg ditanya pertumbuhan bulanan (MoM)
WITH totalrev_month as
    (SELECT 
        FORMAT_TIMESTAMP('%Y-%m', created_at) AS month, -- Hasil: '2021-11'
        ROUND(SUM(sale_price),2) AS revenue
    FROM `bigquery-public-data.thelook_ecommerce.order_items`
    WHERE status IN ('Processing', 'Shipped', 'Complete')
    GROUP BY 1
    ORDER BY 1 DESC)
,
revenue_with_lag AS (
  -- Langkah 2: Ambil data revenue bulan lalu untuk dibandingkan
  SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS last_month_revenue
  FROM totalrev_month
)
SELECT 
  month,
  revenue AS current_month_revenue,
  last_month_revenue,
  ROUND(((revenue - last_month_revenue) / last_month_revenue) * 100, 2) AS mom_growth_pct
FROM revenue_with_lag
ORDER BY month DESC;

--answer 1 Sub A-2 Gross Profit Margin per kategori produk
SELECT
      p.category as product_category,
      ROUND(COUNT(oi.product_id),2) AS total_qty_sold,
      ROUND(AVG(oi.sale_price),2) AS avg_price,
      ROUND(sum(oi.sale_price),2) as total_revenue,
      ROUND(sum(p.cost),2) as total_cost,
      ROUND(sum(oi.sale_price-p.cost),2) as gross_margin,
      ROUND((sum(oi.sale_price-p.cost) / sum(oi.sale_price)),2) as gross_margin_pct

from bigquery-public-data.thelook_ecommerce.products as p
join bigquery-public-data.thelook_ecommerce.order_items as oi
on p.id = oi.product_id 
WHERE oi.status IN ('Complete', 'Shipped', 'Processing')
group by product_category
order by gross_margin_pct desc;

--answer 1 Sub B-1 Berapa persentase pesanan yang berakhir dengan status Cancelled atau Returned?
select
      oi.status as status,
      count(*) as total_status,
      round(count(*) / sum(count(*)) over(), 2) as total_status_pct
from bigquery-public-data.thelook_ecommerce.order_items as oi
group by status
order by 
    case 
        when status = 'Cancelled' then 1 
        when status = 'Returned' then 2 
        else 3
    end asc;

--answer 1 Sub B-2 Dampak finansial dari tingginya angka pengembalian barang (lost revenue analysis).
select
        oi.status as status,
        round(avg(case when oi.status = 'Returned' then oi.sale_price else 0 end),2) as avg_returned_price,
        count(CASE WHEN oi.status = 'Returned' THEN oi.id END) AS returned_qty,
        round(sum(case when oi.status = 'Returned' then oi.sale_price else 0 end),2) as total_loss_revenue,
        round(sum(case when oi.status = 'Returned' then oi.sale_price-p.cost else 0 end),2) as total_loss_profit,
        round(sum(case when oi.status = 'Returned' then oi.sale_price-p.cost else 0 end),2) / 
        NULLIF(SUM(CASE WHEN oi.status = 'Returned' THEN oi.sale_price ELSE 0 END), 0) AS avg_loss_margin_pct
from bigquery-public-data.thelook_ecommerce.order_items as oi
join bigquery-public-data.thelook_ecommerce.products as p
on oi.product_id = p.id
group by oi.status
HAVING oi.status = 'Returned';


--answer 1 Sub C-1 : AOV tahun ke tahun?
select
        EXTRACT(YEAR FROM created_at) as year,
        ROUND(SUM(oi.sale_price),2) as total_revenue,
        count(distinct oi.order_id) as total_order_qty,
        ROUND(SUM(oi.sale_price) / count(distinct oi.order_id),2) as AOV

from bigquery-public-data.thelook_ecommerce.order_items as oi
where oi.status IN ('Complete', 'Shipped', 'Processing')
group by 1
order by year asc;


--answer 2 Sub A-1 : Retention Rate & Churn
WITH user_activity AS (
    SELECT 
        user_id,
        MAX(created_at) as last_order_date,
        -- Di dataset TheLook, data terbaru ada di tahun 2026
        -- Kita ambil tanggal terbaru dari seluruh tabel sebagai titik "Hari Ini"
        (SELECT MAX(created_at) FROM `bigquery-public-data.thelook_ecommerce.order_items`) as today
    FROM `bigquery-public-data.thelook_ecommerce.order_items`
    GROUP BY 1
),
churn_status AS (
    SELECT 
        user_id,
        last_order_date,
        -- Menghitung selisih bulan antara hari ini dan order terakhir
        DATE_DIFF(DATE(today), DATE(last_order_date), MONTH) as months_since_last_order
    FROM user_activity
)

SELECT 
    CASE 
        WHEN months_since_last_order >= 6 THEN 'Churned (>= 6 Months)'
        ELSE 'Active'
    END as customer_status,
    COUNT(user_id) as total_users,
    ROUND(COUNT(user_id) / SUM(COUNT(user_id)) OVER(), 3) as percentage
FROM churn_status
GROUP BY 1;

--answer 2 Sub B : Geographic Hotspot
SELECT 
    u.country,
    COUNT(DISTINCT u.id) AS total_users,
    ROUND(SUM(oi.sale_price), 2) AS total_revenue,
    ROUND(AVG(oi.sale_price), 2) AS avg_item_price
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
JOIN `bigquery-public-data.thelook_ecommerce.users` AS u 
    ON oi.user_id = u.id
WHERE oi.status IN ('Complete', 'Shipped', 'Processing')
GROUP BY u.country
ORDER BY total_users DESC
LIMIT 10;

--answer 2 Sub C : Analisis preferensi belanja berdasarkan jenis kelamin dan usia untuk membantu tim Marketing melakukan targeted advertising.
SELECT 
    u.gender,
    -- Membuat pengelompokan umur agar tim Marketing gampang baca datanya
    CASE 
        WHEN u.age < 20 THEN 'Teen (<20)'
        WHEN u.age BETWEEN 20 AND 35 THEN 'Young Adult (20-35)'
        WHEN u.age BETWEEN 36 AND 50 THEN 'Adult (36-50)'
        ELSE 'Senior (>50)'
    END AS age_group,
    COUNT(DISTINCT u.id) AS total_users,
    ROUND(SUM(oi.sale_price), 2) AS total_revenue,
    ROUND(SUM(oi.sale_price) / COUNT(DISTINCT oi.order_id), 2) AS AOV
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
JOIN `bigquery-public-data.thelook_ecommerce.users` AS u 
    ON oi.user_id = u.id
WHERE oi.status IN ('Complete', 'Shipped', 'Processing')
GROUP BY 1, 2
ORDER BY total_revenue DESC;

--answer 3 Sub A-1 : Produk "Superstar" (Volume tinggi, margin tinggi) vs Produk "Zombie" (tidak laku, margin ).

SELECT 
    p.category,
    COUNT(oi.id) AS sales_volume,
    ROUND(SUM(oi.sale_price - p.cost), 2) AS total_profit,
    ROUND(AVG(oi.sale_price - p.cost), 2) AS avg_margin_per_item
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
JOIN `bigquery-public-data.thelook_ecommerce.products` AS p 
    ON oi.product_id = p.id
WHERE oi.status = 'Complete'
GROUP BY 1
ORDER BY sales_volume DESC;


