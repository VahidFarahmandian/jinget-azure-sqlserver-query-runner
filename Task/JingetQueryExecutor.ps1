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
    $elasticPassword,

    [Parameter(Mandatory = $True)]
    [String] 
    $autoCommitEnabled='false',

    [Parameter(Mandatory = $False)]
    [String] 
    $autoCommitBranchName='master'
)

function Commit{
    Param()
    if([System.Convert]::ToBoolean($autoCommitEnabled) -eq $True){
		Set-Location -Path $basePath
        $env:GIT_REDIRECT_STDERR = '2>&1'
        git add --all
        git commit -m "Committed by Jinget Query Executor"
        git pull origin $autoCommitBranchName
        git push origin head:$autoCommitBranchName
    }
}

function LogToElastic{
    Param($content, $status, $currentPath)

     if([System.Convert]::ToBoolean($elasticLogEnabled) -eq $True){
        
        $data = @{
            Request = @{
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
            GitInfo = @{
               CommitId = $env:Build_SourceVersion
               Branch = $env:Build_SourceBranchName
            }    
        }

        $indexName = 'jinget.query.executer'
        $elasticUrl = $elasticUrl+'/'+$indexName
        $headers = @{
            'Authorization' = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($elasticUsername):$($elasticPassword)"))
        }
        try{
            Invoke-RestMethod -Method Get -Headers $headers -Uri $elasticUrl
            Write-Output "Check if index exists"
        }
        catch{
            if($_.Exception.Response.StatusCode.value__ -ge 300){
                Write-Output "Index doest not exist"
                Invoke-RestMethod -Method Put -Headers $headers -Uri $elasticUrl
                Write-Output "Index created"
            }
        }

        $elasticUrl = $elasticUrl+'/_doc'
        $jsonData = ConvertTo-Json $data -Compress
        
        Invoke-RestMethod -Method Post -Headers $headers -Uri $elasticUrl -Body $jsonData -ContentType 'application/json; charset=utf-8' 
        Write-Output "Operation logged in index successfully"
    }
}

function RemoveOldFiles{
    Param()
    if( $resultRetentionDays -gt 0){
        Get-ChildItem –Path $resultPath -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays($resultRetentionDays*-1) -and $_.Extension -ne '.md')} | Remove-Item
    }
}

function CreateDirectories{
    Param()
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
}

function ExecuteQuery{
    Param()
    
    $Error.Clear()
	$jsonResult = ''
    $requestDateTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff")
	
    try {
		
		$hasJingetInjected = Select-String -Path $filename.FullName -Pattern "/*Injected By Jinget*/ SELECT @@ROWCOUNT AS EffectedRowsCount /**/" -SimpleMatch -Quiet
		if($hasJingetInjected -eq $False){
			Add-Content $filename.FullName "`n GO `n /*Injected By Jinget*/ SELECT @@ROWCOUNT AS EffectedRowsCount /**/"
		}
		
        if($authType -eq "sql"){
            $queryResult = Invoke-Sqlcmd -OutputAs DataSet -ErrorAction Stop -InputFile $filename.FullName -Database $dbName -ServerInstance $instance -Username $dbUser -Password $dbPassword
        }    
        else{
            $queryResult = Invoke-Sqlcmd -OutputAs DataSet -ErrorAction Stop -InputFile $filename.FullName -Database $dbName -ServerInstance $instance 
        }
        
		for ($i = 0; $i -lt $queryResult.Tables.Count; ++$i) {
			$resultFile = "$($resultPath)$($filename.BaseName)_Query#$($i+1).csv"
			$queryResult.Tables[$i] | Export-Csv -NoTypeInformation -Path $resultFile -Encoding UTF8 -Append

			$jsonResult = ($queryResult.Tables[$i] | select $queryResult.Tables[$i].Columns.ColumnName ) | ConvertTo-Json -Compress
		}
		
		LogToElastic $jsonResult 'Success'
        Move-Item -Path $filename.FullName -Destination $destinationpath
		Write-Output "$($filename.FullName) EXECUTED. Check 'Results' folder for output(s)"    
    }

    catch [Microsoft.SqlServer.Management.PowerShell.SqlPowerShellSqlExecutionException] {
        
        $resultFile = "$($resultPath)$($filename.BaseName)_Error.txt"
        
        for ($i = 0; $i -lt $Error.Count; ++$i) {
            
            if($Error[$i].CategoryInfo.Activity -eq "Invoke-Sqlcmd")
            {
                $Error[$i].Exception | Out-File -FilePath $resultFile -Append -Encoding UTF8
                
                $jsonResult = ConvertTo-Json $Error[$i].Exception -Compress
 
                LogToElastic $jsonResult 'Failed'
            }
        }
        Move-Item -Path $filename.FullName -Destination $problematicScriptsPath
		$hasError = $True
		Write-Error "Executing $($filename.BaseName) Failed. Check 'Errors' folder for error(s)"    
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

RemoveOldFiles

CreateDirectories

Import-Module SQLPS

$hasError = $False

foreach ($filename in get-childitem -path $sourcePath -filter "*.sql")
{
    ExecuteQuery
}
Commit
if($hasError -eq $True){
	exit(1)
}
