use Berka_banking_analytics
GO
if schema_id('gold') is null exec('create schema gold')
go

-- Dim date (1993-01-01 to 1998-12-31)
drop table if exists gold.dim_date
go
;with d as (
    select cast('1993-01-01' as date) as dt
    union all
    select dateadd(day, 1, dt) from d where dt < '1998-12-31'
)
select
    isnull(cast(convert(char(8), dt, 112) as int), 0) as date_key,
    dt as full_date,
    year(dt) as year,
    datepart(quarter, dt) as quarter,
    month(dt) as month_number,
    datename(month, dt) as month_name,
    convert(char(7), dt, 120) as year_month,
    datename(weekday, dt) as weekday_name
into gold.dim_date
from d option (maxrecursion 0)
go
alter table gold.dim_date add constraint pk_dim_date primary key (date_key)
go

-- Dimension account(one row % built from transactions)
drop table IF EXISTS gold.dim_account
go

;with ranked as (
    select account_id, balance, ROW_NUMBER() over(PARTITION by account_id order by transaction_date desc, trans_id desc) as rn
    from silver.transactions
)

select
    t.account_id,
    min(t.transaction_date) as first_transaction_date,
    max(t.transaction_date) as last_transaction_date,
    count(*)                as transaction_count,
    sum(case when t.transaction_type = 'Credit' then t.amount else 0 end) as total_credits,
    sum(case when t.transaction_type = 'Debit'  then t.amount else 0 end) as total_debits,
    sum(t.signed_amount)    as net_amount,
    r.balance               as closing_balance
into gold.dim_account
from silver.transactions t
join ranked r on r.account_id = t.account_id and r.rn = 1
group by t.account_id, r.balance
go
alter table gold.dim_account add constraint pk_dim_account primary key (account_id)
go

-- FACT TRANSACTIONS
drop table if exists gold.fact_transactions
go
select
    trans_id, account_id,
    cast(convert(char(8), transaction_date, 112) as int) as date_key,
    transaction_type, operation_desc, k_symbol_desc,
    amount, signed_amount, balance
into gold.fact_transactions
from silver.transactions
go
create index ix_fact_trans_account on gold.fact_transactions (account_id)
create index ix_fact_trans_date on gold.fact_transactions (date_key)
go

-- VIEWS FOR POWER BI
create or alter view gold.vw_monthly_cashflow as
select dd.year_month, dd.year, dd.month_number,
       sum(case when f.transaction_type = 'Credit' then f.amount else 0 end) as total_credits,
       sum(case when f.transaction_type = 'Debit'  then f.amount else 0 end) as total_debits,
       sum(f.signed_amount) as net_cashflow,
       count(*) as transaction_count
from gold.fact_transactions f
join gold.dim_date dd on dd.date_key = f.date_key
group by dd.year_month, dd.year, dd.month_number
go

create or alter view gold.vw_operation_summary as
select isnull(operation_desc, 'Interest / No Operation') as operation,
       transaction_type,
       count(*) as transaction_count,
       sum(amount) as total_amount,
       avg(amount) as avg_amount
from gold.fact_transactions
group by isnull(operation_desc, 'Interest / No Operation'), transaction_type
go

create or alter view gold.vw_purpose_summary as
select isnull(k_symbol_desc, 'Not Specified') as purpose,
       count(*) as transaction_count,
       sum(amount) as total_amount
from gold.fact_transactions
group by isnull(k_symbol_desc, 'Not Specified')
go

create or alter view gold.vw_top_accounts as
select top 100 account_id, transaction_count, total_credits, total_debits,
       net_amount, closing_balance
from gold.dim_account
order by closing_balance desc
go