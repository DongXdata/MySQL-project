/*
OVERVIEW OF THE MAVEN FUZZY FACTORY DATABASE
We will be working with six related tables, which contain eCommerce data about:
• Website Activity
• Products
• Orders and Refunds
We'll use MySQL to understand how customers access and interact with the site, analyze landing page performance and conversion, and explore product-level sales.

I. Analyzing Traffilc Source
II. Analyzing Website Performace
III. Analysis for Channel Portfolio Management
IV. Analysis Business Patterns and Seasonality
V. Product Analysis
VI. User Analysis

*/ 

-- ------------------------------------------------------------------------------------------------------------

/*
I. Analyzing Traffilc Source
	Through the analysis of the Traffic source, to determine which device or source to bid on. 
*/

# 1. FINDING TOP TRAFFIC SOURCES(By the date 0f '2012-04-12')
# Result: 'gsearch', 'nonbrand', 'https://www.gsearch.com' has highest sessions: '3613'

SELECT 
	utm_source,
    utm_campaign,
    http_referer,
    count(distinct website_session_id) as sessions
FROM website_sessions

where created_at < '2012-04-12'
group by 
	utm_source,
    utm_campaign,
    http_referer
order by sessions desc;

# 2.TRAFFIC CONVERSION RATES(CVR of at least 4% to make the numbers work)
# Result1: Even Though 'gsearch', 'nonbrand' has the highest traffic, but the CVR is not that obvious only 0.0296
# Result2: In addition the 'gsearch', 'brand' has a highest CVR = 0.0769 which is higher than 4%

SELECT 
	utm_source,
    utm_campaign,
    http_referer,
    count(distinct web.website_session_id) as sessions,
    count(distinct ord.order_id) as orders,
    count(distinct ord.order_id)/count(distinct web.website_session_id) as conv_rate
FROM website_sessions web
left join orders ord
on web.website_session_id = ord.website_session_id
where web.created_at < '2012-04-12'
group by 
	utm_source,
    utm_campaign,
    http_referer
order by conv_rate desc;

# 3.TRAFFIC SOURCE TRENDING ( bid down gsearch nonbrand on 2012-04-15)
# Result1: 'gsearch' 'nonbrand' is fairly sensitive to bid changes.


SELECT 	
    min(created_at) as start_date,
    count(distinct website_session_id) as sessions
    
FROM website_sessions
where created_at < '2012-05-10'
	and utm_source = 'gsearch'
   and utm_campaign = 'nonbrand'
group by week(created_at);

# 4.TRAFFIC SOURCE BID OPTIMIZATION (mobile device vs the desktop,by date '2012-05-11')
# Result: 'desktop' has more CVR='0.0386'

SELECT
	device_type,
	count(distinct web.website_session_id) as sessions,
    count(distinct ord.order_id) as orders,
    count(distinct ord.order_id)/count(distinct web.website_session_id) as conv_rate
FROM website_sessions web
left join orders ord
on web.website_session_id = ord.website_session_id
where web.created_at < '2012-05-11'
group by 1;

# 5. TRAFFIC SOURCE SEGMENT TRENDING(bid our 'gsearch' 'nonbrand' 'desktop' campaigns up on '2012-05-19')
# by the date of '2012-06-09'
# Result1: desktop is looking strong thanks to the bid changes we made based on the previous CVR analysis.

SELECT
	week(created_at),
    min(date(created_at)) as start_data, 
    count(distinct case when device_type = 'mobile' then website_session_id else NULL END) AS mobile_sessions,
	count(distinct case when device_type = 'desktop' then website_session_id ELSE NULL END) AS desktop_sessions
FROM website_sessions

where created_at < '2012-06-09'
	and created_at > '2012-04-15'
	and utm_source = 'gsearch'
    and utm_campaign = 'nonbrand'
group by 1;


-- ------------------------------------------------------------------------------------------------------------
/*
II. Analyzing Website Performace
use the conversion rate to find out which part of the websites losses most of the customers and then fix that part.
*/

#1. IDENTIFYING TOP WEBSITE PAGES (by the date '2012-06-09')
# Result1: the homepage, the products page, and the Mr. Fuzzy page get the bulk of the traffic

select 
	pageview_url,
    count(distinct website_session_id) AS sessions
from website_pageviews
where created_at < '2012-06-09'
group by 
	pageview_url
order by 2 desc;


#2.IDENTIFYING TOP ENTRY PAGES(by the date '2012-06-12')
# Result1: the traffic all comes in through the homepage right now 

create temporary table table_first_pv_id
select 
	website_session_id,
    min(website_pageview_id) as first_pv_id
from website_pageviews
where created_at < '2012-06-12'
group by website_session_id;


select 
	wpv.pageview_url as landing_page,
    count(fpv.website_session_id) as sessions_hitting_this_page
