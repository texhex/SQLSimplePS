# SQL Simple for PowerShell (SQLSimplePS) 
# Version 1.2.4
# https://github.com/texhex/2Inv
#
# Copyright (c) 2018 Michael 'Tex' Hex 
# Licensed under the Apache License, Version 2.0. 
#
# To use this classes, add this line as the very first line in your script:
# using module .\SQLSimplePS.psm1
#
#
# SQL Simple is an attempt to make handling SQL with PowerShell easier and more secure. If you already use parameterized queries 
# and have working transaction handling, this class is not for you.
#
# It works by creating a SQLMap object that contains the object name it applies to (e.g. a table “dbo.TestTable”) and 
# the connection string to reach the database.
#
# You then define SQLMapCommands that hold the SQL text to run against the database. The property SQLTemplate has the SQL statement
# you want to execute. You can set this property to something like “INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) VALUES(@@PARAMETER@@);”. 
# These special @@ values are replacement values that can also be used but are not required. In fact, for some cases it is not 
# possible to use the @@COLUMN@@ or @@PARAMETER@@ replacement since the replacement would generate invalid SQL.
#
# You then add one or more SQLMapColumns to the command that contains the name of the column this map applies to, the property 
# name where the data from for this column comes from and the SQL Server column data type (NVarChar, VarChar, int, bit etc.)
#
# For example, you might want to add the running processes to a SQL table, but only want to add the number of handles and the 
# process name to this table. You define the table as EXEName (NVarChar) and NumHandles (int).
#
# In this case, you would add two SQLMapColumns. The first would be “EXEName” (SQL column name), “ProcessName” (the property name
# of the object Get-Process returns) and “NVarChar” (data type). The second would be “NumHandles” (SQL Server), “Handles” (property)
# and “Int”.
#
# Your SQLMapCommand would have the SQLTemplate of “INSERT INTO @@OBJECT_NAME@@(EXEName, NumHandles) VALUES(@EXEName, @NumHandles);”
# The classes resuse the column name (EXEName, NumHandler) as parameter names (@EXEName, @NumHandles). During runtime, the data from
# the source property will be set as parameter. 
#
# During runtime, you would do one foreach() loop through the return from Get-Process, add each entry to the Data array list of 
# the SQLMapCommand. When done, call Execute() on the SQLMap object. 
#
# ## NOTICE ##
# SQLSimple uses Snapshot Isolation as isolation level (as it prevents a lot of problems that other isolation levels have). 
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

 $connectionString="Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

#>
#
# ### INSERT SOME DATA WITH DELETE FIRST ####
<#

$map = [SQLMap]::new("[dbo].[TestTable]", $connectionString)

#Create the delete command and add it (no mapping nor data, just the command as we delete the contents of the entire table)
$map.AddCommand( [SQLMapCommand]::new("DELETE FROM @@OBJECT_NAME@@;") )

#Create the insert command
$insertCommand = [SQLMapCommand]::new([SQLCommandTemplate]::Insert)
#This is the same as writing
#$command = [SQLMapCommand]::new("INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);")
#Note: To get the inserted ID from Execute() use this template:
#$command.SQLTemplate="INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);"

#Add directly some values 
#First parameter is the SQL Server column name/parameter, second is the name of the property to get the data from, final parameter is the SQL Server data type
$insertCommand.AddMappingWithData("Name", "From SQLSimplePS_First", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 3, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 33.44, [Data.SqlDbType]::Decimal)

#Add the insert command
$map.AddCommand($insertCommand)

#Execute it
$map.Execute()

#>
#
#
# ### INSERT SEVERAL ROWS USING DATA PROPERTY ####
<#

$map = [SQLMap]::new("[dbo].[TestTable]", $connectionString)

#Create the delete command and add it (no mapping nor data, just the command as we delete the contents of the entire table)
$map.AddCommand( [SQLMapCommand]::new("DELETE FROM @@OBJECT_NAME@@;") )

#We want to get the inserted ID, so we use Output Inserted.ID
$insertCommand = [SQLMapCommand]::new("INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);")

#Add the mapping
$insertCommand.AddMapping( [SQLMapColumn]::new("Name", "NameProp", [Data.SqlDbType]::NVarChar) ) 
$insertCommand.AddMapping( [SQLMapColumn]::new("IntValue", "MyCount", [Data.SqlDbType]::int) ) 
$insertCommand.AddMapping( [SQLMapColumn]::new("NumericValue", "NumericVal", [Data.SqlDbType]::Decimal) ) 

