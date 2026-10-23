use Berka_banking_analytics
GO

-- row count (10,56,320)
select count(*) as SilverRows from silver.transactions
go

--  no null dates
select count(*) as NullDates from silver.transactions where transaction_date is NULL
go

-- splitting credit and debit card
select transaction_type, count(*) as Cnt, sum(signed_amount) as NetAmount
from silver.transactions GROUP BY transaction_type
go

-- Row with null ops: 
select operation_desc, k_symbol_desc, count(*) as Cnt
from silver.transactions
where operation_desc is null
GROUP BY operation_desc, k_symbol_desc order by Cnt desc
go

-- Translated values and leftover empty strings
select operation_desc, count(*) as Cnt from silver.transactions GROUP BY operation_desc ORDER BY Cnt DESC
select k_symbol_desc, count(*) as Cnt from silver.transactions GROUP BY k_symbol_desc order by Cnt DESC
select count(*) as EmptyStrings from silver.transactions
where operation_desc = '' or k_symbol_desc ='' or partner_bank = '' or partner_account ='' 
go
