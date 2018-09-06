# 10619 "SU (Aeroflot)" SH14000037 SU13812 Jerusalem "47 Navi St. Jerusalem" 050654987321 050987654321 05065487987 Y

#if logs directory does not exist, create it
if( -Not (Test-Path C:\priority\bin.95\spix_api\logs\) ){
    mkdir logs
}

#generating the log file names for current day
$date = date -Format u
$date = ($date.Substring(0,10)).Replace('-','')
$date = $date.Replace('-','')
$errorLog = 'C:\priority\bin.95\spix_api\logs\'+$date+'-Error.log'
$runLog = 'C:\priority\bin.95\spix_api\logs\'+$date+'-Run.log'

#this function logs any errors and stops the script
function errorLog{
    $date = date -Format G #current timestamp
    $date = $date.Substring($date.Length-11,11)
    $errorString = '' + $date + ' -> ' + $args[0] #build the string to be logged
    echo $errorString #write to command-line
    echo "$date -> Error occured. Exiting.." >> $runLog #write to run log.
    echo $errorString >> $errorLog #write to log file
    exit
}

#this function logs normal activity
function log{
    $date = date -Format G #current timestamp
    $date = $date.Substring($date.Length-11,11)
    $logString = '' + $date + ' -> ' + $args[0] #build the string to be logged
    echo $logString #write to command-line
    echo $logString >> $runLog #write to log file
}

#this function reads the config file and stores entries in global variables
function readConfigFile{
    #test if config file exists; otherwise write to log
    if(Test-Path C:\priority\bin.95\spix_api\config.cfg){
        #if config file exists, check if all needed entries are supplied
        $configFileContents = Get-Content C:\priority\bin.95\spix_api\config.cfg
        #check if all config file entries are supplied
        if($configFileContents.Length -ne 7){
            errorLog 'Config file incomplete.'
        }
        try{
            #store config file entries in global variables
            $global:serviceUrl = $configFileContents[0].Substring(11,$configFileContents[0].Length-11)
            $global:user = $configFileContents[1].Substring(5,$configFileContents[1].Length-5)
            $global:password = $configFileContents[2].Substring(9,$configFileContents[2].Length-9)
            $global:db_host = $configFileContents[3].Substring(8,$configFileContents[3].Length-8)
            $global:db_user = $configFileContents[4].Substring(8,$configFileContents[4].Length-8)
            $global:db_pass = $configFileContents[5].Substring(8,$configFileContents[5].Length-8)
            $global:db_name = $configFileContents[6].Substring(8,$configFileContents[6].Length-8)
        }
        catch{
            errorLog 'Error parsing config file.'
        }
    }
    else{
        errorLog 'Config file not found.'
    }
}

#this function creates the POST request and sets a global variable flag depending on status code
#only one parameter: the JSON for POST
function createRequest{
    $secpassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($user, $secpassword)
    try{
        $webRequest = Invoke-WebRequest -Uri $serviceUrl -Credential $credential -Method POST -Body $args[0]   #([System.Text.Encoding]::UTF8.GetBytes($args[0])) 
		#$webRequest = Invoke-RestMethod -Method Post -Uri $serviceUrl -Credential $credential -Body ( $args[0]) #-Header @{"X-ApiKey"=$apiKey}   ConvertTo-Json
        $statusCode = [int]$webRequest.StatusCode 
		log $webRequest
        if($statusCode -eq 200){
            $global:responseFlag=0
        }
        if($statusCode -ne 200){
            $global:responseFlag=1
        }
    }
    catch{
        errorLog $_.Exception.Message
    }
}

#this function creates a global variable containing the SQL Connection
function defineConnection{
    $global:connection = New-Object System.Data.SQLClient.SQLConnection
    $connectionString = "Server="+$db_host+";Database="+$db_name+";User ID ="+$db_user+";Password="+$db_pass+";"
    $global:connection.ConnectionString = $connectionString
}
#run query and store result in $Address variable
function runQuery{
    try{
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $connection
    $SQLQuery = "SELECT ELIT_FULLADDRESS FROM DOCUMENTS WHERE DOC = "+ $doc
    $Command.CommandText = $SQLQuery

    $Connection.Open()
    $reader = $Command.ExecuteReader()
    $reader.Read()
    $global:Address = [System.Text.Encoding]::GetEncoding("UTF-16");

    $global:Address = $reader["ELIT_FULLADDRESS"]
    $reader.Close()
    $Connection.Close()
    }
    catch{
        $string = "Error -> "+$Error[0].Exception
		log $string
        exit
    }
}
#this functions updates the database based on the response from WebRequest
function databaseUpdate{
    try{
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $connection
    if($responseFlag -eq 0){
        $SQLQuery = "UPDATE DOCUMENTS SET ELMG_SPIX=5 WHERE DOC="+$doc
    }
    else{
        $SQLQuery = "UPDATE DOCUMENTS SET ELMG_SPIX=6 WHERE DOC="+$doc
    }
    $Command.CommandText = $SQLQuery

    $Connection.Open()
    $Command.ExecuteReader()
    $Connection.Close()
    }
    catch{
        errorLog $Error[0].Exception
    }
}

#check if number of arguments is 10
if($args.Length -ne 10){
    errorLog 'The required numbers of arguments was not supplied.'
}

log 'Received 10 arguments. Parsing the config file.' 

#call to the function that reads the config file and stores entries in global variables
readConfigFile

log 'Config file parsed. Converting arguments to JSON.'


log 'Pull address from sql bd '
defineConnection
$global:doc = ''+$args[0]
runQuery

#create JSON out of args array for POST
#$params = [PsCustomObject]@{
$params = @{
    DOC=''+$args[0]
    CDES=''+$args[1]
    DOCNO=''+$args[2]
    BOOKNUM=''+$args[3]
    ELIT_CITYNAME=''+$args[4]
    ELIT_FULLADDRESS=''+ $Address   #$args[5]
    ELYD_CELL=''+$args[6]
    #ELYD_CELL2=''+$args[7]
    #ELYD_CELL=''+$args[8]
    IS_ENGLISH=''+$args[9]
}

$postParams = $params #| ConvertTo-JSON

log 'POST JSON created. Creating request.'
log $postParams
#call to the function that does the POST to the webservice with JSON data as param and store the response
createRequest $postParams

log 'Request done. Defining connection to database.'

#call to the function that creates the connection object
defineConnection

log 'Connection defined. Running update statement.'

#call to the function that updates the database according to response.
databaseUpdate

log 'Update done. Work is done.'

