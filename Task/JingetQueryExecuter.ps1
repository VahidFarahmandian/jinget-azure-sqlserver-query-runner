
Param
(
    [Parameter(Mandatory = $True)]
    [String] 
    $basePath,
	
	[Parameter(Mandatory = $False)]
    [String]
    $outputPath,

    [Parameter(Mandatory = $True)]
    [String] 
    $instance,

    [Parameter(Mandatory = $True)]
    [String] 
    $authType,

    [Parameter(Mandatory = $False)]
    [String] 
    $dbName,

    [Parameter(Mandatory = $False)]
    [String] 
    $dbUser,

    [Parameter(Mandatory = $False)]
    [String] 
    $dbPassword,

    [Parameter(Mandatory = $False)]
    [Int32] 
    $resultRetentionDays
)

if ($basePath -notmatch '\\$')
{
    $basePath += '\'
}
if($outputPath -eq '')
{
    $outputPath = $basePath
}
elseif ($outputPath -notmatch '\\$')
{
    $outputPath += '\'
}

$sourcePath = $($basePath)+"To Be Executed" 
$destinationpath =  $($basePath)+"Executed"
$resultPath = $($outputPath)+"Results\"
$problematicScriptsPath =  $($basePath)+"Errors"

#remove older files
if( $resultRetentionDays -gt 0){
    Get-ChildItem –Path $resultPath -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays($resultRetentionDays*-1))} | Remove-Item
}

if($dbName -eq '')
{
    $dbName = "master"
}

if(!(Test-Path $sourcePath -ErrorAction Ignore)){
    mkdir $sourcePath
}
if(!(Test-Path $destinationpath -ErrorAction Ignore)){
    mkdir $destinationpath
}
if(!(Test-Path $resultPath -ErrorAction Ignore)){
    mkdir $resultPath
}
if(!(Test-Path $problematicScriptsPath -ErrorAction Ignore)){
    mkdir $problematicScriptsPath
}

Write-Output $problematicScriptsPath

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
