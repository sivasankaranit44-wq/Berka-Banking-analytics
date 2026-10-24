use Berka_banking_analytics
GO

-- Row counts
select(select count(*) from silver.transactions) as SilverRows,
(select count(*) from gold.fact_transactions) as FactRows,
(select count(*) from gold.dim_account) as DimAccountRows,
(select count(*) from gold.dim_date) as DimDateRows 
go

-- Every fact row finds its date and account 
select count(*) as FactWithoutDate
from gold.fact_transactions f
left join gold.dim_date d on d.date_key = f.date_key
where d.date_key is null 
go
select count(*) as FactWithoutAccount
from gold.fact_transactions f
left join gold.dim_account a on a.account_id = f.account_id
where a.account_id is NULL
go

-- Reconciles 
select (select sum(signed_amount) from silver.transactions)  as SilverNet, 
(select sum(signed_amount) from gold.fact_transactions) as FactNet,
(select sum(net_cashflow) from gold.vw_monthly_cashflow) as ViewNet,
(select sum(net_amount) from gold.dim_account) as DimAccountNet
go

-- Date range of the data
select min(transaction_date) as FistDate, max(transaction_date) as LastDate
from silver.transactions
go

-- first few months cashflow
SELECT top 12 * from gold.vw_monthly_cashflow order by year_month
go

-- operation summary 
select * from gold.vw_operation_summary order by total_amount desc
go

-- top 5 accounts by clsing balance
select top 5 * from gold.vw_top_accounts
go