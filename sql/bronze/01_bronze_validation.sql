use Berka_banking_analytics
go

-- verifying the bronze transactions
select count(*) as TotalRows from bronze.transactions
go

-- Inspecting the transaction date range
select min([date]) as EarliestRawDate, max([date]) as LatestRawDate from bronze.transactions
go