#Add the data 
$myData = [PSCustomObject]@{
    NameProp   = "From SQLSimplePS_First";
    MyCount = 1;
    NumericVal = 12.2;
}
$insertCommand.AddData($myData)

$myData2 = [PSCustomObject]@{
    NameProp   = "From SQLSimplePS_Second";
    MyCount = 2;
    NumericVal = 42;
}
$insertCommand.AddData($myData2)

#Add the insert command that includes the mapping and the data
$map.AddCommand($insertCommand)

#Execute this (will return an array with IDs)
$map.Execute()

#>
#
#
# ### QUERY (SELECT) EXAMPLE ###
<#

$mapSelect = [SQLMap]::new("[dbo].[TestTable]", $connectionString)
$result=$mapSelect.Query("SELECT * FROM @@OBJECT_NAME@@;")

#>
#
#
# ## SELECT EXAMPLE WITH PARAMETERS ###
<#

$mapSelect = [SQLMap]::new("[dbo].[TestTable]", $connectionString)

#Define the query with a parameter
$selectCommand=[SQLMapCommand]::new("SELECT * FROM @@OBJECT_NAME@@ WHERE NumericValue=@NumericValue")

#We add the mapping and data directly so the parameter @NumericValue is now 12.20
$selectCommand.AddMappingWithData("NumericValue", 12.20, [Data.SqlDbType]::Decimal)

$mapSelect.AddCommand($selectCommand)

$mapSelect.Query()

#>
#
#

#This script requires PowerShell 5.1 because we are using classes
#requires -version 5

#Guard against common code errors
Set-StrictMode -version 2.0

#Terminate script on errors 
$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot\MPSXM.psm1"


#Base class that holds the object name, the connection string and the commands
class SQLMap
{
    #PowerShell really needs to support constructor chaining...

    SQLMap()
    {
        $this.ObjectName = ""
        $this.ConnectionString = ""
        $this.Commands = New-Object System.Collections.ArrayList
        $this.TransactionIsolationLevel = [System.Data.IsolationLevel]::Snapshot
    }

    SQLMap([string] $ConnectionString)
    {
        $this.ObjectName = ""
        $this.ConnectionString = $ConnectionString
        $this.Commands = New-Object System.Collections.ArrayList
        $this.TransactionIsolationLevel = [System.Data.IsolationLevel]::Snapshot
    }

    SQLMap([string] $Objectname, [string] $ConnectionString)
    {
        $this.ObjectName = $Objectname
        $this.ConnectionString = $ConnectionString
        $this.Commands = New-Object System.Collections.ArrayList
        $this.TransactionIsolationLevel = [System.Data.IsolationLevel]::Snapshot
    }

