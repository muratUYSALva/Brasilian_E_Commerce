--   ------  ORDER ANALYSIS ------

-- Examine the order distribution on a monthly basis.

select date_trunc('month', order_approved_at) as order_months,
count(order_id) 
from orders
where order_approved_at is not null
group by 1 
order by 1

-- Check the order numbers in the order status breakdown on a monthly basis.

select date_trunc('month', order_approved_at) as order_months, 
order_status, 
count(order_id) as order_count
from orders
group by 1,2
order by 1

select date_trunc('month', order_approved_at) as order_months, 
order_status, 
count(order_id) as order_count
from orders
group by 2,1
order by 2

--Check out the order numbers in the product category breakdown.
--What are the prominent categories on special days? For example, New Year's Eve, Valentine's Day...

select product_category_name,
date_trunc('month', order_approved_at) as months,
count(oi.order_id)
from products as p
inner join order_items as oi
on oi.product_id = p.product_id
inner join orders as o
on oi.order_id=o.order_id
where product_category_name is not null
and date_trunc('month', order_approved_at) is not null
group by 1,2
order by 1 desc, 2 asc

-- Examine the order numbers on the basis of days of the week (Monday, Thursday) and month days
-- (such as the 1st, 2nd of the month).

select
to_char(order_approved_at, 'day') as "days of week",
count(order_id) as order_count
from orders
where to_char(order_approved_at, 'day') is not null
group by 1
order by 2

select
to_char(order_approved_at, 'dd') as days_of_month,
count(order_id) as order_count
from orders
where to_char(order_approved_at, 'dd') is not null
group by 1
order by 2

--   ------ CUSTOMER ANALYSIS ------
-- In which cities do customers shop more?
-- Determine the customer's city as the city from which they place the most orders and
-- perform the analysis accordingly.

WITH order_counts AS (
        SELECT o.customer_id,
               customer_city,
               count(order_id) AS order_count
          FROM orders AS o
          LEFT JOIN customers AS c
            ON c.customer_id = o.customer_id
         GROUP BY 1,
                  2
       ),
       customer_city_rn AS (
        SELECT row_number() OVER (PARTITION BY customer_id ORDER BY order_count DESC) AS rn,
               customer_id,
               customer_city
          FROM order_counts
       ),
       customer_city AS (
        SELECT customer_id,
               customer_city
          FROM customer_city_rn
         WHERE rn = 1
       ) 
SELECT cc.customer_city,
       count(o.order_id)
  FROM orders AS o
  LEFT JOIN customer_city AS cc
    ON o.customer_id = cc.customer_id
 GROUP BY 1
 ORDER BY 2 desc

-- Examine the categories of customer-based orders.
-- Do customers often order products in the same category?
-- Calculate order category percentage for each customer

select
customer_unique_id,
product_category_name,
count(*) as order_count,
(percent_rank() over (partition by customer_unique_id order by count(*)))*100 as category_percentage
from customers
inner join orders using (customer_id)
inner join order_items using (order_id)
inner join products using (product_id)
group by 1,2

-- **************
with with_category_name as(
select
customer_unique_id,
product_category_name,
count(*) as category_order_count
from customers
inner join orders using (customer_id)
inner join order_items using (order_id)
inner join products using (product_id)
group by 1,2
),
without_category_name as(
select
customer_unique_id,
count(*) as customer_order_count
from customers
inner join orders using (customer_id)
inner join order_items using (order_id)
inner join products using (product_id)
group by 1
)
select 
wcn.customer_unique_id,
wcn.product_category_name,
wcn.category_order_count,
ocn.customer_order_count,
round((wcn.category_order_count*1.0/ocn.customer_order_count*1.0)*100, 0) as percentage
from with_category_name as wcn
left join
without_category_name as ocn
using(customer_unique_id)
where round((wcn.category_order_count*1.0/ocn.customer_order_count*1.0)*100, 0) <> 100

--  ------ VENDOR ANALYSIS ----------
-- Who are the sellers who deliver orders to customers in the fastest way?
-- Bring the top 5. Examine and comment on the order numbers of these sellers 
-- and the comments and ratings on their products.

select 
avg(order_delivered_customer_date::date - order_purchase_timestamp::date)::integer  as date_dif,
Round(avg(review_score), 1) as review_score_average,
sum(payment_value) as payment_total,
count(o.order_id) as order_count,
s.seller_id
from orders as o
inner join order_items as oi
on o.order_id = oi.order_id
inner join sellers as s
on oi.seller_id= s.seller_id
inner join order_reviews as orr
on o.order_id = orr.order_id
inner join order_payments as op
on o.order_id = op.order_id
where (order_delivered_customer_date::date - order_purchase_timestamp::date)::integer is not null
group by 5
order by 1, 4 desc
limit 10

