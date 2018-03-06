#This script requires PowerShell 5.1 because we are using classes
#requires -version 5

#Guard against common code errors
Set-StrictMode -version 2.0

#Terminate script on errors 
$ErrorActionPreference = 'Stop'



$connectionString = "Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"


#[SQLSimple]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) VALUES('Second Test', 9, 45.66)", $connectionString)

#[SQLSimple]::Query("SELECT * FROM dbo.TestTable", $connectionString)


<#
$sqls = [SQLSimple]::new($connectionString)

$sqls.AddCommand("DELETE FROM dbo.TestTable")

$sqls.AddCommand("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Chain Test 1', 11, 11.11);")

$sqls.Execute()
#>

$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname = "dbo.TestTable"

$deleteCommand = $sqls.AddCommandEx("DELETE FROM dbo.TestTable WHERE IntValue = @IntValue AND NumericValue = @NumericValue OUTPUT Deleted.ID;")
$deleteCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$deleteCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)

$insertCommand = $sqls.AddCommandEx("INSERT INTO @@OBJECT_NAME@@(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")
$insertCommand.AddMappingWithData("Name", "Chain Test 2", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 2, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)

$sqls.Execute()






<#
$procs=get-process | where-object CPU -gt 0 | where-object CPU -lt 10
$sqls = [SQLSimple]::new($connectionString)
$sqls.Objectname="dbo.TestTable"
$sqls.AddCommand("DELETE FROM dbo.TestTable")
$insertCommand = [SQLSimpleCommand]::new([SQLCommandTemplate]::Insert)
$insertCommand.AddMapping( [SQLSimpleColumn]::new("Name", "ProcessName", [Data.SqlDbType]::NVarChar) ) 
$insertCommand.AddMapping( [SQLSimpleColumn]::new("IntValue", "Handles", [Data.SqlDbType]::int) ) 
$insertCommand.AddMapping( [SQLSimpleColumn]::new("NumericValue", "CPU", [Data.SqlDbType]::Decimal) ) 
$insertCommand.Data=$procs
$sqls.AddCommand($insertCommand)
$sqls.Execute()
[SQLSimple]::Query("SELECT * FROM TestTable where IntValue=382", $connectionString)
#>

<#
$sql = [SQLSimple]::new($connectionString)
$insertCommand = [SQLSimpleCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")
$badName = @"
'); DELETE FROM DBO.USERS; GO --
"@
$insertCommand.AddMappingWithData("Name", $badName, [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 33, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)
$sql.AddCommand($insertCommand)
$sql.Execute()
#>


<#
#Create the delete command and add it (no mapping nor data, just the command as we delete the contents of the entire table)
$sql.AddCommand( [SQLSimpleCommand]::new("DELETE FROM @@OBJECT_NAME@@;") )
#Create the insert command
$insertCommand = [SQLSimpleCommand]::new([SQLCommandTemplate]::Insert)
#This is the same as writing
#$command = [SQLSimpleCommand]::new("INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);")
#Note: To get the inserted ID from Execute() use this template:
#$command.SQLTemplate="INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);"
#Add directly some values 
#First parameter is the SQL Server column name/parameter, second is the name of the property to get the data from, final parameter is the SQL Server data type
$insertCommand.AddMappingWithData("Name", "From SQLSimplePS_First", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 3, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 33.44, [Data.SqlDbType]::Decimal)
#Add the insert command
$sql.AddCommand($insertCommand)
#Execute it
$sql.Execute()
#>


