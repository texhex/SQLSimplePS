# SQLSimplePS
PowerShell wrapper for SQL Server data manipulation (DML)

## Introduction

SQL Simple is an attempt to make handling SQL with PowerShell easier and more secure. If you already use parameterized queries and have working transaction handling, this class is not for you.


## Usage

As it uses classes, it requires at least PowerShell 5.0. Copy ``SQLSimplePS.psm1`` and ``MPSXM.psm1`` to the folder where your script is, then add the following command as the first command in your script:

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

If you want to query the database, use the Query() command which returns a hash table. In case you are new to hash tables, please see [this excellent blog post by Kevin Marquette](https://kevinmarquette.github.io/2016-11-06-powershell-hashtable-everything-you-wanted-to-know-about/).
```powershelll
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Query("SELECT * FROM dbo.TestTable", $connectionString)

Result:

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


:exclamation: **Please do not stop here and think about using these two functions and some string replacement to get your task done. String replacement and SQL is a horrifying bad idea - please see [OWASP SQL Injection](https://www.owasp.org/index.php/SQL_Injection) for details. SQL Simple has methods in place to make this easy without any string replacement. Please read on.**


## Transaction isolation level

SQL Simple will *always* use transactions, even for SELECT statements (see [Begin Transaction documentation, section General Remarks](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/begin-transaction-transact-sql#general-remarks) why). It defaults to “Snapshot isolation” which works best for most tasks.

However, you might want to run command in databases that do not support Snapshot isolation. This will cause the error “Exception calling "Commit" with "0" argument(s): "This SqlTransaction has completed; it is no longer usable."

Both Execute() and Query() support to specify a different isolation level:

```powershelll
using module .\SQLSimplePS.psm1

$connectionString = "Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Query("SELECT * FROM dbo.TestTable", $connectionString, [System.Data.IsolationLevel]::Serializable)
```











