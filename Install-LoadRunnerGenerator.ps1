$servers = (
'WIN-JF92RFAR2OE'
)

$VCx86Source = "C:\Users\Merto\Downloads\VC_redist.x86.exe"
$VCx64Source = "C:\Users\Merto\Downloads\VC_redist.x64.exe"
$ndpSource = "C:\Users\Merto\Downloads\ndp48-x86-x64-allos-enu.exe"
$lrgSource = ""

$VCx86Destination = "C:\Temp\VC_redist.x86.exe"
$VCx64Destination = "C:\Temp\VC_redist.x64.exe"
$ndpDestination = "C:\Temp\ndp48-x86-x64-allos-enu.exe"
$lrgDestination = ""

foreach ($server in $servers)
{
	"Connecting to $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	$mySession = New-PSSession $server -Credential (Get-Credential)
	
	"Copying installers to $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	Copy-Item -ToSession $mySession $VCx86Source -Destination $VCx86Destination
	Copy-Item -ToSession $mySession $VCx64Source -Destination $VCx64Destination
	Copy-Item -ToSession $mySession $ndpSource -Destination $ndpDestination
	
	"Installing Microsoft Visual C++ Redistributable Lib x86 on $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	Invoke-Command -Session $mySession -ScriptBlock {Start-Process "$Using:VCx86Destination" -ArgumentList " /install /quiet /norestart" -Wait}
	
	"Installing Microsoft Visual C++ Redistributable Lib x64 on $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	Invoke-Command -Session $mySession -ScriptBlock {Start-Process "$Using:VCx64Destination" -ArgumentList " /install /quiet /norestart" -Wait}
	
	"Installing .NET Framework 4.8 on $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	Invoke-Command -Session $mySession -ScriptBlock {Start-Process "$Using:ndpDestination" -ArgumentList "/q /norestart" -Wait}

	"Restarting $server in 60 seconds" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	Invoke-Command -Session $mySession -ScriptBlock {Start-Process "shutdown.exe" -ArgumentList "/r /t 60"}
		
	"Closing Connection to $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	$mySession | Remove-PSSession
	
	"Waiting 240 seconds before continuing" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	Start-Sleep(240)
	
	Function PSSessionWait {
		DO{Sleep -s 30}UNTIL(test-connection $server)
		DO{$session = New-PSSession $server -Credential (Get-Credential)}UNTIL($session)
		write-output $session
	}
	
	"Connecting to $server again" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	$mySession = PSSessionWait
	
	"Installing LoadRunner Generator on $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	Invoke-Command -Session $mySession -ScriptBlock {Start-Process "<Installation_disk>\lrunner\<your_language_folder>\setup.exe" -ArgumentList "/s REBOOT_IF_NEED=1 IMPROVEMENTPROGRAM=0" -Wait}
	"Install complete. $server should be rebooting" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	
	"Closing Connection to $server" | Tee-Object -FilePath "C:\Temp\LoadRunner_Install.log" -Append | Write-Host
	$mySession | Remove-PSSession
	
}