select 
avg(order_delivered_customer_date::date - order_purchase_timestamp::date)::integer  as date_dif,
Round(avg(review_score), 1) as review_score_average,
sum(payment_value) as payment_total,
count(o.order_id) as order_count,
s.seller_id
from orders as o
inner join order_items as oi
on o.order_id = oi.order_id
inner join sellers as s
on oi.seller_id= s.seller_id
inner join order_reviews as orr
on o.order_id = orr.order_id
inner join order_payments as op
on o.order_id = op.order_id
where (order_delivered_customer_date::date - order_purchase_timestamp::date)::integer is not null
group by 5
order by 1, 4 desc
limit 10

-- Which sellers sell products from more categories?
-- Do sellers with many categories also have a high number of orders?

with spc as(select seller_id,
product_category_name,
count(order_id) as order_count,
sum(price) as total_price
from sellers as s
inner join order_items as oi
using(seller_id)
inner join products as p
using(product_id)
group by 1,2)
select 
seller_id,
count(product_category_name) as product_category_count,
sum(order_count) as total_order_count,
sum(total_price)::integer as total_sales
from spc
group by 1
order by 2 desc, 3 desc, 4 desc
--order by 3 desc, 2 desc, 4 desc
--order by 4 desc, 3 desc, 2 desc

-- ------- PAYMENT ANALYSIS -------
-- In which region do most users with a high number of installments live?

select 
count(customer_unique_id) as customer_count,
customer_state,
payment_installments
from customers as c
inner join orders as o
using(customer_id)
inner join order_payments
using(order_id)
group by 2,3
--order by 3 desc, 1 desc
order by 3 desc, 1 desc

select 
count(customer_unique_id) as customer_count,
customer_state,
case
when payment_installments <6 then '1-5'
when payment_installments between 6 and 10 then '6-10'
when payment_installments between 11 and 15 then '11-15'
when payment_installments between 16 and 20 then '16-20'
else '20+' end as installment_group
from customers as c
inner join orders as o
using(customer_id)
inner join order_payments
using(order_id)
group by 3,2
order by 3 desc, 1 desc


select 
count(customer_unique_id) as customer_count,
customer_state,
payment_installments
from customers as c
inner join orders as o
using(customer_id)
inner join order_payments
using(order_id)
group by 2,3
order by 3 desc, 1 desc

select 
customer_state,
avg(payment_installments)
from customers as c
inner join orders as o
using(customer_id)
inner join order_payments
using(order_id)
group by 1
order by 2 desc

-- Calculate the number of successful orders and total successful payment amount according to payment type.
--List in order from the most used payment type to the least.

select op.payment_type,
count(distinct o.order_id) ORDER_COUNT,
sum(op.payment_value)::integer AS TOTAL_PAYMENT
from orders as o
right join order_payments as op
using(order_id)
where  o.order_status NOT IN ('cancelled','unavailable')
group by 1
order by 2 desc

-- Make a category-based analysis of orders paid in one shot and in installments.
-- In which categories is payment in installments used most?

select 
case when payment_installments = 1 then 'no_installments'
else 'on_installments' end
as installment_case, 
p.product_category_name,
count(order_id) as order_count 
from order_payments as op
inner join order_items as oi
using(order_id)
inner join products as p
using(product_id)
where payment_installments !=0
group by 1,2
order by 1 desc, 3 desc

select * from e_commerce_data where customer_id = '16446'
order by 1 asc 

-- category-based analysis of orders paid in one shot

with tek_çekim as (
select  count(distinct o.order_id) as order_count_tek_çekim,
	    p.product_category_name as category_name
from orders as o
left join order_items as oi
	ON oi.order_id = o.order_id
left join products as p
	ON oi.product_id = p.product_id
left join order_payments as op
	ON op.order_id = o.order_id
where op.payment_installments = 1
group by 2
order by 1 desc
)
-- category-based analysis of orders paid in installments
,taksit as        (
select  count(distinct o.order_id) as order_count_taksit,
		p.product_category_name as category_name 
from orders as o
left join order_items as oi
	ON oi.order_id = o.order_id
left join products as p
	ON oi.product_id = p.product_id
left join order_payments as op
	ON op.order_id = o.order_id
where op.payment_installments > 1 and payment_type = 'credit_card'
group by 2
order by 1 desc
				  )
select tç.*,
	   t.order_count_taksit
from tek_çekim as tç
left join taksit as t 
	ON t.category_name = tç.category_name
where tç.category_name is not null 
and t.order_count_taksit is not null
order by t.order_count_taksit desc


--  ------- RFM -------

