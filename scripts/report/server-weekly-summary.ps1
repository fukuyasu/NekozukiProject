param(
  [string]$HtmlPath,
  [string]$DataPath,
  [string]$GhPath,
  [int]$Port,
  [string]$ErrorLogPath
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $OutputEncoding
if ([string]::IsNullOrWhiteSpace($HtmlPath) -or [string]::IsNullOrWhiteSpace($DataPath) -or
    [string]::IsNullOrWhiteSpace($GhPath) -or $Port -le 0) {
  throw 'HtmlPath, DataPath, GhPath, and a positive Port are required.'
}
$HtmlPath = (Resolve-Path -LiteralPath $HtmlPath).Path
$DataPath = (Resolve-Path -LiteralPath $DataPath).Path
$GhPath = (Resolve-Path -LiteralPath $GhPath).Path
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$startedAt = Get-Date
$lastActivity = $startedAt
$bulmaPath = Join-Path (Split-Path -Path $HtmlPath -Parent) 'assets\vendor\bulma-1.0.4.min.css'
$dataDirectory = Split-Path -Path $DataPath -Parent
$previewCache = @{}

function Send-Response($client, $statusCode, $contentType, $body) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
  $statusText = if ($statusCode -eq 200) { 'OK' } elseif ($statusCode -eq 204) { 'No Content' } elseif ($statusCode -eq 400) { 'Bad Request' } elseif ($statusCode -eq 404) { 'Not Found' } else { 'Method Not Allowed' }
  $header = "HTTP/1.1 $statusCode $statusText`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $stream = $client.GetStream()
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
  $stream.Write($headerBytes, 0, $headerBytes.Length)
  if ($bytes.Length -gt 0) { $stream.Write($bytes, 0, $bytes.Length) }
  $stream.Flush()
}

function Read-ReportData {
  $data = Get-Content -LiteralPath $DataPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($data.schemaVersion -ne 4) { throw 'Unsupported report JSON version.' }
  return $data
}

function Write-ReportData($data) {
  $temporaryPath = "$DataPath.tmp"
  [System.IO.File]::WriteAllText($temporaryPath, ($data | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
  Move-Item -LiteralPath $temporaryPath -Destination $DataPath -Force
}

function Save-AiUsage($requestBody) {
  $update = $requestBody | ConvertFrom-Json
  if ([string]$update.pr -notmatch '^[1-9][0-9]*$') { throw 'A PR number is required.' }
  $allowed = 'none', 'brainstorm', 'plan-issues', 'implement-issue', 'prepare-pr', 'debug', 'review-pr', 'other'
  $choices = @($update.choices)
  if ($choices.Count -gt $allowed.Count -or @($choices | Select-Object -Unique).Count -ne $choices.Count) { throw 'Invalid AI choices.' }
  foreach ($choice in $choices) { if ($allowed -notcontains $choice) { throw 'Invalid AI choice.' } }
  if ($choices -contains 'none' -and $choices.Count -gt 1) { throw 'No AI usage cannot be combined with other choices.' }
  $other = [string]$update.other
  if ($other.Length -gt 500 -or ($choices -notcontains 'other' -and $other.Length -gt 0)) { throw 'Invalid other AI usage.' }
  $data = Read-ReportData
  if (-not @($data.closedPullRequests | Where-Object { $_.number -eq [int]$update.pr }).Count) { throw 'PR is not in this report.' }
  $entry = [pscustomobject]@{ choices = $choices; other = $other; updatedAt = (Get-Date).ToString('o') }
  $data.aiUsage | Add-Member -MemberType NoteProperty -Name ([string]$update.pr) -Value $entry -Force
  Write-ReportData $data
}

function Save-DodAssessment($requestBody) {
  $update = $requestBody | ConvertFrom-Json
  $item = [string]$update.item
  if ($item -notmatch '^[1-6]$') { throw 'Invalid DoD item.' }
  if ($update.PSObject.Properties.Name -contains 'choices') { throw 'Invalid DoD choices.' }
  $data = Read-ReportData
  $allowed = switch ($item) {
    '1' { 'correct', 'incorrect', 'no_assigned' }
    '2' { 'correct', 'incorrect', 'no_assigned' }
    '3' { 'no_direct_main', 'direct_main' }
    '4' { 'complete', 'missing', 'no_assigned' }
    '5' { 'complete', 'missing', 'no_assigned' }
    '6' { 'reviewed', 'same_reviewer', 'no_review_result', 'no_merged' }
  }
  $choice = [string]$update.choice
  if ($choice -ne '' -and $allowed -notcontains $choice) { throw 'Invalid DoD choice.' }
  if ($choice -eq '') { $data.dodAssessment.PSObject.Properties.Remove($item) }
  else {
    $entry = [pscustomobject]@{ choice = $choice; updatedAt = (Get-Date).ToString('o') }
    $data.dodAssessment | Add-Member -MemberType NoteProperty -Name $item -Value $entry -Force
  }
  Write-ReportData $data
}

function Read-ReportHtml {
  $html = Get-Content -LiteralPath $HtmlPath -Raw -Encoding UTF8
  $reportJson = (Get-Content -LiteralPath $DataPath -Raw -Encoding UTF8).Replace('<', '\u003c')
  $prefix = '<script>const report='
  $suffix = ';/*WEEKLY_SUMMARY_DATA_END*/'
  $start = $html.IndexOf($prefix)
  if ($start -lt 0) { throw 'The report HTML does not contain the report data placeholder.' }
  $start += $prefix.Length
  $end = $html.IndexOf($suffix, $start)
  if ($end -lt 0) { throw 'The report HTML does not contain the report data terminator.' }
  $options = Get-ChildItem -LiteralPath $dataDirectory -File -Filter 'lec*.json' |
    Sort-Object -Property Name -Descending |
    ForEach-Object {
      $selected = if ($_.FullName -eq $DataPath) { ' selected' } else { '' }
      $name = [System.Net.WebUtility]::HtmlEncode($_.Name)
      "<option value=""$name""$selected>$name</option>"
    }
  return ($html.Substring(0, $start) + $reportJson + $html.Substring($end)).Replace('__REPORT_OPTIONS__', ($options -join ''))
}

function Select-ReportData($requestTarget) {
  $uri = [uri]("http://127.0.0.1" + $requestTarget)
  $requested = $null
  if ($requestTarget -match '[?&]report=([^&]+)') {
    $requested = [uri]::UnescapeDataString($Matches[1])
  }
  if ([string]::IsNullOrWhiteSpace($requested)) { return $uri.AbsolutePath }
  $fileName = [System.IO.Path]::GetFileName($requested)
  if ($fileName -ne $requested -or $fileName -notmatch '\.json$') { throw 'Invalid report file.' }
  $candidate = Join-Path $dataDirectory $fileName
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw 'Report JSON was not found.' }
  $script:DataPath = $candidate
  return $uri.AbsolutePath
}

function Invoke-GhObject([string]$endpoint) {
  $global:LASTEXITCODE = 0
  $result = & $GhPath api $endpoint 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'GitHub preview request failed.' }
  return (($result -join "`n") | ConvertFrom-Json)
}

