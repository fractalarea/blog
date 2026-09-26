# Servidor local minimo para o editor do blog.
# Compativel com Windows PowerShell 5.1 (nao usa sintaxe do PowerShell 7).
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $raiz

$porta = 8787
$utf8 = New-Object System.Text.UTF8Encoding $false

# Junta caminho tolerando variavel de ambiente ausente (em Linux elas nao existem).
function Caminho($base, $resto) {
  if ([string]::IsNullOrEmpty($base)) { return $null }
  return (Join-Path $base $resto)
}

function Acha-Programa($nome, $candidatos) {
  $cmd = Get-Command $nome -ErrorAction SilentlyContinue
  if ($cmd) { return $nome }
  foreach ($c in $candidatos) { if ($c -and (Test-Path $c)) { return $c } }
  return $null
}

$git = Acha-Programa "git" @(
  (Caminho $env:ProgramFiles "Git\cmd\git.exe"),
  (Caminho ${env:ProgramFiles(x86)} "Git\cmd\git.exe"),
  (Caminho $env:LOCALAPPDATA "Programs\Git\cmd\git.exe"))
$quarto = Acha-Programa "quarto" @(
  (Caminho $env:LOCALAPPDATA "Programs\Quarto\bin\quarto.cmd"),
  (Caminho $env:ProgramFiles "Quarto\bin\quarto.cmd"))

function Json-Escape($s) {
  if ($null -eq $s) { return '""' }
  $s = $s -replace '\\', '\\\\'
  $s = $s -replace '"', '\"'
  $s = $s -replace "`r", '\r'
  $s = $s -replace "`n", '\n'
  $s = $s -replace "`t", '\t'
  return '"' + $s + '"'
}

function Le-Requisicao($stream) {
  $ms = New-Object System.IO.MemoryStream
  $buf = New-Object byte[] 16384
  $fim = -1
  while ($fim -lt 0) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { return $null }
    $ms.Write($buf, 0, $n)
    $arr = $ms.ToArray()
    for ($i = 3; $i -lt $arr.Length; $i++) {
      if ($arr[$i-3] -eq 13 -and $arr[$i-2] -eq 10 -and $arr[$i-1] -eq 13 -and $arr[$i] -eq 10) { $fim = $i; break }
    }
  }
  $arr = $ms.ToArray()
  $cab = [System.Text.Encoding]::ASCII.GetString($arr, 0, $fim + 1)
  $tam = 0
  foreach ($linha in ($cab -split "`r`n")) {
    if ($linha -match '^(?i)content-length:\s*(\d+)') { $tam = [int]$matches[1] }
  }
  $corpo = New-Object System.IO.MemoryStream
  $jaTem = $arr.Length - ($fim + 1)
  if ($jaTem -gt 0) { $corpo.Write($arr, $fim + 1, $jaTem) }
  while ($corpo.Length -lt $tam) {
    $n = $stream.Read($buf, 0, [Math]::Min($buf.Length, $tam - $corpo.Length))
    if ($n -le 0) { break }
    $corpo.Write($buf, 0, $n)
  }
  $primeira = ($cab -split "`r`n")[0]
  $partes = $primeira -split ' '
  return @{
    metodo = $partes[0]
    caminho = $partes[1]
    corpo = [System.Text.Encoding]::UTF8.GetString($corpo.ToArray())
  }
}

function Responde($stream, $status, $tipo, $texto) {
  $bytes = $utf8.GetBytes($texto)
  $cab = "HTTP/1.1 $status`r`nContent-Type: $tipo; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $cb = [System.Text.Encoding]::ASCII.GetBytes($cab)
  $stream.Write($cb, 0, $cb.Length)
  $stream.Write($bytes, 0, $bytes.Length)
  $stream.Flush()
}

function Responde-Bytes($stream, $status, $tipo, $bytes) {
  $cab = "HTTP/1.1 $status`r`nContent-Type: $tipo`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $cb = [System.Text.Encoding]::ASCII.GetBytes($cab)
  $stream.Write($cb, 0, $cb.Length)
  if ($bytes.Length -gt 0) { $stream.Write($bytes, 0, $bytes.Length) }
  $stream.Flush()
}

function Tipo-Mime($ext) {
  switch ($ext.ToLower()) {
    ".html"  { return "text/html; charset=utf-8" }
    ".htm"   { return "text/html; charset=utf-8" }
    ".css"   { return "text/css; charset=utf-8" }
    ".js"    { return "application/javascript; charset=utf-8" }
    ".json"  { return "application/json; charset=utf-8" }
    ".xml"   { return "application/xml; charset=utf-8" }
    ".svg"   { return "image/svg+xml" }
    ".png"   { return "image/png" }
    ".jpg"   { return "image/jpeg" }
    ".jpeg"  { return "image/jpeg" }
    ".gif"   { return "image/gif" }
    ".webp"  { return "image/webp" }
    ".woff"  { return "font/woff" }
    ".woff2" { return "font/woff2" }
    ".ttf"   { return "font/ttf" }
    ".ico"   { return "image/x-icon" }
    ".txt"   { return "text/plain; charset=utf-8" }
    default  { return "application/octet-stream" }
  }
}

