# SQLSimplePS
PowerShell wrapper for SQL Server data manipulation (DML)

## Introduction

SQL Simple is an attempt to make handling SQL with PowerShell easier and more secure. If you already use parameterized queries and have working transaction handling, this class is not for you.


## Usage

As it uses classes, it requires at least PowerShell 5.0. Copy ``SQLSimplePS.psm1`` and ``MPSXM.psm1`` to the folder where your script is, then add the following command as the first command in your script:

```powershell
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

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) VALUES('First Test', 7, 12.3)", $connectionString)
```

This will not return anything, however if we add an [OUTPUT clause]( https://docs.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql) the return will be “2” as the second row has the ID of 2

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Second Test', 9, 45.66)", $connectionString)
```

Execute only returns an array of single values that were returned by SQL Server (it uses ExecuteScalar() internally). 

If you want to query the database, use the Query() command which returns a hash table. In case you are new to hash tables, please see [this excellent blog post by Kevin Marquette](https://kevinmarquette.github.io/2016-11-06-powershell-hashtable-everything-you-wanted-to-know-about/).
```powershell
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

## Transaction isolation level

SQL Simple will *always* use transactions, even for SELECT statements (see [Begin Transaction documentation, section General Remarks](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/begin-transaction-transact-sql#general-remarks) why). It defaults to “Snapshot isolation” which works best for most tasks.

However, you might want to run command in databases that do not support Snapshot isolation. This will cause the error *Exception calling "Commit" with "0" argument(s): "This SqlTransaction has completed; it is no longer usable.*

Both Execute() and Query() support to specify a different isolation level:

```powershell
using module .\SQLSimplePS.psm1

$connectionString = "Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

[SQLMap]::Query("SELECT * FROM dbo.TestTable", $connectionString, [System.Data.IsolationLevel]::Serializable)
```

## Do not use string replacement 

:exclamation: **Please do not stop here and think about using these functions and some string replacement to get your task done. String replacement and SQL is a horrifying bad idea - please see [OWASP SQL Injection](https://www.owasp.org/index.php/SQL_Injection) for details. SQL Simple has methods in place to make this easy without any string replacement. Please read on.**


## Using parametrized queries

The static methods are for very simple tasks enough, but for more complex tasks you should create an instance of SQLMap and add an instance of a SQLMapCommand to it. To add a third row to the *TestTable*, use the following:

```powershelll
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

$map = [SQLMap]::new($connectionString)

$insertCommand = [SQLMapCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Third Test', 11, 78.99);")

$map.AddCommand($insertCommand)

$map.Execute()
```

This will return “3” as ID of the row that have been inserted. 

If this looks like more code for the exact same task, this is correct. However, this changes when we do not want to have the values inside the SQL, but use parameters.

Parameters are placeholders that will be get their value a runtime and are processed by SQL Server directly. SQL Simple expects the parameters to have the exact same name as the column they are for.

The above noted SQL looks like this when using parameters:

```sql
INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);
```

To supply the data those parameters will get, we can use the function ``AddMappingWithData()``:
```powershelll
$insertCommand.AddMappingWithData("Name", "Fourth Test", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 22, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 11.11, [Data.SqlDbType]::Decimal)
```
The function first expects takes the name of the column where the data goes (in this example, “Name” is the name of the column in TestTable), then the data which should be stored in this column (“Fourth Test”) and the last parameter is the data type the column has: “Name” is defined as “NVarChar”. 

The entire code then looks like this:

```powershell
$map = [SQLMap]::new($connectionString)

$insertCommand = [SQLMapCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

$insertCommand.AddMappingWithData("Name", "From SQLSimplePS_First", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 22, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 11.11, [Data.SqlDbType]::Decimal)

$map.AddCommand($insertCommand)

$map.Execute()
```












