
$CollectionName = ([System.Uri]$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI).Host.split('.')[-3]
$CompletedByDate = (Get-Date).AddDays(-14).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")

#Will need to set these for local debug
# $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI= ""
# $CollectionName = ""
# $env:SYSTEM_TEAMPROJECTID = ""
# $env:SYSTEM_ACCESSTOKEN = ""
# $env:BUILD_ARTIFACTSTAGINGDIRECTORY=""
#END DEBUG SECTION

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("{0}:{1}" -f $user, $env:SYSTEM_ACCESSTOKEN))

Write-Host $CollectionName
Write-Host $env:SYSTEM_TEAMPROJECTID
Write-Host $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI

try {
    $odataPipelines = "_odata/v3.0-preview/Pipelines?"
    $url = "https://analytics.dev.azure.com/$CollectionName/$env:SYSTEM_TEAMPROJECTID/$odataPipelines"
    Write-Debug $url
    $pipelineResults = Invoke-RestMethod -Uri $url -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) } 
    Write-Host "*******************pipelines*********************************"
    $outputFile = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/pipelines.md"

    "|{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}|" -f "Pipeline", "Type", "Partial Rate", "Cancel Rate", "Success Rate", "Failed Rate", "Run Count", "Avg Duration", "Avg Queue Time", "Avg Run Time", "Analytics URL" | add-content -path $outputFile
    "|--- |--- |---: |---: |---: |---: |---: |---: |---: |---: |--- |" | add-content -path $outputFile
    
    foreach ($pipeline in $pipelineResults.value) {
        
        Write-Host $pipeline.PipelineName
        Write-Host $pipeline.PipelineProcessType    
        $odataPipelineRuns = '_odata/v3.0-preview/PipelineRuns?&$filter=PipelineId%20eq%20' + $pipeline.PipelineId + 'and%20CompletedDate%20gt%20' + $CompletedByDate
        $url = "https://analytics.dev.azure.com/$CollectionName/$env:SYSTEM_TEAMPROJECTID/$odataPipelineRuns"
        Write-Host $url
        $result = Invoke-RestMethod -Uri $url -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) } 
        Write-Host "*******************pipelineRuns*********************************"
        
        if ($result.value.Count -gt 1) {
            $TotalDuration = $result.value | Where-Object { $_.RunOutcome -eq "Succeed" } | Measure-Object -AllStats TotalDurationSeconds
            $QueueDuration = $result.value | Measure-Object -AllStats QueueDurationSeconds 
            $RunDuration = $result.value | Where-Object { $_.RunOutcome -eq "Succeed" } | Measure-Object -AllStats RunDurationSeconds 
            $Succeeded = $result.value | Measure-Object -AllStats SucceededCount
            $PartiallySucceeded = $result.value | Measure-Object -AllStats PartiallySucceededCount
            $Failed = $result.value | Measure-Object -AllStats FailedCount
            $Canceled = $result.value | Measure-Object -AllStats CanceledCount

            $SucceededAverage = ""
            $CanceledAverage = ""
            $FailedAverage = ""
            $PartiallySucceededAverage = ""
            $tsTotalDuration = ""
            $tsQueueDuration = ""
            $tsRunDuration = ""

            if ($Succeeded.Average) {
                $SucceededAverage = "{0:p2}" -f $Succeeded.Average.ToDouble($null)
            }
            
            if ($Canceled.Average) {
                $CanceledAverage = "{0:p2}" -f $Canceled.Average.ToDouble($null)
            }
            
            if ($Failed.Average) {
                $FailedAverage = "{0:p2}" -f $Failed.Average.ToDouble($null)
            }

            if ($PartiallySucceeded.Average) {
                $PartiallySucceededAverage = "{0:p2}" -f $PartiallySucceeded.Average.ToDouble($null)
            }
            

            if ($TotalDuration.Average) {
                $tsTotalDuration = [timespan]::fromseconds($TotalDuration.Average.toInt32($null))
                $tsTotalDuration = ("{0:hh\:mm\:ss}" -f $tsTotalDuration)

            }
           
            if ($QueueDuration.Average) {
                $tsQueueDuration = [timespan]::fromseconds($QueueDuration.Average.toInt32($null))
                $tsQueueDuration = ("{0:hh\:mm\:ss}" -f $tsQueueDuration)
            }

            if ($RunDuration.Average) {
                $tsRunDuration = [timespan]::fromseconds($RunDuration.Average.toInt32($null))
                $tsRunDuration = ("{0:hh\:mm\:ss}" -f $tsRunDuration)
            }


            $PipelineID = $pipeline.PipelineId
            $PipelineName = $pipeline.PipelineName
            $PipelineType = $pipeline.PipelineProcessType
            $PipelineURL = "[$PipelineName]($Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$env:SYSTEM_TEAMPROJECTID/_build?definitionId=$PipelineID&_a=summary)"
            $AnalyticsURL = "[Analytics]($Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$env:SYSTEM_TEAMPROJECTID/_pipeline/analytics/duration?definitionId=$PipelineID&contextType=build)"
            "|{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}|" -f $PipelineURL, $PipelineType, $PartiallySucceededAverage, $CanceledAverage, $SucceededAverage, $FailedAverage, $result.value.Count, $tsTotalDuration, $tsQueueDuration, $tsRunDuration, $AnalyticsURL | add-content -path $outputFile
        }
    }
}
catch {
    Write-Error $_
    Write-Error $_.Exception.Message
}