function Campo-Json($json, $nome) {
  # Extrai um campo string de um JSON simples, sem depender de ConvertFrom-Json.
  # A desescapagem PRECISA ser em passe unico: trocar \n antes de \\ faria o
  # \\norm de uma macro LaTeX virar quebra de linha.
  $m = [regex]::Match($json, '"' + $nome + '"\s*:\s*"((?:[^"\\]|\\.)*)"')
  if (-not $m.Success) { return "" }
  $v = $m.Groups[1].Value
  return [regex]::Replace($v, '\\u([0-9a-fA-F]{4})|\\(.)', {
    param($x)
    if ($x.Groups[1].Success) {
      return [char][Convert]::ToInt32($x.Groups[1].Value, 16)
    }
    $c = $x.Groups[2].Value
    switch ($c) {
      'n' { return "`n" }
      'r' { return "`r" }
      't' { return "`t" }
      'b' { return "`b" }
      'f' { return "`f" }
      '"' { return '"' }
      '\' { return '\' }
      '/' { return '/' }
      default { return $c }
    }
  })
}

# Valida o nome da pasta de um post. Alem do conjunto de caracteres, precisa
# rejeitar "." e ".." explicitamente: o regex de caracteres sozinho os aceita, e
# pasta=".." gravaria em posts/../index.qmd, sobrescrevendo a capa do blog.
function Pasta-Valida($p) {
  if ([string]::IsNullOrEmpty($p)) { return $false }
  if ($p -notmatch '^[A-Za-z0-9_\-\.]+$') { return $false }
  if ($p -match '^\.+$') { return $false }
  return $true
}

function Lista-Posts {
  $itens = @()
  $dir = Join-Path $raiz "posts"
  if (Test-Path $dir) {
    foreach ($p in (Get-ChildItem $dir -Directory | Sort-Object Name -Descending)) {
      $arq = Join-Path $p.FullName "index.qmd"
      if (-not (Test-Path $arq)) { continue }
      $txt = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8)
      $t = [regex]::Match($txt, '(?m)^title:\s*"?([^"\r\n]+)"?')
      $titulo = $p.Name
      if ($t.Success) { $titulo = $t.Groups[1].Value.Trim() }
      $oculto = $p.Name.StartsWith("_")
      $itens += (,@{ pasta = $p.Name; titulo = $titulo; oculto = $oculto })
    }
  }
  $partes = @()
  foreach ($i in $itens) {
    $partes += "{""pasta"":" + (Json-Escape $i.pasta) + ",""titulo"":" + (Json-Escape $i.titulo) + ",""oculto"":" + $(if ($i.oculto) { "true" } else { "false" }) + "}"
  }
  return "[" + ($partes -join ",") + "]"
}

function Roda($exe, $argumentos) {
  if (-not $exe) { return @{ ok = $false; log = "programa nao encontrado" } }
  $saida = & $exe @argumentos 2>&1 | Out-String
  return @{ ok = ($LASTEXITCODE -eq 0); log = $saida }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $porta)
$listener.Start()
Write-Host ""
Write-Host "  Editor do blog rodando em http://127.0.0.1:$porta/"
Write-Host "  Feche esta janela para encerrar."
Write-Host ""
if ($env:OS -eq "Windows_NT") { Start-Process "http://127.0.0.1:$porta/" }

