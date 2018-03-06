# SQL Simple for PowerShell (SQLSimplePS) 
# Version 1.4.3
# https://github.com/texhex/2Inv
#
# Copyright (c) 2018 Michael 'Tex' Hex 
# Licensed under the Apache License, Version 2.0. 
#
# To use this classes, add this line as the very first line in your script:
# using module .\SQLSimplePS.psm1
#
#
# ## NOTICE ##
# SQLSimple uses Snapshot Isolation as default isolation level (as it prevents a lot of problems that other isolation levels have). 
# Execute this SQL command in the target database to allow this isolation level:
#
# ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON 
# GO
#
# ## EXAMPLES ##
#
# The following table is used for all examples:
<#

 CREATE TABLE [dbo].[TestTable](
	[ID] [int] IDENTITY(1,1) NOT NULL, [Name] [nvarchar](50) NOT NULL, [IntValue] [int] NOT NULL, [NumericValue] [decimal](5, 2) NOT NULL,
    CONSTRAINT [PK_TestTable] PRIMARY KEY CLUSTERED 
    ( [ID] ASC )
	WITH (IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) 
ON [PRIMARY]
GO

#>
# This is the connection string used by all examples
<#

 $connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLSimpleTest;"

#>
#
#
# ### ONE LINERS ###
<#

#Only returns an array of single values
[SQLSimple]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Second Test', 9, 45.66)", $connectionString)

#Specify transaction isolation level 
[SQLSimple]::Query("SELECT * FROM dbo.TestTable", $connectionString, [System.Data.IsolationLevel]::Serializable)

#Returns a hash table
[SQLSimple]::Query("SELECT * FROM dbo.TestTable", $connectionString)

#Specify transaction isolation level 
[SQLSimple]::Query("SELECT * FROM dbo.TestTable", $connectionString, [System.Data.IsolationLevel]::Serializable))

#>
#
# ### INSERT DATA WITH DELETE FIRST ####
<#

$sqls = [SQLSimple]::new($connectionString)

$sqls.AddCommand("DELETE FROM dbo.TestTable")

$sqls.AddCommand("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Chain Test 1', 11, 11.11);")

$sqls.Execute()

#>
#
# ### INSERT DATA WITH DELETE FIRST AND USING SQLCommandTemplates ####
<#

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

#>
#
# ### INSERT SEVERAL ROWS USING DATA PROPERTY ####
<#

$sqls = [SQLSimple]::new("[dbo].[TestTable]", $connectionString)

