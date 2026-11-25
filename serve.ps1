param([int]$Port=0,[switch]$NoBrowser,[switch]$Server)

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$healthMarker = 'hp-bio-quiz-v14'

function Test-QuizServer([int]$Candidate) {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Candidate/__hp_quiz_health__" -TimeoutSec 1
    return $response.Content -eq $healthMarker
  } catch { return $false }
}

function Test-PortOccupied([int]$Candidate) {
  $probe = $null
  try {
    $probe = [Net.Sockets.TcpClient]::new()
    $task = $probe.ConnectAsync('127.0.0.1',$Candidate)
    return $task.Wait(180) -and $probe.Connected
  } catch { return $false }
  finally { if ($probe) { $probe.Dispose() } }
}

if ($Port -le 0) {
  foreach ($candidate in 8765..8785) {
    if (Test-QuizServer $candidate) {
      if (-not $NoBrowser) { Start-Process "http://127.0.0.1:$candidate/index.html?v=14" }
      exit 0
    }
  }
  foreach ($candidate in 8765..8785) {
    if (-not (Test-PortOccupied $candidate)) { $Port=$candidate; break }
  }
}

if ($Port -le 0) {
  Write-Host 'No free local port was found.' -ForegroundColor Red
  Write-Host 'Close other local server apps and try again.'
  if (-not $NoBrowser) { Read-Host 'Press Enter to close this window' | Out-Null }
  exit 1
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
try {
  $listener.Start()
} catch {
  Write-Host "Could not start the quiz on port $Port`: $($_.Exception.Message)" -ForegroundColor Red
  if (-not $NoBrowser) { Read-Host 'Press Enter to close this window' | Out-Null }
  exit 1
}

$url = "http://127.0.0.1:$Port/index.html?v=14"
Write-Host ''
Write-Host 'Harry Potter Biology Quiz is ready.' -ForegroundColor Green
Write-Host "App address: $url"
Write-Host 'Keep this window open while using the quiz.' -ForegroundColor Yellow
Write-Host 'Press Ctrl+C to stop the app.'
if (-not $NoBrowser) { Start-Process $url }

$mime = @{'.html'='text/html; charset=utf-8';'.js'='text/javascript; charset=utf-8';'.mjs'='text/javascript; charset=utf-8';'.css'='text/css; charset=utf-8';'.json'='application/json';'.webmanifest'='application/manifest+json';'.pdf'='application/pdf';'.png'='image/png';'.svg'='image/svg+xml';'.woff2'='font/woff2';'.txt'='text/plain; charset=utf-8'}
try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = [IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
      $request = $reader.ReadLine()
      if (-not $request) { continue }
      while (($line=$reader.ReadLine()) -ne '') { if ($null -eq $line) { break } }
      $parts = $request -split ' '
      if ($parts.Count -lt 2) { continue }
      $rawPath = $parts[1].Split('?')[0]
      if ($rawPath -eq '/__hp_quiz_health__') {
        $body=[Text.Encoding]::UTF8.GetBytes($healthMarker)
        $status='200 OK'
        $type='text/plain; charset=utf-8'
      } else {
        $relative = [Uri]::UnescapeDataString($rawPath).TrimStart('/').Replace('/',[IO.Path]::DirectorySeparatorChar)
        if ([string]::IsNullOrWhiteSpace($relative)) { $relative='index.html' }
        $file = [IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $file.StartsWith($root,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
          $body=[Text.Encoding]::UTF8.GetBytes('Not found')
          $status='404 Not Found'
          $type='text/plain; charset=utf-8'
        } else {
          $body=[IO.File]::ReadAllBytes($file)
          $status='200 OK'
          $ext=[IO.Path]::GetExtension($file).ToLowerInvariant()
          $type=if($mime[$ext]){$mime[$ext]}else{'application/octet-stream'}
        }
      }
      $header="HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
      $head=[Text.Encoding]::ASCII.GetBytes($header)
      $stream.Write($head,0,$head.Length)
      $stream.Write($body,0,$body.Length)
    } catch {
      Write-Host "Local request error: $($_.Exception.Message)" -ForegroundColor DarkYellow
    } finally {
      if ($client) { $client.Close() }
    }
  }
} finally {
  $listener.Stop()
}