from table_first_pv_id fpv
left join website_pageviews wpv
on wpv.website_pageview_id = fpv.first_pv_id
group by 1;

# 3.HOMEPAGE BOUNCE RATES(by the date '2012-06-14')
#Result1: the homepage bounce rate = '0.5918'
#the bounce rate is too high, so a new landing page was set up to test the performace

drop table table_first_pv_id;

-- find the first pageview id
create temporary table table_first_pv_id
select 
	website_session_id,
    min(website_pageview_id) as first_pv_id
from website_pageviews
where created_at < '2012-06-14'
group by website_session_id;

-- bring in the landing page, restrict to '/home' only, get all the sessions

create temporary table home_landing_sessions
select
	fpv.website_session_id,
    wpv.pageview_url as landing_page
from table_first_pv_id fpv
left join website_pageviews wpv
on fpv.first_pv_id = wpv.website_pageview_id
where wpv.pageview_url = '/home';

-- count pageviews for sessions above 

create temporary table sessions_with_pageviews
select 
	hls.website_session_id,
    hls.landing_page,
    count(wpv.website_pageview_id) as count_of_pageviews	
from home_landing_sessions hls
left join website_pageviews wpv
on hls.website_session_id = wpv.website_session_id
group by 1,2;

-- calculate the bounce rate
-- when the count_of_pageviews= 1, that means it is bounced, else not

SELECT
    count(website_session_id) as total_sessions,
	sum(if(count_of_pageviews = 1, 1,0)) as bounce_number,
    sum(if(count_of_pageviews = 1, 1,0))/count(website_session_id) as bounce_rate
FROM sessions_with_pageviews;


# 4.ANALYZING LANDING PAGE TESTS (by the date '2012-07-28')
# a new custom landing page (/lander-1) was launched for the 'gsearch' 'nonbrand' traffic
#Result1: bounce rate for '/lander-1' = '0.5324' bounce rate for '/home'= '0.5834'
#Result2: the bounce rate is lower for the new test_landing page '/lander-1', so it works. 


drop table table_first_pv_id;
drop table home_landing_sessions;
drop table sessions_with_pageviews;

-- look at the time when '/lander-1' was getting traffic
-- the date is '2012-06-19 00:35:54' with the frist pageview id '23504'

select 
	min(created_at) as frist_date_for_lander1,
    min(website_pageview_id) as first_pv_lander1
from 
	website_pageviews
where pageview_url = '/lander-1' and created_at is not null;

-- find the first pageview id for the sessions under the condition

create temporary table table_first_pv_id
SELECT 
	wp.website_session_id,
    min(wp.website_pageview_id) as first_pv_id    
FROM website_pageviews wp
inner join website_sessions ws
on ws.website_session_id = wp.website_session_id
	and date(wp.created_at) >= '2012-06-19' 
	and date(wp.created_at) < '2012-07-28'
    and ws.utm_source = 'gsearch'
    and ws.utm_campaign = 'nonbrand'
group by 1;

-- bring in the landing page, restricted to '/home' and '/lander-1' 

create temporary table sessions_w_landing_url
select
	fpv.website_session_id,
    fpv.first_pv_id,
    wpv.pageview_url
from table_first_pv_id fpv
left join website_pageviews wpv
on fpv.first_pv_id = wpv.website_pageview_id
where wpv.pageview_url in ('/home' , '/lander-1') 
;


-- determine whether the session is bounced or not

create temporary table bounce_table
select
	slu.website_session_id,
    slu.pageview_url,
    case when count(wpv.website_pageview_id) =1 then 1 else 0 end as bounce_or_not
from sessions_w_landing_url slu
left join website_pageviews wpv
on slu.website_session_id = wpv.website_session_id
group by 1,2;


-- find the bounce rate for '/home' and '/lander-1' 
select
    pageview_url as landing_page,
    count(website_session_id) as total_sessions,
    sum(bounce_or_not) as bounce_numbers,
    sum(bounce_or_not)/count(website_session_id) as bounce_rate    
from bounce_table 
group by pageview_url;


#5.LANDING PAGE TREND ANALYSIS (druing the period '2012-06-01' and '2012-08-31')
#Analyze overall paid search bounce rate trended weekly to confirm the traffic is all routed correctly.
#Result1: fully switched over to the lander-1, as intended. 
#Result2: it looks like our overall bounce rate has come down over time, success. 

drop table table_first_pv_id;
drop table sessions_w_landing_url;
drop table bounce_table;

-- find the sessions with the first pageview id and the corresponding date
create temporary table sessions_first_pv
SELECT 
	website_pageviews.website_session_id,
    min(website_pageviews.website_pageview_id) as first_pv_id,
    min(date(website_pageviews.created_at)) as created_date
