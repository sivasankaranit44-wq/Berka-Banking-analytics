use Berka_banking_analytics
go

-- 1. Row counts (4500, 5369, 5369, 77, 682, 892, 6471)
select 'account' as t, count(*) as Cnt from silver.account union all
select 'client',   count(*) from silver.client   union all
select 'disp',     count(*) from silver.disp     union all
select 'district', count(*) from silver.district union all
select 'loan',     count(*) from silver.loan     union all
select 'card',     count(*) from silver.card     union all
select 'orders',   count(*) from silver.orders
go

-- 2. Bad dates (all 0)
select (select count(*) from silver.account where opened_date is null) as BadAccountDates,
       (select count(*) from silver.client  where birth_date  is null) as BadBirthDates,
       (select count(*) from silver.loan    where loan_date   is null) as BadLoanDates,
       (select count(*) from silver.card    where issued_date is null) as BadCardDates
go

-- 3. Category checks (no NULL or Czech values)
select statement_frequency, count(*) as Cnt from silver.account group by statement_frequency
select disp_type,   count(*) as Cnt from silver.disp group by disp_type
select loan_status, count(*) as Cnt from silver.loan group by loan_status
select card_type,   count(*) as Cnt from silver.card group by card_type
select gender,      count(*) as Cnt from silver.client group by gender
go

-- 4. Orphan checks (all 0)
select count(*) as AccountsWithoutDistrict
from silver.account a left join silver.district d on d.district_id = a.district_id
where d.district_id is null
select count(*) as TransWithoutAccount
from silver.transactions t left join silver.account a on a.account_id = t.account_id
where a.account_id is null
select count(*) as AccountsWithoutOwner
from silver.account a
where not exists (select 1 from silver.disp d where d.account_id = a.account_id and d.disp_type = 'Owner')
go