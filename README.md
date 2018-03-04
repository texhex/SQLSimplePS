# SQLSimplePS
PowerShell wrapper for SQL Server data manipulation (DML)

## Introduction

SQL Simple is an attempt to make handling SQL with PowerShell easier and more secure. If you already use parameterized queries and have working transaction handling, this class is not for you.


## Usage

As it uses classes, it requires at least PowerShell 5.0. Copy ``SQLSimplePS.psm1`` to the folder where your script is, then add the following command as the first command in your script:

```
 using module .\SQLSimplePS.psm1
```
 
## Preparation for these examples

In order to execute these examples, please create a new database in your SQL Server called “TestDB”. When done, please execute this command which enabled Snapshot Isolation and creates a test table.

```sql
Use [TestDB]
GO

ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON
GO

CREATE TABLE [dbo].[TestTable](
	[ID] [int] IDENTITY(1,1) NOT NULL, [Name] [nvarchar](50) NOT NULL, [IntValue] [int] NOT NULL, [NumericValue] [decimal](5, 2) NOT NULL,
    CONSTRAINT [PK_TestTable] PRIMARY KEY CLUSTERED 
    ( [ID] ASC )
	WITH (IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) 
ON [PRIMARY]
GO

``` 

This Connection String is then used to connect to the database, which assumes a local installed SQL Server Express Edition. Please change it to fit your environment.

```
$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTests;"
```

## Single line execute

To add a single row of data, we can use a single command, the static function Execute()of SQLMap:

```powershelll
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) VALUES('First Test', 7, 12.3)", $connectionString)

```

This will not return anything, however if we add an [OUTPUT clause]( https://docs.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql) the return will be “2” as the second row has the ID of 2

```powershelll
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Second Test', 9, 45.66)", $connectionString)


```

Execute only returns an array of single values that were returned by SQL Server (it uses ExecuteScalar() internally). 

If you want to query the database, use the Query() command which returns a hash table:

```powershelll
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Query("SELECT * FROM dbo.TestTable", $connectionString)

```
Result:
```powershelll
Name                           Value
----                           -----
ID                             1
Name                           First Test
IntValue                       7
NumericValue                   12,30
ID                             2
Name                           Second Test
IntValue                       9
NumericValue                   45,66
```