FROM website_pageviews
left join website_sessions
on website_sessions.website_session_id = website_pageviews.website_session_id
where 
	date(website_pageviews.created_at) > '2012-06-01' 
	and date(website_pageviews.created_at) < '2012-08-31'
    and website_sessions.utm_source = 'gsearch'
    and website_sessions.utm_campaign = 'nonbrand'
group by website_pageviews.website_session_id;

-- determine the sessions above are bounced or not 

create temporary table table_bounce_or_not
select
	sfpv.website_session_id,
    sfpv.first_pv_id,
    sfpv.created_date,
    case when count(wp.website_pageview_id) =1 then 1 else 0 end as bounce_or_not
from sessions_first_pv sfpv
left join website_pageviews wp
on sfpv.website_session_id = wp.website_session_id
group by 1,2,3;

-- find the bounce rate

select 
	week(table_bounce_or_not.created_date) as week_num,
    min(table_bounce_or_not.created_date) as start_date,
    count(distinct table_bounce_or_not.website_session_id) as total_sessions,
    sum(table_bounce_or_not.bounce_or_not) as bounce_num,
    sum(table_bounce_or_not.bounce_or_not)/count(distinct table_bounce_or_not.website_session_id) as bounce_rate,
    count(case when website_pageviews.pageview_url = '/home' then website_pageviews.pageview_url else null end) as home_num,
    count(case when website_pageviews.pageview_url = '/lander-1' then website_pageviews.pageview_url else null end) as lander_1_num
from table_bounce_or_not 
left join website_pageviews
on table_bounce_or_not.first_pv_id = website_pageviews.website_pageview_id
group by week(table_bounce_or_not.created_date)
;

#6.BUILDING CONVERSION FUNNELS (data period '2012-08-05' to '2012-09-05')
# Problems:It seems that we lose our 'gsearch' visitors between the new '/lander-1' page and placing an order.
# Start with '/lander-1' and build the funnel all the way to our thank you page to find the problems. 
#Result1: lander_p_rate='0.4707', products_tomf_rate='0.7409', tomf_cart_rate='0.4359', cart_s_rate='0.6662', shipping_b_rate='0.7934', billing_e_rate='0.4377'
# lander, Mr. Fuzzy page,and the billing page should be focused on and made some changes about, which have the lowest click rates.
# an updated billing page /billing-2 is lunched to improve the performance of the originall billing page


-- find all the sessions with landing page '/lander-1' under the conditions

create temporary table right_session_ids
select 
	sessions_w_frist_pv.website_session_id,
    website_pageviews.pageview_url
from
(
SELECT 
	website_pageviews.website_session_id,
    min(website_pageviews.website_pageview_id) as min_pv_id
FROM website_pageviews
left join website_sessions
on website_pageviews.website_session_id = website_sessions.website_session_id
where website_pageviews.created_at > '2012-08-05'
	and website_pageviews.created_at < '2012-09-05'
    and website_sessions.utm_source = 'gsearch'

group by website_session_id
) as sessions_w_frist_pv

left join website_pageviews
on sessions_w_frist_pv.min_pv_id = website_pageviews.website_pageview_id
where website_pageviews.pageview_url = '/lander-1'
;

-- pull out the whole clicking process for all the correct sessions
select 
	website_session_id,
    count(case when pageview_url = '/lander-1' then website_session_id else null end) as lander_click,
    count(case when pageview_url = '/products' then website_session_id else null end) as products_click,
    count(case when pageview_url = '/the-original-mr-fuzzy' then website_session_id else null end) as t_omf_click,
    count(case when pageview_url = '/cart' then website_session_id else null end) as cart_click,
    count(case when pageview_url = '/shipping' then website_session_id else null end) as shipping_click,
    count(case when pageview_url = '/billing' then website_session_id else null end) as billing_click,
    count(case when pageview_url = '/thank-you-for-your-order' then website_session_id else null end) as tyfyo_click
	
from
(-- find all the correct sessions' view pages
select
	right_session_ids.website_session_id,
    website_pageviews.pageview_url
from right_session_ids
left join website_pageviews
on right_session_ids.website_session_id = website_pageviews.website_session_id

) all_page_views
group by website_session_id
;

-- find the Conversion Rate

select 
	sum(lander_click) as total_session,
    sum(products_click)/sum(lander_click) as lander_p_rate,
    sum(t_omf_click)/sum(products_click) as products_tomf_rate,
    sum(cart_click)/sum(t_omf_click) as tomf_cart_rate,
    sum(shipping_click)/sum(cart_click) as cart_s_rate,
    sum(billing_click)/sum(shipping_click) as shipping_b_rate,
    sum(tyfyo_click)/sum(billing_click) as billing_e_rate