$insertCommand = [SQLSimpleCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

#Add the mapping
$insertCommand.AddMapping("Name", "NameProp", [Data.SqlDbType]::NVarChar) 
$insertCommand.AddMapping("IntValue", "MyCount", [Data.SqlDbType]::int) 
$insertCommand.AddMapping("NumericValue", "NumericVal", [Data.SqlDbType]::Decimal) 

#Add the data #1
$myData1 = @{ NameProp = "Chain Test 4"; MyCount = 4; NumericVal = 44.44; }
$insertCommand.AddData($myData1)
#Add the data #2
$myData2 = @{ NameProp = "Chain Test 5"; MyCount = 5; NumericVal = 55.55; }
$insertCommand.AddData($myData2)

#Add the insert command that includes the mapping and the data
$sqls.AddCommand($insertCommand)

$sqls.Execute()

#>
#
# ### QUERY (SELECT) EXAMPLE ###
<#

$sqlSelect = [SQLSimple]::new("[dbo].[TestTable]", $connectionString)

$result=$sqlSelect.Query("SELECT * FROM @@OBJECT_NAME@@;")

#>
#
# ## SELECT EXAMPLE WITH PARAMETERS ###
<#

$sqlSelect = [SQLSimple]::new("[dbo].[TestTable]", $connectionString)

#Define the query with a parameter
$selectCommand=[SQLSimpleCommand]::new("SELECT * FROM @@OBJECT_NAME@@ WHERE NumericValue=@NumericValue")

#We add the mapping and data directly so the parameter @NumericValue is now 12.20
$selectCommand.AddMappingWithData("NumericValue", 12.20, [Data.SqlDbType]::Decimal)

$sqlSelect.AddCommand($selectCommand)

$sqlSelect.Query()

#>
#
#

#This script requires PowerShell 5 because we are using classes
#requires -version 5

#Guard against common code errors
Set-StrictMode -version 2.0

#Terminate script on errors 
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\MPSXM.psm1"


#Base class that holds the object name, the connection string and the commands
class SQLSimple
{
    #PowerShell really needs to support constructor chaining...
    #https://github.com/PowerShell/PowerShell/issues/3820#issuecomment-302750422
    SQLSimple()
    {
        $this.Init()   
    }

    SQLSimple([string] $ConnectionString)
    {
        $this.Init()
        $this.ConnectionString = $ConnectionString
    }

    SQLSimple([string] $Objectname, [string] $ConnectionString)
    {
        $this.Init()
        $this.ObjectName = $Objectname
        $this.ConnectionString = $ConnectionString
    }

    SQLSimple([string] $ConnectionString, [System.Data.IsolationLevel] $IsolationLevel)
    {
        $this.Init()
        $this.ConnectionString = $ConnectionString
        $this.TransactionIsolationLevel = $IsolationLevel
    }

    SQLSimple([string] $Objectname, [string] $ConnectionString, [System.Data.IsolationLevel] $IsolationLevel)
    {
        $this.Init()
        $this.ObjectName = $Objectname
        $this.ConnectionString = $ConnectionString
        $this.TransactionIsolationLevel = $IsolationLevel
    }

    hidden [void] Init() 
    {
        $this.ObjectName = ""
        $this.ConnectionString = ""
        $this.Commands = New-Object System.Collections.ArrayList
        $this.TransactionIsolationLevel = [System.Data.IsolationLevel]::Snapshot
    }


    #Replacement tokens
    hidden static [string] $ObjectNameToken = "@@OBJECT_NAME@@"
    hidden static [string] $ColumnToken = "@@COLUMN@@"
    hidden static [string] $ParameterToken = "@@PARAMETER@@"

    #The SQL object this map applies to - in most cases, this will be a table: "[dbo].[MyTable]"
    [string] $Objectname

    #The connection string used to connect to the database
    [string] $ConnectionString

    #The transaction isolation level we want to use
    #For details, please see this excellent post by Sergey Barskiy: http://www.dotnetspeak.com/data/transaction-isolation-levels-explained-in-details/
    [System.Data.IsolationLevel] $TransactionIsolationLevel

    #An array list of SQLSimpleCommand
    [System.Collections.ArrayList] $Commands
    
    #Just a helper, it's also possible to directly use $sql.Commands.Add($myCommand)
    [void] AddCommand([SQLSimpleCommand] $Command)
    {
        [void] $this.Commands.Add($Command)
    }

    #Helper function that accepts a string
    [void] AddCommand([string] $SQLTemplate)
    {
        [void] $this.Commands.Add([SQLSimpleCommand]::new($SQLTemplate))
    }

    #Creates a command, adds it to the list and returns it
    #I have no idea what the best naming for this function would be:
    #? [SQLSimpleCommand] AddCommandEx([string] $SQLTemplate)
    #? [SQLSimpleCommand] AppendCommand([string] $SQLTemplate)
    #? [SQLSimpleCommand] CreateCommand([string] $SQLTemplate)
    #? [SQLSimpleCommand] AttachCommand([string] $SQLTemplate)
    #? [SQLSimpleCommand] AddCommandAndReturn([string] $SQLTemplate)
    #? [SQLSimpleCommand] AddCommand2([string] $SQLTemplate)
    [SQLSimpleCommand] AddCommandEx([string] $SQLTemplate)
    {
        $command=[SQLSimpleCommand]::new($SQLTemplate)
        [void] $this.Commands.Add($command)
        return $command
    }


    #Validates this SQLSimple is everything is set as planned
    [void] Validate()
    {
        #Objectname can be empty, but not null
        if ( $this.Objectname -eq $null)
        {
            throw "SQLSimple: Objectname is null"
        }

        if ( Test-String -IsNullOrWhiteSpace $this.ConnectionString )
        {
            throw "SQLSimple: ConnectionString is not set"
        }

        if ( $this.Commands -eq $null )
        {
            throw "SQLSimple: Commands is null"
        }
        else
        {
            if ( $this.Commands.Count -lt 1 )
            {
                throw "SQLSimple: No commands defined"
            }

            foreach ($command in $this.Commands)
            {
                $command.Validate()
            }
        }
    }

    static [array] Execute([string] $SQLQuery, [string] $ConnectionString)
    {
        return [SQLSimple]::Execute($SQLQuery, $ConnectionString, [System.Data.IsolationLevel]::Snapshot)
    }

    static [array] Execute([string] $SQLQuery, [string] $ConnectionString, [System.Data.IsolationLevel] $IsolationLevel)
    {
        $sql = [SQLSimple]::new($ConnectionString, $IsolationLevel)
        $sql.AddCommand( [SQLSimpleCommand]::new($SQLQuery) )
        return $sql.Execute()
    }

    static [array] Query([string] $SQLQuery, [string] $ConnectionString)
    {
        return [SQLSimple]::Query($SQLQuery, $ConnectionString, [System.Data.IsolationLevel]::Snapshot)
    }
    
    static [array] Query([string] $SQLQuery, [string] $ConnectionString, [System.Data.IsolationLevel] $IsolationLevel)
    {
        $sql = [SQLSimple]::new($ConnectionString, $IsolationLevel)
        $sql.AddCommand( [SQLSimpleCommand]::new($SQLQuery) )        
        return $sql.Query()
    }
    
    [array] Query()
    {
        #Make sure everything is ready
        $this.Validate()

        #A query only allows a single command and a single data object
        if ( $this.Commands.Count -gt 1 )
        {
            throw "SQLSimple: When using Query() only a single command is allowed"
        }

        return $this.ExecuteSQLInternally($true)
    }

    [array] Execute()
    {
        #Make sure everything is ready
        $this.Validate()

        return $this.ExecuteSQLInternally($false)
    }

    
    hidden [array] ExecuteSQLInternally([bool] $ReturnFullResult)
    {
        $transaction = $null
        $connection = $null
        $sqlCommand = $null
        $reader = $null

        $returnList = new-object System.Collections.ArrayList

        try 
        {
            $connection = New-Object System.Data.SqlClient.SqlConnection
            $connection.ConnectionString = Get-TrimmedString -RemoveDuplicates $this.ConnectionString
                       
            $connection.Open()
            if ($connection.State -ne [Data.ConnectionState]::Open) 
            {
                throw "Unable to open connection to database!"
            }
    
            #We do not care how many rows a command has affected
            $sqlCommand = $connection.CreateCommand()
            $sqlCommand.CommandText = "SET NOCOUNT ON;"
            [void]$sqlCommand.ExecuteNonQuery()             
            $sqlCommand.Dispose()
    
            #Start the transaction - yes, even for SELECTs 
            #"An application can perform actions such as acquiring locks to protect the transaction isolation level of SELECT statements [..]"
            #https://docs.microsoft.com/en-us/sql/t-sql/language-elements/begin-transaction-transact-sql
            $transaction = $connection.BeginTransaction( $this.TransactionIsolationLevel )                

            foreach ($simpleCommand in $this.Commands)
            {
                $sqlCommand = $simpleCommand.Build($this.Objectname)
                
                $sqlCommand.Connection = $connection
                $sqlCommand.Transaction = $transaction

                #Change the sourceData to an array so foreach() and .Count works always
                $sourceData = @()
                $sourceData = ConvertTo-Array $simpleCommand.Data

                if ( $sourceData.Count -lt 1 )
                {
                    #No data available, we just execute the command and be done with it
                    $this.ExecuteCommandAndProcessResults($sqlCommand, $ReturnFullResult, $returnList)                    
                }
                else
                {
                    #Go through each entry in data
                    foreach ($sourceDataEntry in $sourceData)
                    {
                        #Map the SQL parameters to the source objects 
                        foreach ($simpleColumn in $simpleCommand.ColumnMap)
                        {
                            $value = $null

                            if ( Test-IsHashtable $sourceDataEntry)
                            {
                                #Hash table is simple
                                if ( $sourceDataEntry.Contains($simpleColumn.Source) )
                                {
                                    $value = $sourceDataEntry[$simpleColumn.Source]    
                                }
                                else
                                {
                                    throw "Source property [$($simpleColumn.Source)] not found as key in hash table for column [$($simpleColumn.Column)]"
                                }
                            }
                            else
                            {
                                #Access NoteProperty
                                try
                                {
                                    $value = Select-Object -InputObject $sourceDataEntry -ExpandProperty $simpleColumn.Source
                                }
                                catch [System.ArgumentException]
                                {
                                    throw "Source property [$($simpleColumn.Source)] not found in data for column [$($simpleColumn.Column)]"
                                }
                            }                        
                
                            $sqlCommand.Parameters["@$($simpleColumn.Column)"].Value = $value    
                        }
    
                        #Everything is ready, go for it 
                        $this.ExecuteCommandAndProcessResults($sqlCommand, $ReturnFullResult, $returnList)
                    }
                }

                $sqlCommand.Dispose()
                $sqlCommand = $null

                #All data in this SQLSimpleCommand done, next one please
            }
    
          
            #All done, commit transaction
            try
            {
                $transaction.Commit()
                $transaction = $null                    
            }
            catch
            {
                #Our commit has failed. This can happen for many reasons, but one of them is that we have requested 
                #snapshot isolation and the database does not support it. I have no idea how we could detect this case.
                $transaction.Dispose()
                $transaction = $null                    

                if ( $this.TransactionIsolationLevel -eq [System.Data.IsolationLevel]::Snapshot )
                {
                    throw "Commit failed (please make sure the database supports snapshot isolation): $($_.Exception.Message)"    
                }
                else
                {
                    throw "Commit failed: $($_.Exception.Message)"    
                }                
            }
        }
        finally
        {
            #We do not check if reader is null because this triggers the reader
            try
            {
                if ( -not $reader.IsClosed ) { $reader.Close() }                
            }
            catch {}


            if ( $sqlCommand -ne $null )
            {
                try { $sqlCommand.Dispose() } catch {}
            }
            
            if ( $transaction -ne $null)
            {
                if ( $transaction.Connection -ne $null )
                {
                    try { $transaction.Rollback() } catch {}
                }
                
                try { $transaction.Dispose() } catch {}
            }
            
            if ( $connection -ne $null ) 
            {                
                if ( $connection.State -eq [Data.ConnectionState]::Open )
                {
                    try { $connection.Close() } catch {}
                }                
            }
        }    

        return $returnList.ToArray()            
    }

    hidden [void] ExecuteCommandAndProcessResults([System.Data.SqlClient.SqlCommand] $Command, [bool] $FullResults, [System.Collections.ArrayList] $ReturnList)
    {
        if ( $FullResults )
        {
            $reader = $Command.ExecuteReader()

            try
            {
                if ($reader.HasRows)
                {
                    while ( $reader.Read() )
                    {
                        #Ordered dictionary will do
                        $row = [Ordered]@{}
    
                        For ($curField = 0; $curField -lt $reader.FieldCount; $curField++)
                        {
                            $row.Add( $reader.GetName($curField), $reader.GetValue($curField) )
                        }
    
                        $ReturnList.Add($row)
                    }
                }
            }
            finally
            {
                #Always close the reader
                $reader.Close()
            }
        }
        else
        {
            #No Full results, use ExecuteScalar()
            $val = $Command.ExecuteScalar()
            if ( $val -ne $null)
            {
                $returnList.Add($val)      
            }
        }

    }


}



enum SQLCommandTemplate
{   
    #DELETE FROM @@OBJECT_NAME@@ WHERE @@COLUMN@@=@@PARAMETER@@;
    Delete = 1
    
    #INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);
    Insert = 2
    
    #UPDATE @@OBJECT_NAME@@ SET @@COLUMN@@=@@PARAMETER@@ OUTPUT Inserted.ID;
    Update = 4
}

#A single SQL command
class SQLSimpleCommand
{
    SQLSimpleCommand()
    {
        $this.ColumnMap = New-Object System.Collections.ArrayList
        $this.Data = New-Object System.Collections.ArrayList
    }

    SQLSimpleCommand([string] $SQLTemplate)
    {
        $this.ColumnMap = New-Object System.Collections.ArrayList
        $this.Data = New-Object System.Collections.ArrayList
        $this.SQLTemplate = $SQLTemplate
    }

    SQLSimpleCommand([SQLCommandTemplate] $Template)
    {
        $this.ColumnMap = New-Object System.Collections.ArrayList
        $this.Data = New-Object System.Collections.ArrayList

        switch ($Template)
        {
            Delete
            {
                $this.SQLTemplate = "DELETE FROM @@OBJECT_NAME@@ WHERE @@COLUMN@@=@@PARAMETER@@;"
            }

            Insert
            {
                $this.SQLTemplate = "INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);"
            }

            Update
            {
                $this.SQLTemplate = "UPDATE @@OBJECT_NAME@@ SET @@COLUMN@@=@@PARAMETER@@ OUTPUT Inserted.ID;"

            }
        }
    }


    #The SQL text to be executed. Can contain replacement tokens @@OBJECT_NAME@@, @@COLUMN@@ or @@PARAMETER@@
    [string] $SQLTemplate

    #An array list of SQLSimpleColumn that map the data at runtime to the matching SQL column
    [System.Collections.ArrayList] $ColumnMap

    #It's also possible to directly use $command.ColumnMap.Add($sqlping)
    [void] AddMapping([SQLSimpleColumn] $Column)
    {
        [void] $this.ColumnMap.Add($Column)
    }

    #This helper function will make the source code a little bit easier to read
    [void] AddMapping([string] $Columnname, [string] $Source, [Data.SqlDbType] $Type)
    {
        $this.AddMapping( [SQLSimpleColumn]::new($Columnname, $Source, $Type) )
    }

    #Quick access function that adds a column mapping and the value for it directly
    #This will only apply to the first entry of Data and will NOT work if the object in Data[0] already exists and is not a hash table
    [void] AddMappingWithData([string] $Columnname, $Data, [Data.SqlDbType] $Type)
    {
        #First add the mapping
        $column = [SQLSimpleColumn]::new($Columnname, $Columnname, $Type)
        $this.AddMapping($column)

        #Then the data 
        if ( $this.Data.Count -eq 0 )
        {
            $temp = @{}
            $this.AddData($temp)
        }

        $this.Data[0].Add($Columnname, $Data)
    }

    #An array list of the data that should be used when executing this command. 
    #Each entry must contain an object that holds the data. For example, if you want to insert a row with "NAME" and "AGE", do not add
    #those two properties directly to this array list, instead create a hash table, add those properties to that hash table and then add
    #the hash table to this array list so $Data.Count will be 1
    [System.Collections.ArrayList] $Data

    #It's also possible to directly use $command.Data.Add($myData)
    [void] AddData($Data)
    {
        [void] $this.Data.Add($Data)
    }

    [void] Validate()
    {
        #if ( [string]::IsNullOrWhiteSpace($this.SQLTemplate) )
        if ( Test-String -IsNullOrWhiteSpace $this.SQLTemplate )
        {
            throw "SQLSimpleCommand: SQLTemplate is not set"
        }

        if ( $this.ColumnMap -eq $null )
        {
            #ColumnMap can be empty, but not $null
            throw "SQLSimpleCommand: ColumMap is null"
        }

        if ( $this.ColumnMap.Count -gt 0 )
        {
            foreach ( $sqlCol in $this.ColumnMap )
            {
                $sqlCol.Validate()
            }
        }

        if ( $this.Data -eq $null )
        {
            #Data can be empty, but not $null
            throw "SQLSimpleCommand: Data is null"
        }

        #Check if the SQLTemplate contains @@COLUMN or @@PARAMETER replacement values but ColumnMap and/or Data is empty
        if ($this.SQLTemplate.Contains([SQLSimple]::ColumnToken) -or
            $this.SQLTemplate.Contains([SQLSimple]::ParameterToken))
        {                
            #Replacement values found. Check if BOTH ColumnMap and Data is set
            if (($this.ColumnMap.Count -eq 0) -or
                ($this.Data.Count -eq 0))
            {
                throw "SQLSimpleCommand: SQLTemplate contains replacement values, but either ColumnMap and/or Data is empty"
            }
        }

    }

    hidden [System.Data.SqlClient.SqlCommand] Build([string] $Objectname)
    {
        $command = new-object System.Data.SqlClient.SqlCommand
        $command.CommandText = $this.GenerateSQLText($Objectname) 

        #Build SQL Parameters and name them @Column
        foreach ($sqlColumn in $this.ColumnMap)
        {
            $param = New-Object Data.SqlClient.SqlParameter("@$($sqlColumn.Column)", $sqlColumn.Type)
            $command.Parameters.Add($param)
        }

        return $command
    }


    hidden [string] GenerateSQLText([string] $Objectname)
    {
        $sb = new-object System.Text.StringBuilder

        $sb.Append($this.SQLTemplate)

        if ($this.SQLTemplate.Contains([SQLSimple]::ObjectNameToken))
        {
            #Check if the objectname is set
            if ( $objectName.Length -gt 0 )
            {
                $sb.Replace([SQLSimple]::ObjectNameToken, $objectName)
            }
            else
            {
                throw "Found replacement token $([SQLSimple]::ObjectNameToken) but Objectname is empty"
            }
        }

        $sqlPart = new-object System.Text.StringBuilder
        
        #Check if the SQLTemplate contains @@COLUMN@@ and start the replacement if this is the case
        if ($this.SQLTemplate.Contains([SQLSimple]::ColumnToken))
        {
            foreach ($sqlColumn in $this.ColumnMap)
            {
                $sqlPart.Append($sqlColumn.Column)
                $sqlPart.Append(",")
            }
            $sb.Replace([SQLSimple]::ColumnToken, $sqlPart.ToString().TrimEnd(","))
        }

        #Reuse it to build the parameter names (@Column), which will later on take the data values
        $sqlPart.Clear();

        #Check if the SQLTemplate contains @@PARAMETER@@ and start the replacement if this is the case
        if ($this.SQLTemplate.Contains([SQLSimple]::ParameterToken))
        {
            foreach ($sqlColumn in $this.ColumnMap)
            {
                $sqlPart.Append("@")
                $sqlPart.Append($sqlColumn.Column)
                $sqlPart.Append(",")
            }
            $sb.Replace([SQLSimple]::ParameterToken, $sqlPart.ToString().TrimEnd(","));
        }

        #Ensure the command ends with a ;
        $finalSQL = $sb.ToString()
        if ( -not ($finalSQL.EndsWith(";")) ) 
        {
            $finalSQL += ";"
        }

        return $finalSQL;
    }
       
}



#A single mapping between a SQL server column and the name of the property on the data object
class SQLSimpleColumn
{
    SQLSimpleColumn()
    {
        $this.Column = $null
        $this.Source = $null
        $this.Type = [Data.SQLDBType]::NVarChar
    }

    SQLSimpleColumn([string] $Column, [string] $Source)
    {
        $this.Column = $Column
        $this.Source = $Source
        $this.Type = [Data.SQLDBType]::NVarChar
    }

    SQLSimpleColumn([string] $Column, [string] $Source, [Data.SqlDbType] $Type)
    {
        $this.Column = $Column
        $this.Source = $Source
        $this.Type = $Type
    }
    
    #The SQL object column name. It will also be used as parameter name. 
    [string] $Column

    #The source property of the data object that maps to this column during runtime
    [string] $Source

    #The SQL Server data type of this column 
    [Data.SQLDBType] $Type 

    [void] Validate()
    {
        if ( Test-String -IsNullOrWhiteSpace $this.Column )
        {
            throw "SQLSimpleColumn: Column is not set"
        }

        if ( Test-String -IsNullOrWhiteSpace $this.Source)
        {
            throw "SQLSimpleColumn: Source is not set"
        }

        if ( $this.Type -eq $null )
        {
            throw "SQLSimpleColumn: Type is not set"
        }
        
    }

}


