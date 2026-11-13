param(
  [Parameter(Mandatory = $true)][string]$HtmlPath,
  [Parameter(Mandatory = $true)][string]$DataPath,
  [Parameter(Mandatory = $true)][string]$GhPath,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$serverPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'server-weekly-summary.ps1')).Path
$logDirectory = Join-Path $PSScriptRoot '.log'
$statePath = Join-Path $logDirectory 'weekly-summary-server.json'
$errorLogPath = Join-Path $logDirectory ("weekly-summary-{0}-{1}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID)
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Write-FailureLog([string]$message) {
  Add-Content -LiteralPath $errorLogPath -Encoding UTF8 -Value ("{0} {1}" -f (Get-Date -Format 'o'), $message)
}

function Remove-PreviousServer {
  if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return }
  try {
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    # 壊れた記録ではプロセスを終了せず、記録だけ破棄する。
    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    return
  }
  if ($state.scriptPath -eq $serverPath -and $state.pid -match '^[1-9][0-9]*$') {
    $previous = Get-Process -Id ([int]$state.pid) -ErrorAction SilentlyContinue
    $sameStartTime = $false
    if ($null -ne $previous) {
      try { $sameStartTime = [string]$previous.StartTime.ToUniversalTime().Ticks -eq [string]$state.startTimeUtcTicks }
      catch { $sameStartTime = $false }
    }
    if ($sameStartTime) {
      Stop-Process -Id $previous.Id -Force
      $stopDeadline = (Get-Date).AddSeconds(5)
      do {
        $previous.Refresh()
        if ($previous.HasExited) { break }
        Start-Sleep -Milliseconds 100
      } while ((Get-Date) -lt $stopDeadline)
      if (-not $previous.HasExited) {
        throw "Previous report server (PID $($previous.Id)) did not stop."
      }
    }
  }
  Remove-Item -LiteralPath $statePath -Force
}

function Get-AvailablePort {
  $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  try {
    $probe.Start()
    return ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
  } finally {
    $probe.Stop()
  }
}

function Test-Health([int]$port) {
  $request = [System.Net.WebRequest]::Create("http://127.0.0.1:$port/api/health")
  $request.Timeout = 500
  try {
    $response = $request.GetResponse()
    try { return ([int]$response.StatusCode -eq 204) }
    finally { $response.Close() }
  } catch { return $false }
}

function Save-ServerState($process, [int]$port) {
  $state = @{
    pid = $process.Id
    startTimeUtcTicks = [string]$process.StartTime.ToUniversalTime().Ticks
    scriptPath = $serverPath
    port = $port
  } | ConvertTo-Json -Compress
  $temporaryPath = "$statePath.tmp"
  [System.IO.File]::WriteAllText($temporaryPath, $state, [System.Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $temporaryPath -Destination $statePath -Force
}

try {
  $launchStartedAt = Get-Date
  $HtmlPath = (Resolve-Path -LiteralPath $HtmlPath).Path
  $DataPath = (Resolve-Path -LiteralPath $DataPath).Path
  $GhPath = (Resolve-Path -LiteralPath $GhPath).Path
  Remove-PreviousServer
  $powershellPath = Join-Path $PSHOME 'powershell.exe'
  $ready = $false
  for ($attempt = 0; $attempt -lt 3 -and -not $ready; $attempt++) {
    $port = Get-AvailablePort
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -HtmlPath "{1}" -DataPath "{2}" -GhPath "{3}" -Port {4} -ErrorLogPath "{5}"' -f
      $serverPath, $HtmlPath, $DataPath, $GhPath, $port, $errorLogPath
    $process = Start-Process -FilePath $powershellPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    Save-ServerState $process $port
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
      if (Test-Health $port) { $ready = $true; break }
      $process.Refresh()
      if ($process.HasExited) { break }
      Start-Sleep -Milliseconds 200
    }
    if (-not $ready) {
      $process.Refresh()
      if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
      Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    }
  }
  if (-not $ready) { throw '週次レポートサーバが起動しませんでした（または15秒以内に応答しませんでした）。' }
  $url = "http://127.0.0.1:$port/"
  Write-Output "URL: $url"
  Write-Output ("サーバ起動: {0:N1} 秒" -f ((Get-Date) - $launchStartedAt).TotalSeconds)
  if (-not $NoBrowser) { Start-Process $url }
} catch {
  Write-FailureLog $_.Exception.ToString()
  [Console]::Error.WriteLine("エラー: $($_.Exception.Message)")
  [Console]::Error.WriteLine("ログ: $errorLogPath")
  exit 1
}
