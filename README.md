# SQLSimplePS

SQL Simple aims to make handling SQL Server data with PowerShell easier and more secure. It features:

* Static functions that can be used as "single line commands" to run against SQL Server (``Execute()`` returns single values, while ``Query()`` returns hash tables)
* Chaining several commands that will execute in a single transaction
* Parametrized queries are fully supported and adding a parameter and its value is done in a single line
* Several SQL templates are available so for simple tasks, you do not need to write any SQL
* It can map the properties of an external source object to parameters which allows to use the source objects directly instead of copying them as parameter values first
* This also applies to an array/list/collection of external data objects
* It defaults to SNAPSHOT ISOLATION but any other isolation level can also be used

## Usage

As SQL Simple is implemented as a class, it requires at least PowerShell 5.0. To use it, [download this repository](https://github.com/texhex/SQLSimplePS/archive/master.zip), copy ``SQLSimplePS.psm1`` and ``MPSXM.psm1`` to the folder where your script is and add the following command as the first command in your script:

```powershell
 using module .\SQLSimplePS.psm1
```

## Preparation for these examples

In order to execute these examples, please create a new database in your SQL Server called “TestDB”. When done, please execute this command which enabl Snapshot Isolation and create a test table.

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

This connection string is used in all examples to connect to the database. It assumes a local installed SQL Server Express Edition; please change it to fit your environment.

```config
$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"
```

## Single line SQL execution

To execute a simple SQL command (no pun intended) like an INSERT, the static function ``Execute()`` can be used:

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

[SQLSimple]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) VALUES('First Test', 7, 12.3)", $connectionString)
```

This will not return anything, however if we add an [OUTPUT clause]( https://docs.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql) the return will be “2” as the second row has the ID of 2:

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

[SQLSimple]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Second Test', 9, 45.66)", $connectionString)
```

``Execute()`` returns an array of single values that were returned by SQL Server (the first column of the first row).