from 
(
select 
	website_session_id,
    count(case when pageview_url = '/lander-1' then website_session_id else null end) as lander_click,
    count(case when pageview_url = '/products' then website_session_id else null end) as products_click,
    count(case when pageview_url = '/the-original-mr-fuzzy' then website_session_id else null end) as t_omf_click,
    count(case when pageview_url = '/cart' then website_session_id else null end) as cart_click,
    count(case when pageview_url = '/shipping' then website_session_id else null end) as shipping_click,
    count(case when pageview_url = '/billing' then website_session_id else null end) as billing_click,
    count(case when pageview_url = '/thank-you-for-your-order' then website_session_id else null end) as tyfyo_click
	
from
(-- find all the correct sessions' view pages
select
	right_session_ids.website_session_id,
    website_pageviews.pageview_url
from right_session_ids
left join website_pageviews
on right_session_ids.website_session_id = website_pageviews.website_session_id

) all_page_views
group by website_session_id
) as table_click_num;


#7.ANALYZING CONVERSION FUNNEL TESTS ( by the date '2012-11-10')
# /billing-2 was created to improve the conversion rate
# Result1: '/billing' has a rate of '0.4566', '/billing-2' has a rate of '0.6269'
# new version of the billing page is doing a much better job converting customers 



-- find the first time '/billing-2' was seen
-- first created at '2012-09-10 00:13:05' and first pageview id is '53550'

select 
	min(created_at) as first_created_at,
    min(website_pageview_id) as first_pv_id
from website_pageviews
where pageview_url = '/billing-2';


-- find the rate for billing and billing-2
select
	billing_version,
    count(distinct website_session_id) as sessions,
    count(distinct order_id) as orders,
    count(distinct order_id)/count(distinct website_session_id) as billing_to_order_rate
from 
(select 
	wp.website_session_id,
    wp.pageview_url as billing_version,
    od.order_id
from website_pageviews wp
left join orders od
on wp.website_session_id = od.website_session_id
where wp.created_at <'2012-11-10' and
	wp.website_pageview_id >= 53550 and
    wp.pageview_url in('/billing', '/billing-2')
) sessions_orders

group by 1
;
-- ------------------------------------------------------------------------------------------------------------
/*
III. Analysis for Channel Portfolio Management
 Analyze the traffic percentage of different channel, to adjust the bidding chioce. 
*/


#1.ANALYZING CHANNEL PORTFOLIOS( by the date '2012-11-29'
# a second paid search channel, bsearch,launched on '2012-08-22'
# Result1:  'bsearch' tends to get roughly one third the traffic of 'gsearch'

SELECT 
    week(created_at) as week_date,
    min(created_at) as start_date,
    count(case when utm_source = 'gsearch' then website_session_id else null end) as gsearch_sessions,
    count(case when utm_source = 'bsearch' then website_session_id else null end) as bsearch_sessions
FROM website_sessions
where created_at < '2012-11-29'
	and created_at > '2012-08-22'
    and utm_campaign = 'nonbrand'
group by week(created_at);

#2.COMPARING CHANNEL CHARACTERISTICS (date period '2012-08-22' and '2012-11-29')
# compare the nonbrand bsearch and gsearch campaign, pull the percentage of traffic coming on Mobile or Desktop
# the traffic comes through mobile on 'gsearch' is '0.2448', on 'bsearch' is '0.0864' 
# the desktop to mobile split is interesting and different for different source

SELECT 
    utm_source,
    count(distinct website_session_id) as total_sessions,
    count(case when device_type = 'mobile' then website_session_id else null end) as mobile_sessions,
    count(case when device_type = 'mobile' then website_session_id else null end)/count(distinct website_session_id) as pct_of_mobile
FROM website_sessions
where created_at < '2012-11-29'
	and created_at > '2012-08-22'
    and utm_campaign = 'nonbrand'
group by utm_source;


#3.CROSS CHANNEL BID OPTIMIZATION(date period '2012-08-22' and '2012-09-19') 
# a special pre-holiday campaign for gsearch starting on September 19th, so the data after that isn’t fair game
# wondering if bsearch nonbrand should have the same bids as gsearch, compare the nonbrand conversion rates from session to order
# Result1: gsearch has a better conversion rate on both mobile and desktop
# Result2: bid down bsearch based on its under-performance.

SELECT 
    website_sessions.device_type,
    website_sessions.utm_source,
    count(website_sessions.website_session_id) as sessions,
    count(orders.website_session_id) as orders, 
    count(orders.website_session_id)/count(website_sessions.website_session_id) as conv_rate
FROM website_sessions
left join orders
on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at < '2012-09-19'
	and website_sessions.created_at > '2012-08-22'
    and website_sessions.utm_campaign = 'nonbrand'
group by website_sessions.device_type,website_sessions.utm_source
;

#4.CHANNEL PORTFOLIO TRENDS(date period '2012-11-04' and '2012-12-22') 
# bid down bsearch nonbrand on December 2nd.
# Result1: bsearch traffic dropped off a bit after the bid down. 
# Result2: Seems like gsearch was down too after Black Friday and Cyber Monday, but bsearch dropped even more