function Invoke-GhItems([string]$endpoint) {
  $global:LASTEXITCODE = 0
  $result = & $GhPath api --paginate --slurp $endpoint 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'GitHub preview discussion request failed.' }
  $pages = ($result -join "`n") | ConvertFrom-Json
  $items = @()
  foreach ($page in $pages) { foreach ($item in $page) { $items += $item } }
  return $items
}

function Get-Preview([string]$requestTarget) {
  if ($requestTarget -cmatch '^/api/preview\?kind=(issue|pr)&number=([1-9][0-9]*)$') {
    $kind = $Matches[1]
    $number = [int]$Matches[2]
  } else { throw 'Invalid preview request.' }
  $data = Read-ReportData
  $repository = [string]$data.repository
  if ($repository -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid repository.' }
  $allowed = @()
  if ($kind -eq 'issue') {
    $allowed += @($data.dodIssues) + @($data.manuallyClosedIssues) + @($data.openIssues) + @($data.completedIssues)
    foreach ($pr in $data.closedPullRequests) { $allowed += @($pr.relatedIssues) }
  } else {
    $allowed += @($data.closedPullRequests) + @($data.mergedByStudent) + @($data.dodPullRequests) +
      @($data.dodCreatedPullRequests) + @($data.openPullRequests) + @($data.pullRequests)
  }
  $linked = @($data.githubComments) + @($data.troubleshooting)
  $pathKind = if ($kind -eq 'issue') { 'issues' } else { 'pull' }
  $linkedPattern = '^https://github\.com/' + [regex]::Escape($repository) + '/' + $pathKind + '/' + $number + '(?:[?#]|$)'
  if (-not @($allowed | Where-Object { $_.number -eq $number }).Count -and
      -not @($linked | Where-Object { $_.html_url -match $linkedPattern -or $_.url -match $linkedPattern }).Count) {
    throw 'Preview target is not in this report.'
  }
  $key = "$repository/$kind/$number"
  if ($script:previewCache.ContainsKey($key)) { return $script:previewCache[$key] }
  $endpoint = if ($kind -eq 'issue') { "repos/$repository/issues/$number" } else { "repos/$repository/pulls/$number" }
  $item = Invoke-GhObject $endpoint
  $comments = @(Invoke-GhItems "repos/$repository/issues/$number/comments?per_page=100" |
    ForEach-Object { [ordered]@{ author = $_.user.login; body = $_.body; createdAt = $_.created_at } })
  $reviews = @()
  if ($kind -eq 'pr') {
    $reviews = @(Invoke-GhItems "repos/$repository/pulls/$number/reviews?per_page=100" |
      ForEach-Object { [ordered]@{ author = $_.user.login; state = $_.state; body = $_.body; submittedAt = $_.submitted_at } })
  }
  $preview = [ordered]@{
    kind = $kind; number = $number; title = $item.title; state = $item.state; body = $item.body
    url = $item.html_url; author = $item.user.login; assignees = @($item.assignees | ForEach-Object { $_.login })
    milestone = $item.milestone.title; labels = @($item.labels | ForEach-Object { $_.name })
    comments = $comments; reviews = $reviews
  }
  $json = $preview | ConvertTo-Json -Depth 20 -Compress
  $script:previewCache[$key] = $json
  return $json
}

try {
  $listener.Start()
  $running = $true
  while ($true) {
    while (-not $listener.Pending()) {
      $now = Get-Date
      if (($now - $lastActivity).TotalMinutes -ge 5) {
        $listener.Stop()
        $running = $false
        break
      }
      Start-Sleep -Seconds 1
    }
    if (-not $running) { break }
    $client = $listener.AcceptTcpClient()
    try {
      # ブラウザの先行接続がHTTP要求を送らなくても、後続の要求を塞がない。
      $client.ReceiveTimeout = 1000
      $client.SendTimeout = 5000
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $false, 4096, $true)
      $requestLine = $reader.ReadLine()
      $client.ReceiveTimeout = 5000
      $parts = $requestLine -split ' '
      $method = $parts[0]; $path = Select-ReportData $parts[1]
      $contentLength = 0
      while ($true) {
        $headerLine = $reader.ReadLine()
        if ([string]::IsNullOrEmpty($headerLine)) { break }
        if ($headerLine -match '^Content-Length:\s*(\d+)$') { $contentLength = [int]$Matches[1] }
      }
      if ($contentLength -gt 16384) { throw 'Request body is too large.' }
      $requestBody = ''
      if ($contentLength -gt 0) {
        $chars = New-Object char[] $contentLength
        $read = 0
        while ($read -lt $contentLength) {
          $chunk = $reader.Read($chars, $read, $contentLength - $read)
          if ($chunk -le 0) { throw 'Incomplete request body.' }
          $read += $chunk
        }
        $requestBody = -join $chars
      }
      switch ($path) {
        '/api/health' {
          Send-Response $client 204 'text/plain; charset=utf-8' ''
        }
        '/' {
          Send-Response $client 200 'text/html; charset=utf-8' (Read-ReportHtml)
        }
        '/assets/vendor/bulma-1.0.4.min.css' {
          Send-Response $client 200 'text/css; charset=utf-8' (Get-Content -LiteralPath $bulmaPath -Raw -Encoding UTF8)
        }
        '/api/heartbeat' {
          Send-Response $client 204 'text/plain; charset=utf-8' ''
        }
        '/api/preview' {
          if ($method -ne 'GET') { Send-Response $client 405 'text/plain; charset=utf-8' 'Method Not Allowed'; break }
          Send-Response $client 200 'application/json; charset=utf-8' (Get-Preview $parts[1])
        }
        '/api/ai-usage' {
          if ($method -ne 'POST') { Send-Response $client 405 'text/plain; charset=utf-8' 'Method Not Allowed'; break }
          Save-AiUsage $requestBody
          Send-Response $client 200 'application/json; charset=utf-8' '{"ok":true}'
        }
        '/api/dod-assessment' {
          if ($method -ne 'POST') { Send-Response $client 405 'text/plain; charset=utf-8' 'Method Not Allowed'; break }
          Save-DodAssessment $requestBody
          Send-Response $client 200 'application/json; charset=utf-8' '{"ok":true}'
        }
        default { Send-Response $client 404 'text/plain; charset=utf-8' 'Not Found' }
      }
    } catch {
      try {
        Send-Response $client 400 'application/json; charset=utf-8' ('{"ok":false,"error":' + ($_.Exception.Message | ConvertTo-Json -Compress) + '}')
      } catch {
        # ブラウザが接続を閉じてもサーバ全体は終了させない。
      }
    } finally {
      $client.Close()
      $lastActivity = Get-Date
    }
  }
} catch {
  if (-not [string]::IsNullOrWhiteSpace($ErrorLogPath)) {
    Add-Content -LiteralPath $ErrorLogPath -Encoding UTF8 -Value ("{0} {1}" -f (Get-Date -Format 'o'), $_.Exception.ToString())
  }
  exit 1
} finally {
  $previewCache.Clear()
  $listener.Stop()
  $listener.Close()
}
