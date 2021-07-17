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
    $environment,

    [Parameter(Mandatory = $True)]
    [String] 
    $elasticLogEnabled='false',

    [Parameter(Mandatory = $False)]
    [String] 
    $elasticUrl="",

    [Parameter(Mandatory = $False)]
    [String] 
    $elasticUsername,

    [Parameter(Mandatory = $False)]
    [String] 
    $elasticPassword
)

function LogToElastic{
    Param($requestId, $content, $status, $currentPath)

    if($elasticLogEnabled -eq 'true'){
        
        $data = @{
            Request = @{
                Id = $requestId
                FileName = $filename.FullName
                DateTime = $requestDateTime
                Environment = $environment
            }
            Response = @{
                Content = $content
                Status = $status
                DateTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff")
            }
            DbOptions = @{
                Instance = $instance
                Database = $dbName
                Username = $dbuser
                AuthenticationType = $authType
            }    
        }

        $indexName = 'jinget.query.executer'
        $elasticUrl = $elasticUrl+'/'+$indexName
        $headers = @{
            'Authorization' = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($elasticUsername):$($elasticPassword)"))
        }
        try{
            Invoke-RestMethod -Method Get -Headers $headers -Uri $elasticUrl
        }
        catch{
            if($_.Exception.Response.StatusCode.value__ -ge 300){
                Invoke-RestMethod -Method Put -Headers $headers -Uri $elasticUrl
            }
        }

        $elasticUrl = $elasticUrl+'/_doc'
        $jsonData = ConvertTo-Json $data -Compress
        
        Invoke-RestMethod -Method Post -Headers $headers -Uri $elasticUrl -Body $jsonData -ContentType 'application/json; charset=utf-8' 
    }
}

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
    $requestId = New-Guid

    $Error.Clear()

    $requestDateTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff")

    try {
        if($authType -eq "sql"){
            $queryResult = Invoke-Sqlcmd -OutputAs DataSet -ErrorAction Stop -InputFile $filename.FullName -Database $dbName -ServerInstance $instance -Username $dbUser -Password $dbPassword
        }    
        else{
            $queryResult = Invoke-Sqlcmd -OutputAs DataSet -ErrorAction Stop -InputFile $filename.FullName -Database $dbName -ServerInstance $instance 
        }
        
        $jsonResult = ''

        for ($i = 0; $i -lt $queryResult.Tables.Count; ++$i) {
           $resultFile = "$($resultPath)$($filename.BaseName)_Query#$($i+1).csv"
           $queryResult.Tables[$i] | Export-Csv -NoTypeInformation -Path $resultFile -Encoding UTF8 -Append

           $jsonResult = ($queryResult.Tables[$i] | select $queryResult.Tables[$i].Columns.ColumnName ) | ConvertTo-Json -Compress

           LogToElastic $requestId $jsonResult 'Success'

        }
        
        Move-Item -Path $filename.FullName -Destination $destinationpath
    }

    catch [Microsoft.SqlServer.Management.PowerShell.SqlPowerShellSqlExecutionException] {
        $resultFile = "$($resultPath)$($filename.BaseName)_Error.txt"
        
        for ($i = 0; $i -lt $Error.Count; ++$i) {
            
            if($Error[$i].CategoryInfo.Activity -eq "Invoke-Sqlcmd")
            {
                $Error[$i].Exception | Out-File -FilePath $resultFile -Append -Encoding UTF8
                
                $jsonResult = ConvertTo-Json $Error[$i].Exception -Compress
 
                LogToElastic $requestId $jsonResult 'Failed'
            }
        }
        Move-Item -Path $filename.FullName -Destination $problematicScriptsPath
    }
    Write-Output "$($filename.FullName) EXECUTED. Check Results folder for possible error(s) or output(s)"    
} 