SELECT 
    week(created_at) as week_date,
    min(created_at) as start_date,
    count(case when utm_source = 'gsearch' and device_type = 'mobile' then website_session_id else null end) as gm_sessions,
    count(case when utm_source = 'bsearch' and device_type = 'mobile' then website_session_id else null end) as bm_sessions,
    count(case when utm_source = 'bsearch' and device_type = 'mobile' then website_session_id else null end)/
		count(case when utm_source = 'gsearch' and device_type = 'mobile' then website_session_id else null end) as bm_gm_rate,
    count(case when utm_source = 'gsearch' and device_type = 'desktop' then website_session_id else null end) as gd_sessions,
    count(case when utm_source = 'bsearch' and device_type = 'desktop' then website_session_id else null end) as bd_sessions,
    count(case when utm_source = 'bsearch' and device_type = 'desktop' then website_session_id else null end)/
		count(case when utm_source = 'gsearch' and device_type = 'desktop' then website_session_id else null end) as bd_fd_rate
		
FROM website_sessions
where created_at < '2012-12-22'
	and created_at > '2012-11-04'
    and utm_campaign = 'nonbrand'
group by week(created_at);


#5.ANALYZING FREE CHANNELS(by the date '2012-12-23')
# if we’re building any momentum with our brand or if we’ll need to keep relying on paid traffic
# Result1:  brand, direct, and organic volumes are actually growing, the rely on the paid chennel is decreasing.


SELECT 
    month(created_at) as month_date,
    min(date(created_at)) as start_date,
    count(case when utm_campaign = 'nonbrand'  then website_session_id else null end) as nonbrand_sessions,
    count(case when utm_campaign = 'brand' then website_session_id else null end) as brand_sessions,
    count(case when utm_campaign = 'brand' then website_session_id else null end)/
		count(case when utm_campaign = 'nonbrand'  then website_session_id else null end) as brand_pct_of_nonbrand,
    count(case when utm_source is null and http_referer is null then website_session_id else null end) as direct_sessions,
    count(case when utm_source is null and http_referer is null then website_session_id else null end)/
		count(case when utm_campaign = 'nonbrand'  then website_session_id else null end) as direct_pct_of_nonbrand,
    count(case when utm_source is null and http_referer in ('https://www.gsearch.com','https://www.bsearch.com') then website_session_id else null end) as organic_sessions,
    count(case when utm_source is null and http_referer in ('https://www.gsearch.com','https://www.bsearch.com') then website_session_id else null end)/
		count(case when utm_campaign = 'nonbrand'  then website_session_id else null end) as organic_pct_of_nonbrand

FROM website_sessions
where created_at < '2012-12-23'
group by month(created_at);

-- ------------------------------------------------------------------------------------------------------------
/*
IV. Analysis Business Patterns and Seasonality
	Through analyze the yearly/daily pattern, adjust the customer support and inventory management due to different customer volume
*/

#1. ANALYZING SEASONALITY(by the date '2013-01-01')
#Result1: grew fairly steadily all year
#Result2: saw significant volume around the holiday months
#Result3: in 2013, think about customer support and inventory management during those holidy seasons.

select
	year(ws.created_at) as year,
    month(ws.created_at) as month,
    count(distinct ws.website_session_id) as sessions,
    count(distinct o.order_id) as orders
from website_sessions ws
left join orders o
using (website_session_id)
where ws.created_at < '2013-01-01'
group by 1,2;

#2. ANALYZING BUSINESS PATTERNS (date period '2013-09-15'-'2013-11-15')
# Analyze the general patterns before the holiday season
#Result1: 8am to 5pm Monday through Friday seems to have more customers
#Result2: Add more staff in the time period. 

select
		hr,
        round(avg(case when wkday = 0 then website_sessions else null end ),1) as Mon,
        round(avg(case when wkday = 1 then website_sessions else null end ),1) as Tue,
        round(avg(case when wkday = 2 then website_sessions else null end ),1) as Wed,
        round(avg(case when wkday = 3 then website_sessions else null end ),1) as Thu,
        round(avg(case when wkday = 4 then website_sessions else null end ),1) as Fri,
        round(avg(case when wkday = 5 then website_sessions else null end ),1) as Sat,
        round(avg(case when wkday = 6 then website_sessions else null end ),1) as Sun
from 
(
select
	date(created_at) as created_at,
    weekday(created_at) as wkday,
    hour(created_at) as hr,
    count(distinct website_session_id) as website_sessions
from website_sessions
where 
	created_at between '2013-09-15' and '2013-11-15'
group by 1,2,3
) week_hour_sessions
group by 1;

-- ------------------------------------------------------------------------------------------------------------
/*
V. Product Analysis
Idetify the different products' revenue, conversion rate and so on.
To see whether the new product will make some better changes or not
The influence of the new websites or new supplier on the products

*/

