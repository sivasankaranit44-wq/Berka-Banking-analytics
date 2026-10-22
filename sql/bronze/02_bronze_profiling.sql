use Berka_banking_analytics
go

select column_name, data_type, character_maximum_length, is_nullable
from INFORMATION_SCHEMA.COLUMNS
where TABLE_SCHEMA = 'bronze' and TABLE_NAME = 'transactions'
order by ORDINAL_POSITION
go

-- raw count and trans_id uniqueness 
select count(*) as Total_Rows, count(distinct trans_id) as DistinctIds from bronze.transactions 
go

-- Nulls in the key columns
select sum(case when trans_id is null then 1 else 0 end) as NullTransIds,
SUM(case when account_id is null then 1 else 0 end) as NullAccountIds,
SUM(case when[date] is null then 1 else 0 end) as NullDates,
SUM(case when amount is null then 1 else 0 end) as NullAmounts,
SUM(case when balance is null then 1 else 0 end) as NullBalances 
from bronze.transactions
GO

-- Raw date range 
select min([date]) as EarliestRawDate, MAX([date]) as LatestRawDate
from bronze.transactions
go

-- distinct values in the categoral colums 
SELECT[type], count(*) as Cnt from bronze.transactions group by [type] order by Cnt DESC
select operation, count(*) as Cnt from bronze.transactions group by operation order by Cnt DESC
select k_symbol, count(*) as Cnt from bronze.transactions group by k_symbol order by Cnt DESC
go

-- blanks and nulls in the sparse columns 
select SUM(case when operation is null or operation = '' then 1 else 0 end) as BlankOperation,
SUM(case when k_symbol is null or k_symbol = '' then 1 else 0 END) as BlankKSymbol,
sum(case when bank is null or bank = '' then 1 else 0 end) as BlankBank,
sum(case when account is null or account='' then 1 else 0 end) as BlankAccount
from bronze.transactions
GO

-- date conversion test (yymmdd - 19yymmdd)
select count(*) as BadDates from bronze.transactions
where TRY_CONVERT(date, '19' + cast([date] as varchar(6)), 112) is null 
GO

-- sign of amt by transaction type
select [type], min(amount) as MinAmount, max(amount) as MaxAmount,
sum(case when amount < 0 then 1 else 0 end) as NegativeRows
from bronze.transactions
GROUP BY [type]
go