    SQLMap([string] $ConnectionString, [System.Data.IsolationLevel] $IsolationLevel)
    {
        $this.ObjectName = ""
        $this.ConnectionString = $ConnectionString
        $this.Commands = New-Object System.Collections.ArrayList
        $this.TransactionIsolationLevel = $IsolationLevel
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

    #An array list of SQLMapCommand
    [System.Collections.ArrayList] $Commands
    
    #Just a helper, it's also possible to directly use $map.Commands.Add($myCommand)
    [void] AddCommand([SQLMapCommand] $Command)
    {
        [void] $this.Commands.Add($Command)
    }


    #Validates this SQLMap is everything is set as planned
    [void] Validate()
    {

        #Objectname can be empty, but not null
        if ( $this.Objectname -eq $null)
        {
            throw "SQLMap: Objectname is null"
        }

        if ( Test-String -IsNullOrWhiteSpace $this.ConnectionString )
        {
            throw "SQLMap: ConnectionString is not set"
        }

        if ( $this.Commands -eq $null )
        {
            throw "SQLMap: Commands is null"
        }
        else
        {
            if ( $this.Commands.Count -lt 1 )
            {
                throw "SQLMap: No commands defined"
            }

            foreach ($command in $this.Commands)
            {
                $command.Validate()
            }
        }
    }

    static [array] Execute([string] $SQLQuery, [string] $ConnectionString)
    {
        return [SQLMap]::Execute($SQLQuery, $ConnectionString, [System.Data.IsolationLevel]::Snapshot)
    }

    static [array] Execute([string] $SQLQuery, [string] $ConnectionString, [System.Data.IsolationLevel] $IsolationLevel)
    {
        $map = [SQLMap]::new($ConnectionString, $IsolationLevel)
        $map.AddCommand( [SQLMapCommand]::new($SQLQuery) )
        return $map.Execute()
    }

    static [array] Query([string] $SQLQuery, [string] $ConnectionString)
    {
        return [SQLMap]::Query($SQLQuery, $ConnectionString, [System.Data.IsolationLevel]::Snapshot)
    }
    
    static [array] Query([string] $SQLQuery, [string] $ConnectionString, [System.Data.IsolationLevel] $IsolationLevel)
    {
        $map = [SQLMap]::new($ConnectionString, $IsolationLevel)
        $map.AddCommand( [SQLMapCommand]::new($SQLQuery) )        
        return $map.Query()
    }

    
    #[System.Data.IsolationLevel]::Snapshot

    [array] Query()
    {
        #Make sure everything is ready
        $this.Validate()

        #A query only allows a single command and a single data object
        if ( $this.Commands.Count -gt 1 )
        {
            throw "SQLMap: When using Query() only a single command is allowed"
        }

        return $this.ExecuteSQLInternally($true)
    }

    [array] Query([string] $SQLQuery)
    {
        $this.AddCommand( [SQLMapCommand]::new($SQLQuery) )

        return $this.Query()
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

            foreach ($mapCommand in $this.Commands)
            {
                $sqlCommand = $mapCommand.Build($this.Objectname)
                
                $sqlCommand.Connection = $connection
                $sqlCommand.Transaction = $transaction

                #Change the sourceData to an array so foreach() and .Count works always
                $sourceData = @()
                $sourceData = ConvertTo-Array $mapCommand.Data

                if ( $sourceData.Count -lt 1 )
                {
                    #No data available, we just execute the command and be done with it
                    
                    if ( $ReturnFullResult )
                    {
                        $reader = $sqlCommand.ExecuteReader()
                        $this.ConvertReaderToHashtable($reader, $returnList)
                    }
                    else
                    {
                        #Execute it and return the first value of the first result                        
                        $val = $sqlCommand.ExecuteScalar()
                        $returnList.Add($val)      
                        $sqlCommand.Dispose()                                              
                    }
                    
                }
                else
                {
                    #Go through each entry in data
                    foreach ($sourceDataEntry in $sourceData)
                    {
                        #Map the SQL parameters to the source objects 
                        foreach ($mapColumn in $mapCommand.ColumnMap)
                        {
                            $value = $null

                            if ( Test-IsHashtable $sourceDataEntry)
                            {
                                #Hash table is simple
                                if ( $sourceDataEntry.Contains($mapColumn.Source) )
                                {
                                    $value = $sourceDataEntry[$mapColumn.Source]    
                                }
                                else
                                {
                                    throw "Source property [$($mapColumn.Source)] not found in data for column [$($mapColumn.Column)]"
                                }
                            }
                            else
                            {
                                #Access NoteProperty
                                try
                                {
                                    $value = Select-Object -InputObject $sourceDataEntry -ExpandProperty $mapColumn.Source
                                }
                                catch [System.ArgumentException]
                                {
                                    throw "Source property [$($mapColumn.Source)] not found in data for column [$($mapColumn.Column)]"
                                }
                            }                        
                
                            $sqlCommand.Parameters["@$($mapColumn.Column)"].Value = $value    
                        }
    
                        if ( $ReturnFullResult )
                        {
                            $reader = $sqlCommand.ExecuteReader()
                            $this.ConvertReaderToHashtable($reader, $returnList)                            
                        }
                        else
                        {
                            #Execute it and return the first value of the first result                        
                            $val = $sqlCommand.ExecuteScalar()
                            $returnList.Add($val)                                                    
                        }

                        $sqlCommand.Dispose()
                        $sqlCommand = $null
                    }
                }

                #All data in this SQLMapCommand done, next one please
            }
    
          
            #All done, commit transaction
            try
            {
                $transaction.Commit()
                $transaction = $null                    
            }
            catch
            {
                #OK, so our commit has failed. This can happen for many reasons, but one of them is
                #that we have requested snapshot isolation and the database does not support it.
                #I'm unable to detect this special case. 
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
                
                $transaction.Dispose()          
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

    
    hidden [void] ConvertReaderToHashtable([System.Data.SqlClient.SqlDataReader] $Reader, [System.Collections.ArrayList] $ReturnList )
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

        #Always close the reader
        $reader.Close()
    }

}



enum SQLCommandTemplate
{   
    #DELETE FROM @@OBJECT_NAME@@ WHERE @@COLUMN@@=@@PARAMETER@@;
    Delete = 1
    
    #INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);
    Insert = 2
    
    #UPDATE @@OBJECT_NAME@@ SET @@COLUMN@@=@@PARAMETER@@
    Update = 4
}


#A single SQL command
class SQLMapCommand
{
    SQLMapCommand()
    {
        $this.ColumnMap = New-Object System.Collections.ArrayList
        $this.Data = New-Object System.Collections.ArrayList
    }

    SQLMapCommand([string] $SQLTemplate)
    {
        $this.ColumnMap = New-Object System.Collections.ArrayList
        $this.Data = New-Object System.Collections.ArrayList
        $this.SQLTemplate = $SQLTemplate
    }

    SQLMapCommand([SQLCommandTemplate] $Template)
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
                $this.SQLTemplate = "INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) VALUES(@@PARAMETER@@);"
                #To get the inserted ID use this template:
                #$this.SQLTemplate="INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);"
            }

            Update
            {
                $this.SQLTemplate = "UPDATE @@OBJECT_NAME@@ SET @@COLUMN@@=@@PARAMETER@@;"

            }
        }
    }


    #The SQL text to be executed. Can contain replacement tokens @@OBJECT_NAME@@, @@COLUMN@@ or @@PARAMETER@@
    [string] $SQLTemplate

    #An array list of SQLMapColumn that map the data at runtime to the matching SQL column
    [System.Collections.ArrayList] $ColumnMap

    #It's also possible to directly use $command.ColumnMap.Add($mapping)
    [void] AddMapping([SQLMapColumn] $Column)
    {
        [void] $this.ColumnMap.Add($Column)
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
        

    #Quick access function that adds a column mapping and the value for it directly
    #This will only apply to the first entry of Data and will NOT work if the object in Data[0] already exists and is not a hash table
    [void] AddMappingWithData([string] $Columnname, $Data, [Data.SqlDbType] $Type)
    {
        #First add the mapping
        $column = new-object SQLMapColumn -ArgumentList $Columnname, $Columnname, $Type
        $this.AddMapping($column)

        #Then the data 
        if ( $this.Data.Count -eq 0 )
        {
            $temp = @{}
            $this.AddData($temp)
        }

        $this.Data[0].Add($Columnname, $Data)
    }


    [void] Validate()
    {
        #if ( [string]::IsNullOrWhiteSpace($this.SQLTemplate) )
        if ( Test-String -IsNullOrWhiteSpace $this.SQLTemplate )
        {
            throw "SQLMapCommand: SQLTemplate is not set"
        }

        if ( $this.ColumnMap -eq $null )
        {
            #ColumnMap can be empty, but not $null
            throw "SQLMapCommand: ColumMap is null"
        }

        if ( $this.ColumnMap.Count -gt 0 )
        {
            foreach ( $mapCol in $this.ColumnMap )
            {
                $mapCol.Validate()
            }
        }

        if ( $this.Data -eq $null )
        {
            #Data can be empty, but not $null
            throw "SQLMapCommand: Data is null"
        }

        #Check if the SQLTemplate contains @@COLUMN or @@PARAMETER replacement values but ColumnMap and/or Data is empty
        if ( $this.SQLTemplate.Contains([SQLMap]::ColumnToken) -or
            $this.SQLTemplate.Contains([SQLMap]::ParameterToken)  )
        {                
            #Replacement values found. Check if BOTH ColumnMap and Data is set
            if ( ($this.ColumnMap.Count -eq 0) -or
                ($this.Data.Count -eq 0) )
            {
                throw "SQLMapCommand: SQLTemplate contains replacement values, but either ColumnMap and/or Data is empty"
            }
        }

    }

    hidden [System.Data.SqlClient.SqlCommand] Build([string] $Objectname)
    {
        $command = new-object System.Data.SqlClient.SqlCommand
        $command.CommandText = $this.GenerateSQLText($Objectname) 

        #Build SQL Parameters and name them @Column
        foreach ($mapColumn in $this.ColumnMap)
        {
            $param = New-Object Data.SqlClient.SqlParameter("@$($mapColumn.Column)", $mapColumn.Type)
            $command.Parameters.Add($param)
        }

        return $command
    }


    hidden [string] GenerateSQLText([string] $Objectname)
    {
        $sb = new-object System.Text.StringBuilder

        $sb.Append($this.SQLTemplate)

        if ($this.SQLTemplate.Contains([SQLMap]::ObjectNameToken))
        {
            #Check if the objectname is set
            if ( $objectName.Length -gt 0 )
            {
                $sb.Replace([SQLMap]::ObjectNameToken, $objectName)
            }
            else
            {
                throw "Found replacement token $([SQLMap]::ObjectNameToken) but Objectname is empty"
            }
        }


        $sqlPart = new-object System.Text.StringBuilder
        
        #Check if the SQLTemplate contains @@COLUMN@@ and start the replacement if it is there
        if ($this.SQLTemplate.Contains([SQLMap]::ColumnToken))
        {
            foreach ($mapColumn in $this.ColumnMap)
            {
                $sqlPart.Append($mapColumn.Column)
                $sqlPart.Append(",")
            }
            $sb.Replace([SQLMap]::ColumnToken, $sqlPart.ToString().TrimEnd(","))
        }

        #Reuse it to build the parameter names (@Column), which will later on take the data values
        $sqlPart.Clear();

        #Check if the SQLTemplate contains @@PARAMETER@@ and start the replacement if this is the case
        if ($this.SQLTemplate.Contains([SQLMap]::ParameterToken))
        {
            foreach ($mapColumn in $this.ColumnMap)
            {
                $sqlPart.Append("@")
                $sqlPart.Append($mapColumn.Column)
                $sqlPart.Append(",")
            }
            $sb.Replace([SQLMap]::ParameterToken, $sqlPart.ToString().TrimEnd(","));
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
class SQLMapColumn
{
    SQLMapColumn()
    {
        $this.Column = $null
        $this.Source = $null
        $this.Type = [Data.SQLDBType]::NVarChar
    }

    SQLMapColumn([string] $Column, [string] $Source, [Data.SqlDbType] $Type )
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

        if ( [string]::IsNullOrWhiteSpace($this.Column) )        
        {
            throw "SQLMapColumn: Column is not set"
        }

        if ( [string]::IsNullOrWhiteSpace($this.Source) )
        {
            throw "SQLMapColumn: Source is not set"
        }

        if ( $this.Type -eq $null )
        {
            throw "SQLMapColumn: Type is not set"
        }
        
    }

}



#Create the tables we are using for our tests

#using module .\SQLSimplePS.psm1

$connectionString = "Server=.\SQLEXPRESS; Database=TestDB; Connect Timeout=15; Integrated Security=True; Application Name=SQLMapTest;"

#[SQLMap]::Execute("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES('Second Test', 9, 45.66)", $connectionString)

#[SQLMap]::Query("SELECT * FROM dbo.TestTable", $connectionString, [System.Data.IsolationLevel]::Serializable)


$map = [SQLMap]::new($connectionString)

$insertCommand = [SQLMapCommand]::new("INSERT INTO dbo.TestTable(Name, IntValue, NumericValue) OUTPUT Inserted.ID VALUES(@Name, @IntValue, @NumericValue);")

$badName=@"
'); DELETE FROM DBO.USERS; GO --
"@

$insertCommand.AddMappingWithData("Name", $badName, [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 33, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 22.22, [Data.SqlDbType]::Decimal)

$map.AddCommand($insertCommand)

$map.Execute()



<#
$map = [SQLMap]::new("[dbo].[TestTable]", $connectionString)

#Create the delete command and add it (no mapping nor data, just the command as we delete the contents of the entire table)
$map.AddCommand( [SQLMapCommand]::new("DELETE FROM @@OBJECT_NAME@@;") )

#Create the insert command
$insertCommand = [SQLMapCommand]::new([SQLCommandTemplate]::Insert)
#This is the same as writing
#$command = [SQLMapCommand]::new("INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);")
#Note: To get the inserted ID from Execute() use this template:
#$command.SQLTemplate="INSERT INTO @@OBJECT_NAME@@(@@COLUMN@@) OUTPUT Inserted.ID VALUES(@@PARAMETER@@);"

#Add directly some values 
#First parameter is the SQL Server column name/parameter, second is the name of the property to get the data from, final parameter is the SQL Server data type
$insertCommand.AddMappingWithData("Name", "From SQLSimplePS_First", [Data.SqlDbType]::NVarChar)
$insertCommand.AddMappingWithData("IntValue", 3, [Data.SqlDbType]::Int)
$insertCommand.AddMappingWithData("NumericValue", 33.44, [Data.SqlDbType]::Decimal)

#Add the insert command
$map.AddCommand($insertCommand)

#Execute it
$map.Execute()
#>




