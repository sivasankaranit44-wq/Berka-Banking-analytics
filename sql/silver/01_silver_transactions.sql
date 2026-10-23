use Berka_banking_analytics
GO

if schema_id('silver') is null exec('create schema silver')
GO

drop table if exists silver.transactions
go

create table silver.transactions (
    trans_id    bigint      not null,
    account_id  int         not null,
    transaction_date date   not null,
    transaction_year SMALLINT   not null,
    transaction_month TINYINT   not null,
    transaction_type varchar(10) not null,
    operation_desc varchar(50) null,
    k_symbol_desc varchar(50)  null,
    amount DECIMAL(18,2) not null,
    signed_amount decimal(18,2) not null,
    balance decimal(18,2) not null,
    partner_bank varchar(10)  null,
    partner_account varchar(20) null,
    CONSTRAINT pk_silver_transactions PRIMARY KEY(trans_id)
)
go

insert into silver.transactions (
    trans_id, account_id, transaction_date, transaction_year, transaction_month,
    transaction_type, operation_desc, k_symbol_desc, amount, signed_amount, balance, partner_bank, partner_account
)
select t.trans_id, t.account_id, d.transaction_date, year(d.transaction_date),month(d.transaction_date), case when t.[type]='PRIJEM'
then 'Credit' else 'Debit' END, 
case clean.operation 
when 'VYBER KARTOU' then 'Credit Card Withdrawal'
when 'VKLAD' then 'Cash Deposit'
when 'PREVOD Z UCTU' then 'Incoming Transfer'
when 'VYBER' then 'Cash Withdrawal'
when 'PREVOD NA UCET' then 'Outgoing transfer'
else clean.operation end, 

case clean.k_symbol
when 'UROK' then 'Interest Credited'
when 'SLUZBY' then 'Service Fee'
when 'POJISTNE'  then 'Insurance Payment'
when 'SIPO' then 'Household Payment'
when 'DUCHOD' then 'Pension Credit'
when 'UVER' then 'Loan Payment'
when 'SANKC. UROK' then 'Penalty Interest'
else clean.k_symbol end,

t.amount, case when t.[type] = 'PRIJEM' then t.amount else -t.amount end, t.balance, clean.bank, clean.account
from bronze.transactions t cross apply(select try_convert(date, '19' + t.[date],112)as transaction_date) d cross apply (
    select nullif(LTRIM(RTRIM(t.operation)), '') as operation,
    nullif(LTRIM(RTRIM(t.k_symbol)),'') as k_symbol,
    nullif(LTRIM(RTRIM(t.bank)),'') as bank,
    nullif(LTRIM(RTRIM(t.account)),'') as account 
) clean
go

-- indexes for all gold layer
create index ix_silver_trans_account_date on silver.transactions(account_id, transaction_date)
create index ix_silver_trans_date on silver.transactions(transaction_date)
go