In order to run a query and get full results (SELECT), use the ``Query()`` command which returns an array of hash table. In case you are new to hash tables, please read [this excellent blog post by Kevin Marquette](https://kevinmarquette.github.io/2016-11-06-powershell-hashtable-everything-you-wanted-to-know-about/).

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

---

:exclamation: Please do not think about using these functions and some string replacement to get your task done. String replacement and SQL is a **horrifying bad idea** - see [OWASP SQL Injection](https://www.owasp.org/index.php/SQL_Injection). SQL Simple has methods in place to make this easy without any string replacement.

---

## Executing SQL

SQLSimple offers three commands to run SQL commands. All three are available as instance functions (``$sqls.Query/Execute/ExecuteScalar``) and as static functions (``[SQLSimple]::Query/Execute/ExecuteScalar()``)

* Query
* Execute
* ExecuteScalar

``Query()`` is used if you want to get full details, most likely when you use a SELECT statement. It returns an array where each element is a hash table. This allows for an easy looping using foreach():

```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.AddCommand("SELECT Name, IntValue FROM dbo.TestTable;")
$results=$sqls.Query()

foreach ($row in $results)
{
  write-host "Item $($row.Name) has a value of $($row.IntValue)"
}
```

Please note however, that you can use only one ``AddCommand()`` with an instance of SQLSimple if you plan to use ``Query()``. If more than one command have been added, ``Query()`` will throw an error.

``Execute()`` is used if you only need limited details, mostly for INSERT or UPDATE statements. It returns an array with the value of the first column of the first row for each command executed.

```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.AddCommand("SELECT 'abc';")
$sqls.AddCommand("SELECT 'klm';")
$sqls.AddCommand("SELECT 'xyz';")
$results=$sqls.Execute()

# This will print three rows
foreach ($row in $results)
{
  write-host "Item $row"
}
```

``ExecuteScalar()`` works the same as ``Execute()`` but will only return a single value, the very first element of the array  ``Execute()`` returns. This function can be handy if you only care about this single value and want to skip dealing with an array.


```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.AddCommand("SELECT 'abc';")
$sqls.AddCommand("SELECT 'klm';")
$sqls.AddCommand("SELECT 'xyz';")
$value=$sqls.ExecuteScalar()

# Will print "Value is abc"
write-host "Value is $value"
```

Please note that, although only a single value is returned, *ALL* commands will be executed. There is no difference in the inner workings of ``Execute()`` and ``ExecuteScalar()``, only the output is different.

## Transaction isolation level

SQL Simple will *always* use transactions, even for SELECT statements (see [Begin Transaction documentation, section General Remarks](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/begin-transaction-transact-sql#general-remarks) why). It defaults to *Snapshot isolation* that works best for most tasks.

However, you might want to run commands in databases that do not support Snapshot isolation (running a command on a database that does not support snapshot isolation will return the error *Exception calling "Commit" with "0" argument(s): This SqlTransaction has completed; it is no longer usable.*). You can specify a different isolation level as a parameter for ``Execute()``, ``ExecuteScalar()`` and ``Query()``:

```powershell
using module .\SQLSimplePS.psm1

$connectionString = "Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

[SQLSimple]::Query("SELECT * FROM dbo.TestTable", $connectionString, [System.Data.IsolationLevel]::Serializable)
```

When using an instance of SQL Simple, you define the isolation level like this:

```powershell
using module .\SQLSimplePS.psm1

$sqls = [SQLSimple]::new($connectionString)

$sqls.TransactionIsolationLevel = [System.Data.IsolationLevel]::Serializable

...
```

To not use transactions at all, use ``[System.Data.IsolationLevel]::Unspecified``. Please note that **without** transactions a lot of command will run significantly slower than with transactions enabled. In short: Only disable transactions if a command can not be executed in a transaction, for example ``BACKUP DATABASE``.



## Using parametrized queries

The static methods work for simple tasks, but for more complex tasks use an instance of SQLSimple and add commands to it.

```powershell
using module .\SQLSimplePS.psm1

$connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

$sqls = [SQLSimple]::new($connectionString)

$sqls.AddCommand("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Third Test', 11, 78.99);")

$sqls.Execute()
```

This will return “3” as ID of the row that have been inserted.

If this looks like more code for the exact same task, this is correct. However, this changes when we do not want to have the values inside the SQL command, but supply them seperatly using parameters.

Parameters are placeholders that will be get their value a runtime and are processed by the runtime/SQL Server directly. SQL Simple expects the parameters to have the exact same name as the column they are for. When using parameters, the code ist as follows:

```sql
INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);
```

To supply the data those parameters will get, we can use the function ``AddMappingWithData()``:

```powershell
$insertCommand.AddMappingWithData("Name", "Fourth Test", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 22, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 11.11, [Data.SqlDbType]::Decimal)
```

The function first expects the name of the column where the data goes (in this example, “Name” is the name of the column in TestTable), then the data which should be stored in this column (“Fourth Test”) and the last parameter is the data type the column has: “Name” is defined as “NVarChar”.

The entire code then looks like this:

```powershell
$sqls = [SQLSimple]::new($connectionString)

$insertCommand = $sqls.AddCommandEx("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

$insertCommand.AddMappingWithData("Name", "Fourth Test", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 22, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 11.11, [Data.SqlDbType]::Decimal)

$sqls.Execute()
```

This will return 4, as this is the ID of the row that was inserted.

One of the advantages is that the base SQL command is only parsed once (as only the values are different, but not the SQL itself), so they are faster - but in normal scenarios this effect is neglectable. What makes them great however is that they are nearly immune to SQL injection (see [OWASP SQL Injection](https://www.owasp.org/index.php/SQL_Injection)). Suppose we would use string replacement and we get a name like this:

```sql
'); DELETE FROM DBO.USERS; GO --'
```

When using string replacement, we would be in big trouble, but with parameters that's no problem at all:

```powershell
$sqls = [SQLSimple]::new($connectionString)

$insertCommand = $sqls.AddCommandEx("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

$badName=@"
'); DELETE FROM DBO.USERS; GO --
"@

$insertCommand.AddMappingWithData("Name", $badName, [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 33, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)

$sqls.Execute()
```

SQL Simple will return 5 as ID because *$badName* was not part of the SQL, but just a value that was replaced at runtime.

It is also possible to query the database using parameters:

```powershell
$sqls = [SQLSimple]::new($connectionString)

$selectCommand = $sqls.AddCommandEx("SELECT * from dbo.TestTable WHERE IntValue < @IntValue;")

$selectCommand.AddMappingWithData("IntValue", 12, [Data.SqlDbType]::Int)

$sqls.Query()
```

This query will return three rows: First Test, Second Test and Third Test as their IntValue are below 12.

## NULL Handling

By default, the NULL handling between PowerShell and SQL Server is incompatible. Passing $null as value will not cause SQL Server to store it as NULL, neither will a test for $null (``$myValue -eq $null``) work if ``$myValue`` contains a NULL value from SQL Server.

That’s because to PowerShell, the NULL value SQL Server returns is actually ``[System.DBNull]::Value`` which is not the same as the PowerShell NULL value of ``$null``. For more details, please see [this question on StackOverflow](https://stackoverflow.com/q/22285149).

SQL Simple will therefore check any return from SQL Server if it’s DBNull and if so, replace it with ``$null``. When using parameters, ``$null`` will be replaced with DBNull.

## Connection string from external file

In case you have several script files that share the same connection string, you can store it in an external file and use it with the static function ``CreateFromConnectionStringFile()``. This function will read the content of the ``ConnectionString.conf`` located in the same folder as your script and return a SQLSimple instance with the ConnectionString set to the content of the file.

```powershell
#Use the connection string from ConnectionString.conf in the script folder
$sqls = [SQLSimple]::CreateFromConnectionStringFile()

write-host "Database connection string: $($sqls.ConnectionString)"

$sqls.AddCommand("SELECT * from dbo.TestTable")

$sqls.Query()
```

The file does not have any special format, SQL Simple will just read the entire content and use it as connection string:

```config
Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;
```

In case you want to use more than one connection string file, this is also possible:

```powershell
#Use the connection string from file server1.connection stored in script folder
$sqls = [SQLSimple]::CreateFromConnectionStringFile("server1.connection")

write-host "Database connection string: $($sqls.ConnectionString)"

$sqls.AddCommand("SELECT * from dbo.TestTable")

$sqls.Query()
```

## Using several parametrized queries at once

SQL Simple supports adding more than one command and execute all in one go. A typical example is to clear a table before adding new data.

```powershell
$sqls = [SQLSimple]::new($connectionString)

$sqls.AddCommand("DELETE FROM dbo.TestTable")

$sqls.AddCommand("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Chain Test 1', 11, 11.11);")

$sqls.Execute()
```

When executed, *TestTable* will only contain one row. SQL Simple executes all commands in a **single transaction** so either all the commands will work, or the transaction is rolled back, and the database will be in the same state before the command (no changes are made).

You can also use ``AddMappingWithData()`` with several commands, but note that each command requires their own mapping.

```powershell
$sqls = [SQLSimple]::new($connectionString)

$deleteCommand = $sqls.AddCommandEx("DELETE FROM dbo.TestTable WHERE IntValue = @IntValue")
$deleteCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)

$insertCommand = $sqls.AddCommandEx("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")
$insertCommand.AddMappingWithData("Name", "Chain Test 2", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)

$sqls.Execute()
```

This command will first delete any record with a IntValue of 2 and then add a new record.

You can add as many commands to an instance of SQLSimple as you require. To do so, you have several possibilities:

* When the command is a simple SQL command, use the ``AddCommand()`` with a string
  * ``$sqls.AddCommand("DELETE FROM dbo.TestTable")``
* Use one of the SQLCommandTemplates with ``AddCommand()``
  * ``$sqls.AddCommand([SQLCommandTemplate]::Delete)``
* To have the command object returned (e.g. to add mappings), use the ``AddCommandEx()`` function
  * ``$command = $sqls.AddCommandEx("DELETE FROM dbo.TestTable WHERE IntValue < @IntValue")``
* The SQLCommandTemplate parameter is also supported by ``AddCommandEx()``
  * ``$command = $sqls.AddCommandEx([SQLCommandTemplate]::Delete)``
* Creating it with the ``::new`` operator, then adding the object with ``AddCommand()``. This can be handy in case you need to run the same command against several databases
  * ``$deleteCommand = [SQLSimpleCommand]::new("DELETE FROM dbo.TestTable")``
  * ``$sqls.AddCommand($deleteCommand)``
* Creating it with the ``::new`` operator and using a SQLCommandTemplate, then adding the object with ``AddCommand()``.
  * ``$deleteCommand = [SQLSimpleCommand]::new([SQLCommandTemplate]::Delete)``
  * ``$sqls.AddCommand($deleteCommand)``

## SQL command templates

When chaining several commands, you can use the ``@@OBJECT_NAME@@`` replacement value and the ``Objectname`` property to write the object name only once. The below code makes use of this and is, beside from this change, the exact same as the last example.

```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"

$deleteCommand = $sqls.AddCommandEx("DELETE FROM @@OBJECT_NAME@@ WHERE IntValue = @IntValue")
$deleteCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)

$insertCommand = $sqls.AddCommandEx("INSERT INTO @@OBJECT_NAME@@(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")
$insertCommand.AddMappingWithData("Name", "Chain Test 2", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)

$sqls.Execute()
```

---

:exclamation: Note that *@@OBJECT_NAME@@* and other *@@* replacement values **use string replacement and are therefore open to string injection**. They exist to make the coding easier, not for dynamic replacement. *NEVER EVER* set them to anything you didn't coded directly. Means: Do not use any variable data that is user supplied or comes from a source that you do not control. When in doubt, do not use them.

---

Because deleting all records and then inserting new records is a common tasks, SQL Simple offers SQL templates that works for these tasks and that use ``@@OBJECT_NAME@@``, ``@@COLUMN@@``, ``@@PARAMETER@@`` and  ``@@COLUMN_EQUALS_PARAMETER@@`` replacement values. When using these templates, using the SQLCommandTemplate enumeration, the code looks like this:

```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"

$deleteCommand = $sqls.AddCommandEx([SQLCommandTemplate]::Delete)
# [SQLCommandTemplate]::Delete translates to:
# DELETE FROM @@OBJECT_NAME@@ WHERE @@COLUMN@@=@@PARAMETER@@ AND @@COLUMN@@=@@PARAMETER@@ ...;
$deleteCommand.AddMappingWithData("IntValue", 3, [Data.SqlDbType]::Int)

$insertCommand = $sqls.AddCommandEx([SQLCommandTemplate]::Insert)
# [SQLCommandTemplate]::Insert translates to:
# INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@, @@COLUMN@@ ...) VALUES(@@PARAMETER@@, @@PARAMETER@@ ...);
$insertCommand.AddMappingWithData("Name", "Chain Test 3", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 3, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 33.33, [Data.SqlDbType]::Decimal)

$sqls.Execute()
```

SQLCommandTemplate offers the following templates:

* Delete
  * ``DELETE FROM @@OBJECT_NAME@@ WHERE @@COLUMN_EQUALS_PARAMETER@@;``
* DeleteReturnID
  * ``DELETE FROM @@OBJECT_NAME@@ OUTPUT Deleted.ID WHERE @@COLUMN_EQUALS_PARAMETER@@;``
* DeleteAll
  * ``DELETE FROM @@OBJECT_NAME@@;``
* DeleteAllReturnID
  * ``DELETE FROM @@OBJECT_NAME@@ OUTPUT Deleted.ID;``
* Insert
  * ``INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) VALUES(@@PARAMETER@@);``
* InsertReturnID
  * ``INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);``

In case you miss an UPDATE template, there is no template for this. A typical UPDATE statement can contain the same column for the new value as well as being used in the WHERE clause (``UPDATE dbo.TestTable SET Name='New Name' where Name='First Test'``). I have not found a way to implement this correctly.

## Adding data to the DATA property

Until now, all command only added a single row but in most cases you want to deal with more rows. SQL Simple supports this by using the ``Data`` property and mapping the properties of these external objects to the SQL Server object.

Suppose you have two hash tables and they should be stored in *TestTable*

```powershell
$myData1 = @{ NameProp = "Chain Test 4"; MyCount = 4; NumericVal = 44.44; }

$myData2 = @{ NameProp = "Chain Test 5"; MyCount = 5; NumericVal = 55.55; }
```

The mapping in this case would be like this:

```powershell
dbo.TestTable.Name = Value from hash table "NameProp" property
dbo.TestTable.IntValue =  Value from hash table "MyCount" property
dbo.TestTable.NumericValue =  Value from hash table "NumericVal" property
```

To define these mappings, the method ``AddMapping()`` is used that creates a SQLSimpleColumn instance internally:

```powershell
$insertCommand.AddMapping("Name", "NameProp", [Data.SqlDbType]::NVarChar)
```

This line means that the mapping between the column *Name* should get the value of the *NameProp* property and the data type is NVarChar.

The final code is as follows:

```powershell
$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"

$insertCommand = $sqls.AddCommandEx("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

#Add the mapping
$insertCommand.AddMapping("Name", "NameProp", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMapping("IntValue", "MyCount", [Data.SqlDbType]::int)
$insertCommand.AddMapping("NumericValue", "NumericVal", [Data.SqlDbType]::Decimal)

#Add data #1
$myData1 = @{ NameProp = "Chain Test 4"; MyCount = 4; NumericVal = 44.44; }
$insertCommand.AddData($myData1)

#Add data #2
$myData2 = @{ NameProp = "Chain Test 5"; MyCount = 5; NumericVal = 55.55; }
$insertCommand.AddData($myData2)

$sqls.Execute()
```

As we have added two data objects to ``$insertCommand``, SQL Simple will run the second command two times, so both items are inserted into *TestTable*.

## Using the DATA property directly

If you have a rather long list of objects, there is no need to add them one by one using ``AddData()``, you can just set the data property to the list.

For example, we want to save the names, CPU time and the number of handles of the currently running processes to *TestTable*. We limit the list to processes that use between 0 and 10 CPU time.

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

The code to create this mapping is again a SQLSimpleColumn which requires three parameters:

* **Column Name** (*Name*) - The name of the SQL Server column the data should go
* **Property Name** (*ProcessName*) - The name of the property from data to get the value
* **Data Type** (*NVarChar*) - The data type of the column in SQL Server

For the first column, the mapping is declared as follows:

```powershell
$insertCommand.AddMapping("Name", "ProcessName", [Data.SqlDbType]::NVarChar)
```

This mapping means that SQL Simple will query each object (which you added to the ``Data`` property) for the value of the ``ProcessName`` property and store the returned value in the ``Name`` column.

We capture all processes in the ``$procs`` variable and later on add this list directly to the ``Data`` property:

```powershell
$procs=get-process | where-object CPU -gt 0 | where-object CPU -lt 10

...

$insertCommand.Data=$procs
```

The entire code, when using replacement values and SQL templates:

```powershell
#Get list of processes
$procs=get-process | where-object CPU -gt 0 | where-object CPU -lt 10

$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"

#First delete all rows
$sqls.AddCommand([SQLCommandTemplate]::DeleteAll)

#Use standard insert template
$insertCommand = $sqls.AddCommandEx([SQLCommandTemplate]::Insert)

#Create the mapping
$insertCommand.AddMapping("Name", "ProcessName", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMapping("IntValue", "Handles", [Data.SqlDbType]::int)
$insertCommand.AddMapping("NumericValue", "CPU", [Data.SqlDbType]::Decimal)

#Assign the data property which holds the data that is used as values for our mapping
$insertCommand.Data=$procs

$sqls.Execute()
```

When executed, all processes from ``$procs`` are saved to *TestTable* and we can query the table for ApplicationFrameHost (first entry):

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

## Contributions

Any constructive contribution is very welcome! If you encounter a bug or have an idea for an improvment, please open a [new issue](https://github.com/texhex/SQLSimplePS/issues/new).

## License

``SQLSimplePS.psm1`` and ``MPSXM.psm1``: Copyright © 2015-2018 [Michael Hex](http://www.texhex.info/). Licensed under the **Apache 2 License**. For details, please see LICENSE.txt.

** ENDE **
