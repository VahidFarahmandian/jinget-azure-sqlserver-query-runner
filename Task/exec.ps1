
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
    $dbUser,

    [Parameter(Mandatory = $False)]
    [String] 
    $dbPassword
)

if ($basePath -notmatch '\\$')
{
    $basePath += '\'
}

$sourcePath = $($basePath)+"To Be Executed" 
$resultPath = $($basePath)+"Results\"
$destinationpath =  $($basePath)+"Executed"

foreach ($filename in get-childitem -path $sourcePath -filter "*.sql")
{
    $resultFile = "$($resultPath)$($filename.BaseName)_RESULT.txt"

    if(Test-Path $resultFile -ErrorAction Ignore){
        Remove-Item $resultFile -ErrorAction Ignore
    }

    if($authType -eq "sql"){
        sqlcmd -S $instance -U $dbUser -P $dbPassword -i $filename.fullname -o $resultFile      
    }    
    else{
        sqlcmd -S $instance -E -i $filename.fullname -o $resultFile
    }
    
    Move-Item -Path $filename.FullName -Destination $destinationpath
    echo "$($filename.FullName) EXECUTED. Check Results folder for possible error(s) or output(s)"    
} 