with rfm_data as (select customer_id,
'2011-12-09'-max(invoice_date)::date as recency,
			case
			when '2011-12-09'-max(invoice_date)::date between 0 and 6 then 'R-1'
			when '2011-12-09'-max(invoice_date)::date between 7 and 30 then 'R-2'
			when '2011-12-09'-max(invoice_date)::date between 31 and 61 then 'R-3'
			else 'R-4' end
						as recency_segment,
			count(distinct invoice_no) as frequency,
case
			when count(distinct invoice_no)  between 1 and 2 then 'F-4'
			when count(distinct invoice_no) between 3 and 10 then 'F-3'
			when count(distinct invoice_no) between 11 and 25 then 'F-2'
			else 'F-1' end
			as frequency_segment,
sum(quantity*unit_price)::integer as monetary,
			case
			when sum(quantity*unit_price)::integer <=0 then 'M-5'
			when sum(quantity*unit_price)::integer between 0 and 200 then 'M-4'
			when sum(quantity*unit_price)::integer between 201 and 2000 then 'M-3'
			when sum(quantity*unit_price)::integer between 2001 and 5000 then 'M-2'
			else 'M-1' end
			as monetary_segment
from e_commerce_data
group by 1)
select * from rfm_data
where recency_segment = 'R-1' and 
frequency_segment= 'F-1' and
monetary_segment = 'M-1'



with rfm_data as (select customer_id,
'2011-12-09'-max(invoice_date)::date as recency,
			case
			when '2011-12-09'-max(invoice_date)::date between 0 and 6 then 4
			when '2011-12-09'-max(invoice_date)::date between 7 and 30 then 3
			when '2011-12-09'-max(invoice_date)::date between 31 and 61 then 2
			else 1 end
						as r_p,
			count(distinct invoice_no) as frequency,
case
			when count(distinct invoice_no)  between 1 and 2 then 1
			when count(distinct invoice_no) between 3 and 10 then 2
			when count(distinct invoice_no) between 11 and 25 then 3
			else 4 end
			as f_p,
sum(quantity*unit_price)::integer as monetary,
			case
			when sum(quantity*unit_price)::integer <=0 then -1
			when sum(quantity*unit_price)::integer between 0 and 200 then 1
			when sum(quantity*unit_price)::integer between 201 and 2000 then 2
			when sum(quantity*unit_price)::integer between 2001 and 5000 then 3
			else 4 end
			as m_p
from e_commerce_data
group by 1)
select
customer_id,
r_p*f_p*m_p as rfm_score
from rfm_data
order by 2 desc

with rfm_data as (select customer_id,
'2011-12-09'-max(invoice_date)::date as recency,
			case
			when '2011-12-09'-max(invoice_date)::date between 0 and 6 then 'R-1'
			when '2011-12-09'-max(invoice_date)::date between 7 and 30 then 'R-2'
			when '2011-12-09'-max(invoice_date)::date between 31 and 61 then 'R-3'
			else 'R-4' end
						as recency_segment,
			count(distinct invoice_no) as frequency,
case
			when count(distinct invoice_no)  between 1 and 2 then 'F-4'
			when count(distinct invoice_no) between 3 and 10 then 'F-3'
			when count(distinct invoice_no) between 11 and 25 then 'F-2'
			else 'F-1' end
			as frequency_segment,
sum(quantity*unit_price)::integer as monetary,
			case
			when sum(quantity*unit_price)::integer <=0 then 'M-5'
			when sum(quantity*unit_price)::integer between 0 and 200 then 'M-4'
			when sum(quantity*unit_price)::integer between 201 and 2000 then 'M-3'
			when sum(quantity*unit_price)::integer between 2001 and 5000 then 'M-2'
			else 'M-1' end
			as monetary_segment
from e_commerce_data
group by 1)
select recency_segment, frequency_segment, monetary_segment,
count(customer_id) from rfm_data
group by 1,2,3
order by 1, 2, 3



with rfm_data as (select customer_id,
'2011-12-09'-max(invoice_date)::date as recency,
			case
			when '2011-12-09'-max(invoice_date)::date between 0 and 6 then 'R-1'
			when '2011-12-09'-max(invoice_date)::date between 7 and 30 then 'R-2'
			when '2011-12-09'-max(invoice_date)::date between 31 and 61 then 'R-3'
			else 'R-4' end
						as recency_segment,
			count(distinct invoice_no) as frequency,
case
			when count(distinct invoice_no)  between 1 and 2 then 'F-4'
			when count(distinct invoice_no) between 3 and 10 then 'F-3'
			when count(distinct invoice_no) between 11 and 25 then 'F-2'
			else 'F-1' end
			as frequency_segment,
sum(quantity*unit_price)::integer as monetary,
			case
			when sum(quantity*unit_price)::integer <=0 then 'M-5'
			when sum(quantity*unit_price)::integer between 0 and 200 then 'M-4'
			when sum(quantity*unit_price)::integer between 201 and 2000 then 'M-3'
			when sum(quantity*unit_price)::integer between 2001 and 5000 then 'M-2'
			else 'M-1' end
			as monetary_segment
from e_commerce_data
group by 1)
select recency_segment, frequency_segment,
count(customer_id) from rfm_data
group by 1,2
order by 1, 2


