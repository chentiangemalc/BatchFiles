@echo off
Rem pingPCs by malcolm mccaffery - pings all PCs in a text file and logs results to CSV
REM enabled delayed expansion so we can change variables during batch file execution
SETLOCAL ENABLEDELAYEDEXPANSION

Rem set the maximum number of runs...
SET MAXRUNS=5

REM the output CSV file
SET OUTPUTFILE=PC_LOG.csv

REM set input file, which is a list of computer names in an ASCII text file, each computer name on a new line
SET INPUTFILE=computers.txt

REM create the header row for the CSV file
echo Computer Name,IP Address,Ping Status,SMB Hostname,SMB Domain,SMB Name,SMB OS,SMB DateTime,SMB Host Match,Date Time > "%OUTPUTFILE%"

echo Reading computer list from %INPUTFILE%
echo Saving log to %OUTPUTFILE%
FOR /F %%i IN (%INPUTFILE%) DO (    
  echo Pinging %%i...
  ping %%i > "%temp%\ping.txt"
 
  IF !ERRORLEVEL! EQU 0 (
    REM machine is pingable!
    SET result=SUCCESS
 
    REM we filter by 'ping statistics' to get IP because it's easy to process,
    REM whether IPv6 or IPv4 it's consistent across legacy and lates MS OSes
    REM dummy delims \ as we don't want it separating any of the output
    FOR /F "delims=\" %%j IN ('type ^"%temp%\ping.txt^" ^| find ^"Ping statistics^"') DO (
      SET IPAddress=%%j
      SET IPAddress=!IPAddress:~20,-1!
      echo SUCCESS ... !IPAddress!
    )
  ) ELSE (
    REM machine is not pingable!
    SET RESULT=FAILED
   
    REM Assume guilty until proven innocent
    SET IPAddress=NOT FOUND
    REM did we get IP, but machine not online?
    type "%temp%\ping.txt" | find "Request timed out."
    IF !ERRORLEVEL! EQU 0 (
      FOR /F "delims=\" %%j IN ('type ^"%temp%\ping.txt^" ^| find ^"Ping statistics^"') DO (
        SET IPAddress=%%j
        SET IPAddress=!IPAddress:~20,-1!
        echo FAILED ... !IPAddress!
      )
    ) ELSE (
      echo FAILED ... NOT FOUND
    )
  )

echo Scanning %%i using NMap...
REM nmap -p 445 -Pn -script=smb-os-discovery %%i > "%temp%\nmap.txt"
echo Scan complete.
SET NMAP_OS=Not Detected
SET NMAP_NAME=Not Detected
SET NMAP_DATETIME=Not Detected
SET NMAP_DOMAIN=Not Detected
SET NMAP_HOSTNAME=Not Detected

FOR /F "tokens=1,2* delims=:" %%j IN ('type ^"%temp%\nmap.txt^"') DO (

REM We use !VALUE:~1! to get rid of leading space
SET VALUE=%%k
IF "%%j" EQU "|   OS" SET NMAP_OS=!VALUE:~1!
IF "%%j" EQU "|   Name" SET NMAP_NAME=!VALUE:~1!
IF "%%j" EQU "|_  System time" SET NMAP_DATETIME=!VALUE:~1!:%%l

)

FOR /F "tokens=1,2 delims=\" %%j IN ('echo !NMAP_NAME!') DO (
  IF "%%j" NEQ "" (
    SET NMAP_DOMAIN=%%j
    SET NMAP_HOSTNAME=%%k
  )
)

IF /I !NMAP_HOSTNAME! EQU %%i (
   SET NMAP_MATCH=TRUE
) ELSE (
   SET NMAP_MATCH=FALSE
)

  echo %%i,!IPAddress!,!result!,!NMAP_HOSTNAME!,!NMAP_DOMAIN!,!NMAP_NAME!,!NMAP_OS!,!NMAP_DATETIME,!NMAP_MATCH!,%DATE%%TIME% >> "%OUTPUTFILE%"
)
 
SET COUNTER=0

:REPEAT

SET /A COUNTER=!COUNTER!+1

echo Completed Cycle #!COUNTER!. Output in "%OUTPUTFILE%"
IF !COUNTER! GEQ !MAXRUNS! GOTO :EOF

