# 1. Cấu hình RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 -Force
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "SecurityLayer" -Value 0 -Force

netsh advfirewall firewall delete rule name="RDP-Tailscale"
netsh advfirewall firewall add rule name="RDP-Tailscale" dir=in action=allow protocol=TCP localport=3389
Restart-Service -Name TermService -Force

# 2. Tạo User RDP
$charSet = @{
    Upper   = [char[]](65..90)
    Lower   = [char[]](97..122)
    Number  = [char[]](48..57)
    Special = ([char[]](33..47) + [char[]](58..64) + [char[]](91..96) + [char[]](123..126))
}
$rawPassword = @()
$rawPassword += $charSet.Upper | Get-Random -Count 4
$rawPassword += $charSet.Lower | Get-Random -Count 4
$rawPassword += $charSet.Number | Get-Random -Count 4
$rawPassword += $charSet.Special | Get-Random -Count 4
$password = -join ($rawPassword | Sort-Object { Get-Random })
$securePass = ConvertTo-SecureString $password -AsPlainText -Force

New-LocalUser -Name "RDP" -Password $securePass -AccountNeverExpires
Add-LocalGroupMember -Group "Administrators" -Member "RDP"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "RDP"

# 3. Cài đặt Tailscale (Dùng Choco cho nhanh và chuẩn)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
choco install tailscale -y

# 4. Kết nối Tailscale
$tsExe = Join-Path ${env:ProgramFiles} "Tailscale\tailscale.exe"
& $tsExe up --authkey=$env:TAILSCALE_KEY --hostname="gh-runner-$env:GITHUB_RUN_ID"

$tsIP = $null
$retries = 0
while (-not $tsIP -and $retries -lt 10) {
    $tsIP = & $tsExe ip -4
    Start-Sleep -Seconds 5
    $retries++
}

# 5. Hiển thị thông tin kết nối
Clear-Host
Write-Host "==========================================" -ForegroundColor Green
Write-Host " TAILSCALE IP : $tsIP" -ForegroundColor Yellow
Write-Host " USERNAME     : RDP" -ForegroundColor Yellow
Write-Host " PASSWORD     : $password" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Green

# 6. Giữ runner hoạt động
while ($true) {
    Start-Sleep -Seconds 300
}