$rodando = $true
while ($rodando) {
  $cliente = $listener.AcceptTcpClient()
  # Navegadores abrem conexoes especulativas e nao mandam nada. Sem timeout, o
  # laco de atendimento (que e sequencial) ficaria preso numa delas para sempre.
  $cliente.ReceiveTimeout = 8000
  $stream = $cliente.GetStream()
  $stream.ReadTimeout = 8000
  try {
    $req = Le-Requisicao $stream
    if ($null -eq $req) { $cliente.Close(); continue }
    $caminho = ($req.caminho -split '\?')[0]

    if ($caminho -eq "/" -or $caminho -eq "/index.html") {
      $html = [System.IO.File]::ReadAllText((Join-Path $raiz "editor.html"), [System.Text.Encoding]::UTF8)
      Responde $stream "200 OK" "text/html" $html
    }
    elseif ($caminho -eq "/api/posts") {
      Responde $stream "200 OK" "application/json" (Lista-Posts)
    }
    elseif ($caminho -eq "/api/ler") {
      $pasta = Campo-Json $req.corpo "pasta"
      if (-not (Pasta-Valida $pasta)) {
        Responde $stream "200 OK" "application/json" '{"ok":false,"erro":"nome de pasta invalido"}'
        $cliente.Close(); continue
      }
      $arq = Join-Path (Join-Path $raiz "posts") (Join-Path $pasta "index.qmd")
      if (Test-Path $arq) {
        $txt = [System.IO.File]::ReadAllText($arq, [System.Text.Encoding]::UTF8)
        Responde $stream "200 OK" "application/json" ("{""ok"":true,""texto"":" + (Json-Escape $txt) + "}")
      } else {
        Responde $stream "200 OK" "application/json" '{"ok":false,"erro":"post nao encontrado"}'
      }
    }
    elseif ($caminho -eq "/api/salvar") {
      $pasta = Campo-Json $req.corpo "pasta"
      $texto = Campo-Json $req.corpo "texto"
      if (-not (Pasta-Valida $pasta)) {
        Responde $stream "200 OK" "application/json" '{"ok":false,"erro":"nome de pasta invalido"}'
      } else {
        $dir = Join-Path (Join-Path $raiz "posts") $pasta
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        [System.IO.File]::WriteAllText((Join-Path $dir "index.qmd"), $texto, $utf8)
        Responde $stream "200 OK" "application/json" '{"ok":true}'
      }
    }
    elseif ($caminho -eq "/previa" -or $caminho.StartsWith("/previa/")) {
      $rel = [System.Uri]::UnescapeDataString(($caminho -replace '^/previa/?', ''))
      $site = Join-Path $raiz "_site"
      $alvo = $site
      if ($rel) { $alvo = Join-Path $site $rel }
      if ((Test-Path $alvo) -and (Get-Item $alvo).PSIsContainer) { $alvo = Join-Path $alvo "index.html" }
      $baseR = Resolve-Path $site -ErrorAction SilentlyContinue
      if ($baseR -and (Test-Path $alvo)) {
        $full = (Resolve-Path $alvo).Path
        if ($full.StartsWith($baseR.Path)) {
          $bytes = [System.IO.File]::ReadAllBytes($full)
          Responde-Bytes $stream "200 OK" (Tipo-Mime ([System.IO.Path]::GetExtension($full))) $bytes
        } else {
          Responde $stream "403 Forbidden" "text/plain" "fora do _site"
        }
      } else {
        Responde $stream "404 Not Found" "text/plain" "ainda nao renderizado"
      }
    }
    elseif ($caminho -eq "/api/renderizar") {
      if (-not $quarto) {
        Responde $stream "200 OK" "application/json" '{"ok":false,"log":"Quarto nao encontrado nesta maquina."}'
      } else {
        $r = Roda $quarto @("render")
        $json = "{""ok"":" + $(if ($r.ok) { "true" } else { "false" }) + ",""log"":" + (Json-Escape $r.log) + "}"
        Responde $stream "200 OK" "application/json" $json
      }
    }
    elseif ($caminho -eq "/api/postar") {
      $msg = Campo-Json $req.corpo "mensagem"
      if (-not $msg) { $msg = "Atualiza o blog" }
      $log = ""
      $falhou = $false
      if ($quarto) {
        $r = Roda $quarto @("render")
        $log += "== quarto render ==`n" + $r.log + "`n"
        if (-not $r.ok) { $falhou = $true }
      } else {
        $log += "== quarto nao encontrado: renderizacao pulada ==`n(so e seguro se o post nao tem chunk de codigo)`n`n"
      }
      if (-not $falhou) {
        $r = Roda $git @("add", "-A");     $log += "== git add ==`n" + $r.log
        $r = Roda $git @("commit", "-m", $msg); $log += "== git commit ==`n" + $r.log
        $r = Roda $git @("push");          $log += "== git push ==`n" + $r.log
        if (-not $r.ok) { $falhou = $true }
      }
      $json = "{""ok"":" + $(if ($falhou) { "false" } else { "true" }) + ",""log"":" + (Json-Escape $log) + "}"
      Responde $stream "200 OK" "application/json" $json
    }
    elseif ($caminho -eq "/api/sair") {
      Responde $stream "200 OK" "application/json" '{"ok":true}'
      $rodando = $false
    }
    else {
      Responde $stream "404 Not Found" "text/plain" "nao encontrado"
    }
  } catch {
    try { Responde $stream "500 Internal Server Error" "text/plain" ($_.Exception.Message) } catch { }
  } finally {
    $cliente.Close()
  }
}
$listener.Stop()