#1. PRODUCT LEVEL SALES ANALYSIS (by the date '2013-01-04')
#Result1: nice to see the growth pattern in general
#Result2: This will serve as great baseline data as we roll out the new product.

select
	year(created_at) as yr,
    month(created_at) as mo,
    count(distinct order_id) as num_of_sales,
    sum(price_usd) as total_revenue,
    sum(price_usd-cogs_usd) as total_margin
from orders
where created_at < '2013-01-04'
group by 1,2;

#2. PRODUCT LAUNCH SALES ANALYSIS(date period '2012-04-01' to '2013-04-05')
# launched second product back on January 6th
#Result1: This confirms that the conversion rate and revenue per session are improving over time
#Result2: especially after the launched of second product, the conversion rate increased



select
	year(ws.created_at) as yr,
    month(ws.created_at) as mo,
    count(distinct ws.website_session_id) as sessions,
    count(distinct o.order_id) as orders,
    count(distinct o.order_id)/count(distinct ws.website_session_id) as con_rate,
    sum(o.price_usd)/count(distinct ws.website_session_id) as revenue_per_session,
    count(case when o.primary_product_id = 1 then o.order_id else null end) as product1_orders,
    count(case when o.primary_product_id = 2 then o.order_id else null end) as product2_orders
    
from website_sessions ws
left join orders o
on ws.website_session_id = o.website_session_id
where 
	ws.created_at < '2013-04-05' and 
	ws.created_at >'2012-04-01'     
group by 1,2;



#3.PRODUCT PATHING ANALYSIS(date period '2012-10-06' to '2013-04-06'
#Determine whether the growth since January is due to the new product launch or just a continuation of the overall business improvements
#Result1:  clicked to Mr. Fuzzy has gone down since the launch of the Love Bear, but the overall clickthrough rate has gone up
#Result2: it seems to be generating additional product interest overall

-- find the product pageviews we need
create temporary table product_pageviews
select
	website_session_id,
    website_pageview_id,
    created_at,
    case 
	when created_at < '2013-01-06' then 'A_Pre_Product2'
    when created_at >= '2013-01-06' then 'B_Post_Product2'
    else 'Check logic'
    end as time_period
from website_pageviews
where 
	created_at < '2013-04-06' and
    created_at > '2012-10-06' and
    pageview_url = '/products';

-- summarize the data pre and post the new product
select
	ppv.time_period,
    count(distinct ppv.website_session_id) as sessions,
    count(distinct wpv.website_pageview_id) as product_to_nextpg,
    count(distinct wpv.website_pageview_id)/count(distinct ppv.website_session_id) as pct_to_nextpg,
    count(case when wpv.pageview_url = '/the-original-mr-fuzzy' then wpv.website_pageview_id else null end) as to_mrfuzzy,
    count(case when wpv.pageview_url = '/the-original-mr-fuzzy' then wpv.website_pageview_id else null end)/
		count(distinct wpv.website_pageview_id) as pct_to_mrfuzzy,
    count(case when wpv.pageview_url = '/the-forever-love-bear' then wpv.website_pageview_id else null end) as to_flovebear,
    count(case when wpv.pageview_url = '/the-forever-love-bear' then wpv.website_pageview_id else null end)/
		count(distinct wpv.website_pageview_id) as pct_to_flovebear
    
from product_pageviews ppv
left join website_pageviews wpv
on ppv.website_session_id = wpv.website_session_id and
 wpv.pageview_url in ('/the-original-mr-fuzzy', '/the-forever-love-bear' )
group by 1;


#4.PRODUCT CONVERISON FUNNELS (date period '2013-01-06' and '2014-04-10' )
# determine which one has a better perfomance in the conversion rate.
#Result1: '/the-original-mr-fuzzy' click rate to the cart = '0.4314' and '/the-forever-love-bear' = '0.5515'
#Result2: the Love Bear has a better click rate to the /cart page and comparable rates throughout the rest of the funnel.

-- find all the related pagesessions
create temporary table table_products
SELECT
	website_session_id,
    case
	when pageview_url = '/the-original-mr-fuzzy' then 'the_omf'
    else 'the_flb'
    end as products
FROM website_pageviews
where created_at > '2013-01-06'
	and created_at < '2014-04-10'
    and pageview_url in ('/the-original-mr-fuzzy','/the-forever-love-bear')
;

-- pull all the pageviews and urls
create temporary table table_pv_with_products
select
	website_pageviews.website_pageview_id,
    website_pageviews.website_session_id,
    website_pageviews.pageview_url,
    table_products.products
from table_products
left join website_pageviews
on table_products.website_session_id = website_pageviews.website_session_id
;

-- create session level conversion funnel
select distinct(pageview_url)
from table_pv_with_products;


