# SQLSimplePS
SQL Simple is an attempt to make handling SQL with PowerShell easier and more secure. If you already use parameterized queries and have working transaction handling, this class is not for you. Everybody, please read on.


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
$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"
```

## Single line execute

To add a single row of data, we can use a single command, the static function ``Execute()`` of SQLSimple:

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

[SQLSimple]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) VALUES('First Test', 7, 12.3)", $connectionString)
```

This will not return anything, however if we add an [OUTPUT clause]( https://docs.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql) the return will be “2” as the second row has the ID of 2

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

[SQLSimple]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Second Test', 9, 45.66)", $connectionString)
```

``Execute()`` only returns an array of single values that were returned by SQL Server (it uses ExecuteScalar() internally). 

If you want to query the database, use the ``Query()`` command which returns a hash table. In case you are new to hash tables, please see [this excellent blog post by Kevin Marquette](https://kevinmarquette.github.io/2016-11-06-powershell-hashtable-everything-you-wanted-to-know-about/).
```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

[SQLSimple]::Query("SELECT * FROM dbo.TestTable", $connectionString)

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

SQL Simple will *always* use transactions, even for SELECT statements (see [Begin Transaction documentation, section General Remarks](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/begin-transaction-transact-sql#general-remarks) why). It defaults to *Snapshot isolation* which works best for most tasks.

However, you might want to run command in databases that do not support Snapshot isolation. This will cause the error *Exception calling "Commit" with "0" argument(s): This SqlTransaction has completed; it is no longer usable.*

Both ``Execute()`` and ``Query()`` support to specify a different isolation level:

```powershell
using module .\SQLSimplePS.psm1

$connectionString = "Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

[SQLSimple]::Query("SELECT * FROM dbo.TestTable", $connectionString, [System.Data.IsolationLevel]::Serializable)
```

When using an instance of SQL Simple, you can define the isolation level like this:

```powershell
using module .\SQLSimplePS.psm1

$sqls = [SQLSimple]::new($connectionString)
$sqls.TransactionIsolationLevel = [System.Data.IsolationLevel]::Serializable

...
```


## Do not use string replacement 

:exclamation: **Please do not stop here and think about using these functions and some string replacement to get your task done. String replacement and SQL is a horrifying bad idea - please see [OWASP SQL Injection](https://www.owasp.org/index.php/SQL_Injection) for details. SQL Simple has methods in place to make this easy without any string replacement. Please read on.**


## Using parametrized queries

The static methods work for  simple tasks, but for more complex tasks you should create an instance of SQLSimple and add instance(s) of SQLSimpleCommand to it. To add a third row to *TestTable*, use the following code:

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

$sqls = [SQLSimple]::new($connectionString)

$insertCommand = [SQLSimpleCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Third Test', 11, 78.99);")

$sqls.AddCommand($insertCommand)

$sqls.Execute()
```

This will return “3” as ID of the row that have been inserted. 

If this looks like more code for the exact same task, this is correct. However, this changes when we do not want to have the values inside the SQL command, but supply them seperatly using parameters.

Parameters are placeholders that will be get their value a runtime and are processed by the runtime/SQL Server directly. SQL Simple expects the parameters to have the exact same name as the column they are for. The above noted SQL command looks like this when using parameters:

```sql
INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);
```

To supply the data those parameters will get, we can use the function ``AddMappingWithData()``:
```powershell
$insertCommand.AddMappingWithData("Name", "Fourth Test", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 22, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 11.11, [Data.SqlDbType]::Decimal)
```
The function first expects takes the name of the column where the data goes (in this example, “Name” is the name of the column in TestTable), then the data which should be stored in this column (“Fourth Test”) and the last parameter is the data type the column has: “Name” is defined as “NVarChar”. 

The entire code then looks like this:

```powershell
$sqls = [SQLSimple]::new($connectionString)

$insertCommand = [SQLSimpleCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

$insertCommand.AddMappingWithData("Name", "Fourth Test", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 22, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 11.11, [Data.SqlDbType]::Decimal)

$sqls.AddCommand($insertCommand)

$sqls.Execute()
```

This will return 4, as this is the ID of the row we just inserted.

One of the advantages is that the base SQL command is only parsed once (as only the values are different, but not the SQL itself), so they are faster - but in normal scenarios this effect is neglectable. What makes them great is that they are nearly immune to SQL injection (see [OWASP SQL Injection](https://www.owasp.org/index.php/SQL_Injection)).

Suppose we would use string replacement and we get a name like this:
```sql
'); DELETE FROM DBO.USERS; GO --'
```

When using string replacement, we would be in big trouble, but with parameters we can do this:

```powershell
$sqls = [SQLSimple]::new($connectionString)

$insertCommand = [SQLSimpleCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

$badName=@"
'); DELETE FROM DBO.USERS; GO --
"@

$insertCommand.AddMappingWithData("Name", $badName, [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 33, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)

$sqls.AddCommand($insertCommand)

$sqls.Execute()
```

SQL Simple will return 5 as ID because *$badName* was not part of the SQL, but just a value that was replaced at runtime.


It is also possible to query the database using parameters:

```powershell
$sqls = [SQLSimple]::new($connectionString)

$selectCommand = [SQLSimpleCommand]::new("SELECT * from dbo.TestTable WHERE IntValue < @IntValue;")

$selectCommand.AddMappingWithData("IntValue", 12, [Data.SqlDbType]::Int)

$sqls.AddCommand($selectCommand)

$sqls.Query()
```

This query will return three rows: First Test, Second Test and Third Test as their IntValue are below 12).


## Using several parametrized queries at once

SQL Simple supports adding more than one command and execute all in one go. A typical example is to clear a table before adding new data. 


```powershell
$sqls = [SQLSimple]::new($connectionString)

$sqls.AddCommand("DELETE FROM dbo.TestTable")

$sqls.AddCommand("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Chain Test 1', 11, 11.11);")

$sqls.Execute()
```

When executed, *TestTable* will only contain one row. SQL Simple executes all commands in a **single transaction** so either all the commands will work, or the transaction is rolled back, and the database will be in the same state before the command (no changes are made). 


Of course, you can also use ``AddMappingWithData()`` with several commands, but note that each command requires their own mapping. 

```powershell
$sqls = [SQLSimple]::new($connectionString)

$deleteCommand = [SQLSimpleCommand]::new("DELETE FROM dbo.TestTable WHERE IntValue = @IntValue")
$deleteCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$sqls.AddCommand($deleteCommand)

$insertCommand = [SQLSimpleCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")
$insertCommand.AddMappingWithData("Name", "Chain Test 2", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)
$sqls.AddCommand($insertCommand)

$sqls.Execute()
```

This command will first delete any record with a IntValue of 2 and then add a new record. You can add as many command as you require but note that the size of the transaction log of the database limits the number of changes. 

When chaining several commands, you can use the ``@@OBJECT_NAME@@`` replacement value and the ``Objectname`` property to write the object name only once. The below code makes use of this and is, beside from this change, the exact same as the code above. 

```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"

$deleteCommand = [SQLSimpleCommand]::new("DELETE FROM @@OBJECT_NAME@@ WHERE IntValue = @IntValue")
$deleteCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$sqls.AddCommand($deleteCommand)

$insertCommand = [SQLSimpleCommand]::new("INSERT INTO @@OBJECT_NAME@@(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")
$insertCommand.AddMappingWithData("Name", "Chain Test 2", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)
$sqls.AddCommand($insertCommand)

$sqls.Execute()
```


:exclamation: **Note that @@OBJECT_NAME@@ and other @@ replacement values use string replacement and are therefore open to string injection. These values should *NEVER EVER* be set to anything you didn't coded directly. Means: Do not use any variable data that is user supplied or comes from a source that you do not control. When in doubt, do not use them.**


Because deleting all records and then inserting new records is a common tasks, SQL Simple offers SQL Templates that works for these simple tasks that make use of ``@@OBJECT_NAME@@``, ``@@COLUMN@@`` and ``@@PARAMETER@@`` replacement values. When using these templates using the SQLCommandTemplate enumeration, the code looks like this:

```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"

$deleteCommand = [SQLSimpleCommand]::new([SQLCommandTemplate]::Delete)
# [SQLCommandTemplate]::Delete translates to:
# DELETE FROM @@OBJECT_NAME@@ WHERE @@COLUMN@@=@@PARAMETER@@;

$deleteCommand.AddMappingWithData("IntValue", 3, [Data.SqlDbType]::Int)
$sqls.AddCommand($deleteCommand)

$insertCommand = [SQLSimpleCommand]::new([SQLCommandTemplate]::Insert)
# [SQLCommandTemplate]::Insert translates to:
# INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);

$insertCommand.AddMappingWithData("Name", "Chain Test 3", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 3, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 33.33, [Data.SqlDbType]::Decimal)
$sqls.AddCommand($insertCommand)

$sqls.Execute()
```

* The insert and update  templates contain an OUTPUT clause for the field named ``ID``. If your table does not contain an column of this name or it isn't the primary key, the templates are of no use for you.
* Beside that, the insert template should work for most cases
* Both the UPDATE and the DELETE statement can only handle a single mapping value. If more mappings are used, the command will fail


## Using the DATA property

Until now, all command only added a single row but in most cases you want to deal with more rows.

SQL Simple supports this by using the ``Data`` property and mapping the properties of these external objects to the SQL Server object. 

For this example, we want to save the names, CPU time and the number of handles of the currently running processes to *TestTable*. We limit the list to processes that use more between 0 and 10 CPU time.

```powershell
get-process | where-object CPU -gt 0 | where-object CPU -lt 10

Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    382      22    18868      31940       1,00   9572   1 ApplicationFrameHost
    624      15    11184      15440       0,17  10712   1 CodeHelper
    259      14     5368      16924       1,20   1956   1 conhost
    110       7     5260        504       0,11  10996   1 conhost
    110       7     5268      10032       0,02  12788   1 conhost
    134      10     7024      11204       0,41  20132   1 conhost
    215      17    14824        164       0,09   8252   1 DipAwayMode

```

The mapping is as follows:

```powershell
dbo.TestTable.Name = Get-Process ProcessName 
dbo.TestTable.IntValue = Get-Process Handles  
dbo.TestTable.NumericValue = Get-Process CPU 
```

The code to create this mapping is creating a SQLSimpleColumn which requires three parameters:

* **Column Name** (*Name*) - The name of the SQL Server column the data should go
* **Property Name** (*ProcessName*) - The name of the property from data to get the value
* **Data Type** (*NVarChar*) - The data type of the column in SQL Server

For the first column, the SQLSimpleColumn would be declared as follows:

```powershell
$col=[SQLSimpleColumn]::new("Name", "ProcessName", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMapping($col)
```

To declare it in a single line and add it, use this syntax:
```powershell
$insertCommand.AddMapping("Name", "ProcessName", [Data.SqlDbType]::NVarChar) 

```

This mapping means that SQL Simple will query each object (which you added to the ``Data`` property) for the value of the ``ProcessName`` property and store the returned value in the ``Name`` column. 

The entire code looks like this:

```powershell
#Get list of processes
$procs=get-process | where-object CPU -gt 0 | where-object CPU -lt 10

$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"

#First delete all rows
$sqls.AddCommand("DELETE FROM dbo.TestTable")

#Use standard insert template
$insertCommand = [SQLSimpleCommand]::new([SQLCommandTemplate]::Insert)

#Create the mapping
$insertCommand.AddMapping("Name", "ProcessName", [Data.SqlDbType]::NVarChar) 
$insertCommand.AddMapping("IntValue", "Handles", [Data.SqlDbType]::int) 
$insertCommand.AddMapping("NumericValue", "CPU", [Data.SqlDbType]::Decimal) 

#Assign the data property which holds the data that is used as the values for the mapping
$insertCommand.Data=$procs

$sqls.AddCommand($insertCommand)

$sqls.Execute()
```

When executed, all running processes are saved to *TestTable* and we can query the table for ApplicationFrameHost (first entry):

```powershell
[SQLSimple]::Query("SELECT * FROM TestTable where IntValue=382", $connectionString)

Name                           Value
----                           -----
ID                             239
Name                           ApplicationFrameHost
IntValue                       382
NumericValue                   1,00
```

This was the output of get-process:

```powershell
Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    382      22    18868      31940       1,00   9572   1 ApplicationFrameHost
```

Thanks for reading!

ENDE
