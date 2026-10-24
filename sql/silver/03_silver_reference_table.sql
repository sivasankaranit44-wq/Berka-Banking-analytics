/* Layer: Silver | Purpose: clean the Berka reference tables
   Source: bronze.account/client/disp/district/loan/card/orders
   Re-runnable: drops and rebuilds each table */
use Berka_banking_analytics
go

-- ACCOUNT
drop table if exists silver.account
go
select
    cast(account_id as int)  as account_id,
    cast(district_id as int) as district_id,
    case ltrim(rtrim(frequency))
        when 'POPLATEK MESICNE'   then 'Monthly'
        when 'POPLATEK TYDNE'     then 'Weekly'
        when 'POPLATEK PO OBRATU' then 'After Transaction'
        else ltrim(rtrim(frequency))
    end as statement_frequency,
    try_convert(date, '19' + cast([date] as varchar(6)), 112) as opened_date
into silver.account
from bronze.account
go
alter table silver.account alter column account_id int not null
go
alter table silver.account add constraint pk_silver_account primary key (account_id)
go

-- CLIENT (birth_number = YYMMDD; month + 50 means female)
drop table if exists silver.client
go
select
    cast(c.client_id as int)   as client_id,
    cast(c.district_id as int) as district_id,
    case when b.mm > 50 then 'Female' else 'Male' end as gender,
    try_convert(date,
        '19' + substring(b.bn, 1, 2)
             + right('0' + cast(case when b.mm > 50 then b.mm - 50 else b.mm end as varchar(2)), 2)
             + substring(b.bn, 5, 2), 112) as birth_date
into silver.client
from bronze.client c
cross apply (select cast(c.birth_number as varchar(6)) as bn,
                    try_cast(substring(cast(c.birth_number as varchar(6)), 3, 2) as int) as mm) b
go
alter table silver.client alter column client_id int not null
go
alter table silver.client add constraint pk_silver_client primary key (client_id)
go

-- DISP (links clients to accounts)
drop table if exists silver.disp
go
select
    cast(disp_id as int)    as disp_id,
    cast(client_id as int)  as client_id,
    cast(account_id as int) as account_id,
    case upper(ltrim(rtrim([type])))
        when 'OWNER'     then 'Owner'
        when 'DISPONENT' then 'Disponent'
        else ltrim(rtrim([type]))
    end as disp_type
into silver.disp
from bronze.disp
go
alter table silver.disp alter column disp_id int not null
go
alter table silver.disp add constraint pk_silver_disp primary key (disp_id)
go

-- DISTRICT (A1..A16 renamed; '?' becomes NULL)
drop table if exists silver.district
go
select
    cast(A1 as int)                  as district_id,
    ltrim(rtrim(A2))                 as district_name,
    ltrim(rtrim(A3))                 as region,
    try_cast(A4 as int)              as population,
    try_cast(A10 as decimal(5,2))    as urban_ratio,
    try_cast(A11 as int)             as avg_salary,
    try_cast(nullif(ltrim(rtrim(A12)), '?') as decimal(5,2)) as unemployment_1995,
    try_cast(A13 as decimal(5,2))    as unemployment_1996,
    try_cast(A14 as int)             as entrepreneurs_per_1000,
    try_cast(nullif(ltrim(rtrim(A15)), '?') as int) as crimes_1995,
    try_cast(A16 as int)             as crimes_1996
into silver.district
from bronze.district
go
alter table silver.district alter column district_id int not null
go
alter table silver.district add constraint pk_silver_district primary key (district_id)
go

-- LOAN
drop table if exists silver.loan
go
select
    cast(loan_id as int)    as loan_id,
    cast(account_id as int) as account_id,
    try_convert(date, '19' + cast([date] as varchar(6)), 112) as loan_date,
    cast(amount as decimal(18,2))   as loan_amount,
    cast(duration as int)           as duration_months,
    cast(payments as decimal(18,2)) as monthly_payment,
    case upper(ltrim(rtrim(status)))
        when 'A' then 'Finished - Paid'
        when 'B' then 'Finished - Not Paid'
        when 'C' then 'Running - OK'
        when 'D' then 'Running - In Debt'
    end as loan_status,
    case when upper(ltrim(rtrim(status))) in ('B','D') then 1 else 0 end as is_bad_loan
into silver.loan
from bronze.loan
go
alter table silver.loan alter column loan_id int not null
go
alter table silver.loan add constraint pk_silver_loan primary key (loan_id)
go

-- CARD (issued looks like '930107 00:00:00', so take the first 6 characters)
drop table if exists silver.card
go
select
    cast(card_id as int) as card_id,
    cast(disp_id as int) as disp_id,
    case lower(ltrim(rtrim([type])))
        when 'junior'  then 'Junior'
        when 'classic' then 'Classic'
        when 'gold'    then 'Gold'
        else ltrim(rtrim([type]))
    end as card_type,
    try_convert(date, '19' + left(cast(issued as varchar(20)), 6), 112) as issued_date
into silver.card
from bronze.card
go
alter table silver.card alter column card_id int not null
go
alter table silver.card add constraint pk_silver_card primary key (card_id)
go

-- ORDERS (standing orders)
drop table if exists silver.orders
go
select
    cast(order_id as int)   as order_id,
    cast(account_id as int) as account_id,
    nullif(ltrim(rtrim(bank_to)), '')    as partner_bank,
    nullif(ltrim(rtrim(account_to)), '') as partner_account,
    cast(amount as decimal(18,2)) as amount,
    case nullif(ltrim(rtrim(k_symbol)), '')
        when 'POJISTNE' then 'Insurance Payment'
        when 'SIPO'     then 'Household Payment'
        when 'LEASING'  then 'Leasing'
        when 'UVER'     then 'Loan Payment'
        else nullif(ltrim(rtrim(k_symbol)), '')
    end as payment_purpose
into silver.orders
from bronze.orders
go
alter table silver.orders alter column order_id int not null
go
alter table silver.orders add constraint pk_silver_orders primary key (order_id)
go