create temporary table table_pre_tunnel
select
	website_session_id,
    products,
    count(case when pageview_url in ('/lander-1','/home','/lander-2','/lander-3','/lander-4') then website_session_id else null end) as p_lander,
	count(case when pageview_url = '/products' then website_session_id else null end) as p_products,
    count(case when pageview_url in ('/the-original-mr-fuzzy','/the-forever-love-bear' )then website_session_id else null end) as p_main,
	count(case when pageview_url = '/cart' then website_session_id else null end) as p_cart,
	count(case when pageview_url = '/shipping' then website_session_id else null end) as p_shipping,
    count(case when pageview_url = '/billing-2' then website_session_id else null end) as p_billing,
    count(case when pageview_url = '/thank-you-for-your-order' then website_session_id else null end) as p_ty
    
from table_pv_with_products
group by 1,2;

-- analyze the funnel performance for different products
select
	products,
    sum(p_main) as to_main,
    sum(p_cart)/sum(p_main) as main_click_rate,
    sum(p_cart) as to_cart,
    sum(p_shipping)/sum(p_cart) as cart_click_rate,
    sum(p_shipping) as to_shipping,
    sum(p_billing)/sum(p_shipping)as shipping_click_rate,
    sum(p_billing) as to_billing,
    sum(p_ty)/sum(p_billing) as billing_click_rate,
    sum(p_ty) as to_ty
    
from table_pre_tunnel
group by products;


#5.CROSS-SELL ANALYSIS(date period '2013-08-25' and '2013-10-25')
# On'2013-09-25' started giving customers the option to add a 2nd product while on the /cart page.
#Result1: It looks like the CTR from the /cart page didn’t go down and others are all up slightly
#Result2: Doesn’t look like a game changer, but the trend looks positive.


-- find the needed session-level url count
create temporary table table_time_click
SELECT
	website_session_id,
    case
	when created_at <= '2013-09-25' then 'pre_change'
    else 'post_change'
    end as time_period,
    count(case when pageview_url = '/cart' then website_session_id else null end) as cart_click,
    count(case when pageview_url = '/shipping' then website_session_id else null end) as shipping_click
FROM website_pageviews

where created_at > '2013-08-25'
	and created_at < '2013-10-25'
    and pageview_url in ('/shipping','/cart')
group by website_session_id, time_period
;


-- compare the pre_change and post_change data
select 
	table_time_click.time_period,
    sum(table_time_click.cart_click) as cart_sessions,
    sum(table_time_click.shipping_click) as shipping_sessions,
    sum(table_time_click.shipping_click)/sum(table_time_click.cart_click) as cart_ctr,
    sum(orders.items_purchased)/count(orders.order_id) as products_per_order,
    sum(orders.price_usd)/count(orders.order_id) as aov,
    sum(orders.price_usd)/sum(table_time_click.cart_click) as rev_per_cart_session
    
from table_time_click
left join orders
on table_time_click.website_session_id = orders.website_session_id
group by table_time_click.time_period;


#6. PORTFOLIO EXPANSION ANALYSIS(date period '2013-11-12' and '2014-01-12'
# On '2013-12-12', a third product targeting the birthday gift market (Birthday Bear) was launched
#Result1:  all of the critical metrics have improved since we launched the third product


create temporary table table_session_with_order
SELECT
	distinct(website_pageviews.website_session_id),
    orders.order_id,
    orders.items_purchased,
    orders.price_usd,
    case
	when website_pageviews.created_at <= '2013-12-12' then 'pre_change'
    else 'post_change'
    end as time_period
FROM website_pageviews
left join orders
on website_pageviews.website_session_id = orders.website_session_id

where website_pageviews.created_at > '2013-11-12'
	and website_pageviews.created_at < '2014-01-12'
order by website_pageviews.website_session_id
;


select
	time_period,
    count(order_id)/count(website_session_id) as conv_rate,
    sum(items_purchased)/count(order_id) as products_per_order,
    sum(price_usd)/count(website_session_id) as revenue_per_session,
	sum(price_usd)/count(order_id) as aov
    
from table_session_with_order
group by time_period
;



#7.PRODUCT REFUND RATES(by the date '2014-10-15')
#Mr. Fuzzy supplier had some quality issues which weren’t corrected until September 2013. 
#Then they had a major problem where the bears’ arms were falling off in Aug/Sep 2014. 
#As a result, we replaced them with a new supplier on September 16, 2014.
#Result1: the refund rates for Mr. Fuzzy did go down after the initial improvements in September 2013, 
#Result2: the refund rates for Mr. Fuzzy were terrible in August and September 2014 again because of the arms


create temporary table table_refunds
SELECT 
	year(order_items.created_at) as yr,
    month(order_items.created_at) as mo,
    order_items.order_item_id,
    order_items.order_id,
    order_items.product_id,
    case when order_item_refunds.order_id is not null then 1 else 0 end as refunds
