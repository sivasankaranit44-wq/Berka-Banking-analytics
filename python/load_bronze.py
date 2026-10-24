"""Load the Berka CSV files into the bronze schema (raw text, no cleaning)."""
import urllib.parse

import pandas as pd
from sqlalchemy import create_engine, text

# ---------- Settings ----------
DATA_DIR = r"F:\DSA\Projects DA\Project_Berka\Berka\data"
SERVER = r".\SQLEXPRESS01"
DATABASE = "Berka_banking_analytics"
SEP = ";"

# bronze table name -> file name inside DATA_DIR
FILES = {
    "account": "account.csv",
    "client": "client.csv",
    "disp": "disp.csv",
    "district": "district.csv",
    "loan": "loan.csv",
    "card": "card.csv",
    "orders": "order.csv",
}

# ---------- Connection ----------
conn_str = urllib.parse.quote_plus(
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)
engine = create_engine(
    f"mssql+pyodbc:///?odbc_connect={conn_str}",
    fast_executemany=True,
)

# ---------- Load each file into bronze ----------
for table, file in FILES.items():
    path = rf"{DATA_DIR}\{file}"
    df = pd.read_csv(path, sep=SEP, dtype=str, keep_default_na=False)
    df.columns = [c.strip().strip('"') for c in df.columns]
    df.to_sql(table, engine, schema="bronze", if_exists="replace", index=False)
    print(f"{table:10s} {len(df):6d} rows | columns: {list(df.columns)}")

# ---------- Verify from the database side ----------
with engine.connect() as conn:
    rows = conn.execute(
        text(
            "select table_name from INFORMATION_SCHEMA.TABLES "
            "where table_schema = 'bronze' order by table_name"
        )
    ).fetchall()
    print("\nTables now in bronze:", [r[0] for r in rows])