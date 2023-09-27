# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing permissions and limitations under the
# License.

Function Get-RandomAlphanumericString {
    [CmdletBinding()]
    Param (
        [int] $length = 6
    )
    Begin{
    }
    Process{
        Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | % {[char]$_}) )
    }    
}
$user = 'admin'
$pass = ''
$jenkinsHost = ''
$agentHost = ''
$agentPort = '50000'
$DefaultUsername = 'jenkins'
$DefaultPassword = ''

$pair = "$($user):$($pass)"

Write-Verbose 'Now configuring IE'

# Navigate to the domains folder in the registry
Set-Location 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-Location ZoneMap\Domains

# Create a new folder with the website name
New-Item $jenkinsHost/ -Force # website part without https
Set-Location $jenkinsHost/
New-ItemProperty . -Name https -Value 2 -Type DWORD -Force

Write-Host 'Site added Successfully'
Start-Sleep -s 2

Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\1' -Name 2500 -Value '3'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\2' -Name 2500 -Value '3'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' -Name 2500 -Value '3'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\4' -Name 2500 -Value '3'

Write-Host 'IE protection mode turned Off successfully'
Start-Sleep -s 2

# 3. Bring down security level for all zones

# Set Level 0 for low 
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\1' -Name 1A10 -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\2' -Name 1A10 -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3' -Name 1A10 -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\4' -Name 1A10 -Value 0

$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

$basicAuthValue = "Basic $encodedCreds"

$Headers = @{ 
    Authorization = $basicAuthValue
}

# Download required jar files from Jenkins Server
Invoke-WebRequest -URI http://$jenkinsHost/jnlpJars/jenkins-cli.jar -OutFile C:\Users\jenkins\Downloads\jenkins-cli.jar -Headers $Headers 
Invoke-WebRequest -URI http://$jenkinsHost/jnlpJars/agent.jar -OutFile C:\Users\jenkins\Downloads\agent.jar -Headers $Headers

$NODE_NAME=(Invoke-RestMethod `
        -Headers @{'Metadata-Flavor' = 'Google'} `
        -Uri "http://metadata.google.internal/computeMetadata/v1/instance/name")

$config=@"
<?xml version="1.1" encoding="UTF-8"?>
<slave>
  <name>$NODE_NAME</name>
  <description>jenkins agent node</description>
  <remoteFS>C:\</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>NORMAL</mode>
  <label>windows-gcp</label>
  <createSnapshot>false</createSnapshot>
  <oneShot>false</oneShot>
  <ignoreProxy>false</ignoreProxy>
  <javaExecPath>java</javaExecPath>
  <launchTimeout>300000</launchTimeout>
  <launcher class="hudson.slaves.JNLPLauncher">
  <tunnel>$agentHost`:$agentPort</tunnel>
  </launcher>
</slave>
"@

$config | Out-File C:\Users\jenkins\Documents\config.xml

$agentStart = @"

# java -jar C:\Users\jenkins\Downloads\swarm-client.jar -url http://$jenkinsHost/ -description "Dynamic Windows Node" -labels "Windows-Node" -name "$NODE_NAME" -username $user -password $pass
cat C:\Users\jenkins\Documents\config.xml | java -jar C:\Users\jenkins\Downloads\jenkins-cli.jar -s http://$jenkinsHost/ -auth $pair create-node $NODE_NAME

`$SECRET=echo `'println jenkins.model.Jenkins.instance.nodesObject.getNode(`"$NODE_NAME`")?.computer?.jnlpMac`' | java -jar C:\Users\jenkins\Downloads\jenkins-cli.jar -s http://$jenkinsHost/ -auth $pair groovy =
echo `$SECRET

java -jar C:\Users\jenkins\Downloads\agent.jar -jnlpUrl http://$jenkinsHost/computer/$NODE_NAME/jenkins-agent.jnlp -auth $pair -secret `$SECRET
"@

$agentStart | Out-File C:\Users\jenkins\Documents\start-jenkins-agent.ps1

$hostname = hostname 
# Remove RDP Certificate Check
reg add "HKEY_CURRENT_USER\Software\Microsoft\Terminal Server Client" /v "AuthenticationLevelOverride" /t "REG_DWORD" /d 0 /f

cmdkey /add:$hostname /user:$DefaultUsername /pass:$DefaultPassword
mstsc /v:$hostname /f 