FROM order_items
left join order_item_refunds
on order_items.order_item_id = order_item_refunds.order_item_id
where order_items.created_at < '2014-10-15'

;

select
	yr,
    mo,
    count(distinct case when product_id =1 then order_id else null end) as p1_order,
    sum(case when product_id =1 then refunds else null end)/count(distinct case when product_id =1 then order_id else null end) as p1_order_rt,
    count(distinct case when product_id =2 then order_id else null end) as p2_order,
    sum(case when product_id =2 then refunds else null end)/count(distinct case when product_id =2 then order_id else null end) as p2_order_rt,
    count(distinct case when product_id =3 then order_id else null end) as p3_order,
    sum(case when product_id =3 then refunds else null end)/count(distinct case when product_id =3 then order_id else null end) as p3_order_rt,
    count(distinct case when product_id =4 then order_id else null end) as p4_order,
    sum(case when product_id =4 then refunds else null end)/count(distinct case when product_id =4 then order_id else null end) as p4_order_rt
    
from table_refunds
group by yr,mo
;

-- ------------------------------------------------------------------------------------------------------------
/*
VI. User Analysis
Anlyze the customers type and behavior, find the vluable customer
Keep an eye on the behavior pattern, try to encourage more purchasing.

*/

#1.IDENTIFYING REPEAT VISITORS(date period '2014-01-01' and '2014-11-01')
# if the customers have repeat sessions, they may be more valuable than we thought. 
#Result1:  a fair number of our customers do come back to our site after the first session.

select 
	repeat_num,
    count(user_id) as users
from
(
SELECT 
	user_id,
    sum(is_repeat_session) as repeat_num
FROM website_sessions
where created_at >= '2014-01-01'
	and created_at < '2014-11-01'
group by user_id
) as repeated_table
group by repeat_num
;


#2. ANALYZING REPEAT BEHAVIOR (date period '2014-01-01' and '2014-11-03')
# to better understand the behavior of these repeat customers
#Result1: max(days)='69', min(days)='1', avg(days)= '33.2622'
#Result2: Interesting to see that our repeat visitors are coming back about a month later, on average.


select 
	max(days),
    min(days),
    avg(days)
from
(
select 
	table_second_session.user_id,
    second_session_date,
    date(website_sessions.created_at) as first_session_date,
    datediff(second_session_date, date(website_sessions.created_at)) as days
from 
(-- the id of the repeated session and the date
SELECT 
	user_id,
    min(date(created_at)) as second_session_date
FROM website_sessions
where created_at >= '2014-01-01'
	and created_at < '2014-11-03'
    and is_repeat_session = 1
group by user_id
) as table_second_session
left join website_sessions
on website_sessions.user_id = table_second_session.user_id
where website_sessions.is_repeat_session = 0
	and website_sessions.created_at >= '2014-01-01'
	and website_sessions.created_at < '2014-11-03'
) as table_days

;

#3. NEW VS REPEAT CHANNEL PATTERNS(date period '2014-01-01' and '2014-11-05')
# Try to figure out the channels they come back through
#Result1:'paid_nonbrand' and 'paid_social' has no repeated sessions
#Result2: Only about 1/3 come through a paid channel, and brand clicks are cheaper than nonbrand. So all in all, we’re not paying very much for these subsequent visits.

create temporary table table_channel
SELECT
	user_id,
    is_repeat_session,
	case when utm_source in ('gsearch','bsearch' ) and utm_campaign = 'brand' then 'paid_brand'
		 when utm_source in ('gsearch','bsearch' ) and utm_campaign = 'nonbrand' then 'paid_nonbrand'
         when utm_source = 'socialbook' then 'paid_social'
         when utm_source is null and http_referer is null then 'direct_type_in'
         when utm_source is null and http_referer is not null then 'dorganic_search'
         else 'opps_wrong'
	end as channel_group
FROM website_sessions
where created_at >= '2014-01-01'
	and created_at < '2014-11-05'
;

SELECT 
    channel_group,
    count(case when is_repeat_session = 0 then user_id else null end) as new_sessions,
    count(case when is_repeat_session = 1 then user_id else null end) as repeated_sessions
FROM table_channel
group by channel_group
;


#4. NEW VS REPEAT PERFORMANCE(date period '2014-01-01' and '2014-11-08')
#Result1:  Looks like repeat sessions are more likely to convert, and produce more revenue per session.


SELECT 
	website_sessions.is_repeat_session,
    count(website_sessions.website_session_id) as sessions,
    count(orders.website_session_id)/count(website_sessions.website_session_id) as rate,
    sum(orders.price_usd)/count(website_sessions.website_session_id) as revernue_per_session
    
FROM website_sessions
left join orders 
on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at  >= '2014-01-01'
	and website_sessions.created_at < '2014-11-08'
group by website_sessions.is_repeat_session

