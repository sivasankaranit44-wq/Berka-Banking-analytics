/* Layer: Gold | Purpose: district, client, loan and account-profile layer
   Re-runnable: drops and rebuilds */
use Berka_banking_analytics
go

-- DIM DISTRICT
drop table if exists gold.dim_district
go
select * into gold.dim_district from silver.district
go
alter table gold.dim_district alter column district_id int not null
go
alter table gold.dim_district add constraint pk_dim_district primary key (district_id)
go

-- DIM CLIENT (age measured at the end of the data, 1998-12-31)
drop table if exists gold.dim_client
go
select
    c.client_id,
    c.gender,
    c.birth_date,
    c.district_id,
    x.age,
    case when x.age < 25 then 'Under 25'
         when x.age < 40 then '25-39'
         when x.age < 55 then '40-54'
         when x.age < 70 then '55-69'
         else '70+' end as age_group
into gold.dim_client
from silver.client c
cross apply (
    select datediff(year, c.birth_date, '1998-12-31')
         - case when dateadd(year, datediff(year, c.birth_date, '1998-12-31'), c.birth_date) > '1998-12-31'
                then 1 else 0 end as age
) x
go
alter table gold.dim_client alter column client_id int not null
go
alter table gold.dim_client add constraint pk_dim_client primary key (client_id)
go

-- FACT LOANS
drop table if exists gold.fact_loans
go
select
    loan_id,
    account_id,
    cast(convert(char(8), loan_date, 112) as int) as date_key,
    loan_amount,
    duration_months,
    monthly_payment,
    loan_status,
    is_bad_loan
into gold.fact_loans
from silver.loan
go
create index ix_fact_loans_account on gold.fact_loans (account_id)
go

-- VIEW: ACCOUNT PROFILE (account + district + owner + loan flag + activity)
create or alter view gold.vw_account_profile as
select
    a.account_id,
    a.statement_frequency,
    a.opened_date,
    d.district_name,
    d.region,
    d.avg_salary,
    cl.client_id as owner_client_id,
    cl.gender    as owner_gender,
    cl.age       as owner_age,
    cl.age_group as owner_age_group,
    da.transaction_count,
    da.total_credits,
    da.total_debits,
    da.net_amount,
    da.closing_balance,
    case when exists (select 1 from gold.fact_loans l where l.account_id = a.account_id)
         then 1 else 0 end as has_loan
from silver.account a
join gold.dim_district d on d.district_id = a.district_id
join silver.disp dp on dp.account_id = a.account_id and dp.disp_type = 'Owner'
join gold.dim_client cl on cl.client_id = dp.client_id
join gold.dim_account da on da.account_id = a.account_id
go

-- VIEW: LOAN SUMMARY
create or alter view gold.vw_loan_summary as
select loan_status,
       count(*) as loans,
       sum(loan_amount) as total_loan_amount,
       avg(loan_amount) as avg_loan_amount
from gold.fact_loans
group by loan_status
go

-- VIEW: DISTRICT ACTIVITY
create or alter view gold.vw_district_activity as
select region, district_name, avg_salary,
       count(*) as accounts,
       sum(total_credits + total_debits) as total_volume,
       sum(has_loan) as accounts_with_loan
from gold.vw_account_profile
group by region, district_name, avg_salary
go

-- VIEW: GENDER AND AGE ACTIVITY
create or alter view gold.vw_customer_segments as
select owner_gender, owner_age_group,
       count(*) as accounts,
       avg(closing_balance) as avg_closing_balance,
       sum(has_loan) as accounts_with_loan
from gold.vw_account_profile
group by owner_gender, owner_age_group
go