Rem Allows for conditional operations in batch processing.
IF EXIST "%INPUTFILE%.csv" DEL "%INPUTFILE%.csv"
copy "%OUTPUTFILE%" "%INPUTFILE%.csv" /y
IF EXIST "%OUTPUTFILE%.tmp" DEL "%OUTPUTFILE%.tmp"
Rem Allows for conditional operations in batch processing.
FOR /F "delims=, TOKENS=1,2,3,4,5,6,7,8,9,10" %%i IN (%INPUTFILE%.csv) DO (    
  Rem only retry failed machines...
  SET RETRY=FALSE
 
  Rem if ping failed last time, retry
  IF "%%k" EQU "FAILED" SET RETRY=TRUE
 
  Rem if nmap match successed last time, then don't retry
  IF "%%q" EQU "TRUE" SET RETRY=FALSE
 
  Rem if nmap match failed last time, retry
  IF "%%q" EQU "FALSE" SET RETRY=TRUE
 
  IF "!RETRY!" EQU "TRUE" (
    Rem Allows for conditional operations in batch processing.
    echo Pinging %%i...
    ping %%i > "%temp%\ping.txt"
   
    IF !ERRORLEVEL! EQU 0 (
      REM machine is pingable!
      SET result=SUCCESS
   
      REM we filter by 'ping statistics' to get IP because it's easy to process,
      REM whether IPv6 or IPv4 it's consistent across legacy and lates MS OSes
      REM dummy delims \ as we don't want it separating any of the output
      REM May need to change ,-1 to ,-2 on XP pinging IPv4 machines to remove trailing :
      FOR /F "delims=\" %%x IN ('type ^"%temp%\ping.txt^" ^| find ^"Ping statistics^"') DO (
        SET IPAddress=%%x
        SET IPAddress=!IPAddress:~20,-1!
        echo SUCCESS ... !IPAddress!
      )
    ) ELSE (
      REM machine is not pingable!
      SET RESULT=FAILED
     
      REM Assume guilty until proven innocent
      SET IPAddress=NOT FOUND
 
      REM did we get IP, but machine not online?
      type "%temp%\ping.txt" | find "Request timed out."
      IF !ERRORLEVEL! EQU 0 (
        FOR /F "delims=\" %%x IN ('type ^"%temp%\ping.txt^" ^| find ^"Ping statistics^"') DO (
          SET IPAddress=%%x
          SET IPAddress=!IPAddress:~20,-1!
          echo FAILED ... !IPAddress!
        )
      ) ELSE (
        echo FAILED ... NOT FOUND
      )
    )
 

echo Scanning %%i using NMap...
REM nmap -p 445 -Pn -script=smb-os-discovery %%i > "%temp%\nmap.txt"
echo Scan complete.
SET NMAP_OS=Not Detected
SET NMAP_NAME=Not Detected
SET NMAP_DATETIME=Not Detected
SET NMAP_DOMAIN=Not Detected
SET NMAP_HOSTNAME=Not Detected

FOR /F "tokens=1,2* delims=:" %%x IN ('type ^"%temp%\nmap.txt^"') DO (

REM We use !VALUE:~1! to get rid of leading space
SET VALUE=%%y
IF "%%x" EQU "|   OS" SET NMAP_OS=!VALUE:~1!
IF "%%x" EQU "|   Name" SET NMAP_NAME=!VALUE:~1!
IF "%%x" EQU "|_  System time" SET NMAP_DATETIME=!VALUE:~1!:%%z

)

FOR /F "tokens=1,2 delims=\" %%x IN ('echo !NMAP_NAME!') DO (
  IF "%%x" NEQ "" (
    SET NMAP_DOMAIN=%%x
    SET NMAP_HOSTNAME=%%y
  )
)

IF /I !NMAP_HOSTNAME! EQU %%i (
   SET NMAP_MATCH=TRUE
) ELSE (
   SET NMAP_MATCH=FALSE
)

  echo %%i,!IPAddress!,!result!,!NMAP_HOSTNAME!,!NMAP_DOMAIN!,!NMAP_NAME!,!NMAP_OS!,!NMAP_DATETIME,!NMAP_MATCH!,%DATE%%TIME% >> "%OUTPUTFILE%.tmp"
  ) ELSE (
    echo %%i was SUCCESSFUL in previous test
    echo %%i,%%j,%%k,%%l,%%m,%%n,%%o,%%p,%%q,%%r >> "%OUTPUTFILE%.tmp"
  )
)

IF EXIST %OUTPUTFILE% del %OUTPUTFILE%
rename %OUTPUTFILE%.tmp %OUTPUTFILE%

GOTO :REPEAT