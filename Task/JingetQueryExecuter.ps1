
Param
(
    [Parameter(Mandatory = $True)]
    [String] 
    $basePath,
	
    [Parameter(Mandatory = $True)]
    [String] 
    $instance,

    [Parameter(Mandatory = $True)]
    [String] 
    $authType,

    [Parameter(Mandatory = $False)]
    [String] 
    $dbName = "master",

    [Parameter(Mandatory = $False)]
    [String] 
    $dbUser,

    [Parameter(Mandatory = $False)]
    [String] 
    $dbPassword,

    [Parameter(Mandatory = $False)]
    [Int32] 
    $resultRetentionDays,

    [Parameter(Mandatory = $True)]
    [String] 
    $environment
)

if($environment -eq "staging"){
    $sourcePath = Join-Path $($basePath) "To Be Executed" 
    $destinationpath = Join-Path $($basePath) "To Production"
    $resultPath = Join-Path $($basePath) "Staging Results/"
    $problematicScriptsPath = Join-Path  $($basePath) "Staging Errors"
}
else{
    $sourcePath = Join-Path $($basePath) "To Production" 
    $destinationpath = Join-Path $($basePath) "Production Executed"
    $resultPath = Join-Path $($basePath) "Production Results/"
    $problematicScriptsPath = Join-Path $($basePath) "Production Errors"
}

#remove older files
if( $resultRetentionDays -gt 0){
    Get-ChildItem –Path $resultPath -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays($resultRetentionDays*-1) -and $_.Extension -ne '.md')} | Remove-Item
}


if(!(Test-Path $sourcePath -ErrorAction Ignore)){
    mkdir $sourcePath
}
if(!(Test-Path $destinationpath -ErrorAction Ignore)){
    mkdir $destinationpath
}
if(!(Test-Path $resultPath -ErrorAction Ignore)){
	New-Item -Path "$($resultPath)README.md" -ItemType File -Force
}
if(!(Test-Path $problematicScriptsPath -ErrorAction Ignore)){
    mkdir $problematicScriptsPath
}

Import-Module SQLPS

foreach ($filename in get-childitem -path $sourcePath -filter "*.sql")
{
    $Error.Clear()

    try {
        if($authType -eq "sql"){
            $queryResult = Invoke-Sqlcmd -OutputAs DataSet -ErrorAction Stop -InputFile $filename.FullName -Database $dbName -ServerInstance $instance -Username $dbUser -Password $dbPassword
        }    
        else{
            $queryResult = Invoke-Sqlcmd -OutputAs DataSet -ErrorAction Stop -InputFile $filename.FullName -Database $dbName -ServerInstance $instance 
        }
        
        for ($i = 0; $i -lt $queryResult.Tables.Count; ++$i) {
           $resultFile = "$($resultPath)$($filename.BaseName)_Query#$($i+1).csv"
           $queryResult.Tables[$i] | Export-Csv -NoTypeInformation -Path $resultFile -Encoding UTF8 -Append
        }
        
        Move-Item -Path $filename.FullName -Destination $destinationpath
    }

    catch [Microsoft.SqlServer.Management.PowerShell.SqlPowerShellSqlExecutionException] {
        $resultFile = "$($resultPath)$($filename.BaseName)_Error.txt"
        
        for ($i = 0; $i -lt $Error.Count; ++$i) {
            
            if($Error[$i].CategoryInfo.Activity -eq "Invoke-Sqlcmd")
            {
                $Error[$i].Exception | Out-File -FilePath $resultFile -Append -Encoding UTF8
            }
        }
        Move-Item -Path $filename.FullName -Destination $problematicScriptsPath
    }
    Write-Output "$($filename.FullName) EXECUTED. Check Results folder for possible error(s) or output(s)"    
} 
