# Editor do blog — especificação técnica

Documento de referência para quem for integrar este editor em um sistema maior.
Descreve o comportamento **real** do código, incluindo limitações e defeitos
conhecidos. Escrito a partir da leitura linha a linha da versão corrente.

---

## 1. Contexto e propósito

O editor é uma ferramenta local de autoria para um blog estático em
[Quarto](https://quarto.org) publicado no GitHub Pages. O ciclo que ele
automatiza é:

```
escrever .qmd  →  quarto render  →  git add/commit/push  →  GitHub Actions  →  site no ar
```

Restrição de origem que motivou o desenho: uma página HTML aberta por `file://`
não pode gravar arquivos nem executar processos. Por isso existe um servidor
local — a página é só o cliente.

Premissa do projeto Quarto que o editor atende: os resultados dos chunks de
R/Python são congelados em `_freeze/` na máquina do autor e versionados, de modo
que o CI monta o HTML sem ter R nem Python instalados. **Consequência para o
editor: renderizar localmente antes de commitar não é opcional quando o post tem
código.**

---

## 2. Arquivos

Os três ficam na **raiz do projeto Quarto**, ao lado de `_quarto.yml`.

| Arquivo | Papel |
|---|---|
| `editor.bat` | Lançador. Conserta o `PATH` da janela, localiza o PowerShell e chama o `.ps1`. |
| `editor.ps1` | Servidor HTTP local e toda a lógica. ~290 linhas, sem dependências. |
| `editor.html` | Cliente: UI e chamadas à API. Documento único, sem bibliotecas externas. |

`editor.ps1` determina a raiz do projeto por
`Split-Path -Parent $MyInvocation.MyCommand.Path` e faz `Set-Location` nela.
**Todos os caminhos são relativos a essa raiz.** Mover o `.ps1` para outra pasta
quebra tudo.

---

## 3. Ciclo de vida

1. O usuário executa `editor.bat`.
2. O `.bat` acrescenta à variável `PATH` **da própria janela** (via `setlocal`):
   `%SystemRoot%\System32`, `%SystemRoot%`, `...\Wbem`, `...\WindowsPowerShell\v1.0`,
   e, se existir `%ProgramFiles%\R\R-*`, também `bin\x64` e `bin` do R.
   Isso existe porque a máquina-alvo está com o `PATH` do sistema sem o
   `System32` — o que quebra `chcp`, `where`, e a busca do R pelo Quarto, que
   executa `CMD` internamente para localizá-lo.
3. O `.bat` chama
   `powershell -NoProfile -ExecutionPolicy Bypass -File editor.ps1`.
4. O `.ps1` localiza `git` e `quarto`, abre um `TcpListener` em
   `127.0.0.1:8787`, imprime a URL e chama `Start-Process` na URL (abre o
   navegador padrão). O `Start-Process` é condicionado a
   `$env:OS -eq "Windows_NT"`.
5. Laço de atendimento **sequencial e bloqueante** até `/api/sair` ou até a
   janela ser fechada.

Não há desligamento gracioso além do `/api/sair`; fechar a janela mata o
processo e libera a porta.

---

## 4. Decisões de arquitetura e por quê

**`TcpListener` em vez de `HttpListener`.** O `HttpListener` do .NET exige uma
reserva de URL (`netsh http add urlacl`) e, sem ela, falha com acesso negado
quando executado sem privilégio de administrador. O `TcpListener` em loopback
não exige nada. O custo é implementar HTTP à mão.

**PowerShell em vez de Python/Node/Deno.** É o único runtime garantido em
qualquer Windows. O código evita sintaxe exclusiva do PowerShell 7 (sem `??`,
sem operador ternário, sem `-Parallel`) para rodar no Windows PowerShell 5.1,
que é o que vem instalado.

**JSON à mão em vez de `ConvertTo-Json`/`ConvertFrom-Json`.** Decisão
discutível, herdada de cautela com diferenças entre 5.1 e 7 (profundidade
padrão, tratamento de `PSCustomObject`). Ver §7 para o que isso custou.

**Sem bibliotecas no cliente.** A página é um arquivo só, servido inteiro a cada
`GET /`.

---

## 5. Implementação de HTTP e seus limites

`Le-Requisicao` lê do socket até encontrar `CRLFCRLF`, interpreta o cabeçalho
como ASCII, extrai `Content-Length` e lê exatamente esse número de bytes de
corpo, decodificando como UTF-8. Devolve `@{ metodo; caminho; corpo }`.

`Responde` e `Responde-Bytes` escrevem `HTTP/1.1 <status>` com `Content-Type`,
`Content-Length`, `Cache-Control: no-store` e `Connection: close`.

O que **não** é implementado, e que um integrador precisa saber:

- **Sem `keep-alive`.** Toda resposta fecha a conexão.
- **Sem `Transfer-Encoding: chunked`** na entrada. Requisição sem
  `Content-Length` é tratada como corpo vazio.
- **Sem `multipart/form-data`.** Não há upload de arquivo; imagens de post
  precisam ser colocadas na pasta por fora.
- **Sem negociação de conteúdo, sem compressão, sem `Range`, sem `ETag`.**
- **Atendimento estritamente sequencial.** Uma requisição lenta (§10) bloqueia
  todas as outras, inclusive as do próprio navegador.
- **Timeout de leitura de 8 s** (`ReceiveTimeout`/`ReadTimeout`). Existe porque
  navegadores abrem conexões especulativas e não enviam nada; sem timeout, o
  laço sequencial ficaria preso numa delas indefinidamente. Na expiração, a
  exceção cai no `catch` do laço e a conexão é fechada.
- **`$ErrorActionPreference = "Stop"`** no topo: qualquer erro não tratado vira
  exceção, capturada pelo `try/catch` do laço, que responde `500` com a
  mensagem da exceção em texto puro.

---

## 6. Referência da API

Base: `http://127.0.0.1:8787`. Todas as respostas de API são
`application/json; charset=utf-8` e **status `200`**, inclusive em erro de
domínio — o erro vem no campo `ok: false`. Só `/previa` usa `403`/`404`.

O cliente envia `POST` quando há corpo e `GET` quando não há, mas **o servidor
não verifica o método**. Qualquer método é aceito em qualquer rota.

### `GET /` e `GET /index.html`
Devolve o conteúdo de `editor.html` lido do disco a cada requisição (sem cache;
editar o HTML e recarregar a página basta).

### `GET /api/posts`
Lista as pastas de `posts/` que contenham `index.qmd`, ordenadas por nome
**descendente** (como os nomes começam com a data, isso ordena do mais recente
ao mais antigo).

```json
[
  {"pasta":"2026-09-08-birkhoff","titulo":"O teorema ergódico de Birkhoff","oculto":false},
  {"pasta":"_modelo","titulo":"Título do post","oculto":true}
]
```

- `titulo` vem do primeiro casamento de `(?m)^title:\s*"?([^"\r\n]+)"?` **no
  arquivo inteiro**, não só no cabeçalho YAML. Se o cabeçalho não tiver `title:`
  e o corpo tiver uma linha começando com `title:`, essa será usada. Se não
  houver nenhuma, cai para o nome da pasta.
- `oculto` é `true` quando o nome da pasta começa com `_`. No Quarto isso
  significa que o post não é renderizado nem listado — é a convenção usada para
  despublicar.

### `POST /api/ler`
```json
// requisição
{"pasta":"2026-09-08-birkhoff"}
// resposta
{"ok":true,"texto":"---\ntitle: ...\n"}
{"ok":false,"erro":"post nao encontrado"}
{"ok":false,"erro":"nome de pasta invalido"}
```
Lê `posts/<pasta>/index.qmd` como UTF-8 e devolve o arquivo **cru e inteiro**,
cabeçalho YAML incluído. O editor não decompõe nem remonta front matter — o que
elimina toda uma classe de bugs de serialização.

### `POST /api/salvar`
```json
// requisição
{"pasta":"2026-09-12-meu-post","texto":"---\ntitle: \"...\"\n---\n\ncorpo"}
// resposta
{"ok":true}
{"ok":false,"erro":"nome de pasta invalido"}
```
Cria `posts/<pasta>/` se não existir e grava `index.qmd` em **UTF-8 sem BOM**
(`New-Object System.Text.UTF8Encoding $false` + `File::WriteAllText`). Sobrescreve
sem aviso e **sem detecção de conflito** (§14).

### `POST /api/renderizar`
```json
{"ok":true,"log":"...saída do quarto..."}
{"ok":false,"log":"Quarto nao encontrado nesta maquina."}
```
Executa `quarto render` na raiz. `ok` reflete `$LASTEXITCODE -eq 0`.

### `POST /api/postar`
```json
// requisição
{"mensagem":"Post novo: ..."}   // vazio ⇒ "Atualiza o blog"
// resposta
{"ok":true,"log":"== quarto render ==\n...== git add ==\n...== git push ==\n..."}
```
Sequência: `quarto render` → `git add -A` → `git commit -m <mensagem>` →
`git push`. Semântica de erro, que é irregular de propósito e por descuido:

- Se o `render` falhar, **aborta antes de qualquer comando git** e devolve
  `ok:false`. Essa parte é deliberada: não publicar site quebrado.
- Se o Quarto não for encontrado, **pula a renderização e segue para o git**,
  anotando isso no log. Seguro apenas para post sem chunk de código.
- `ok` final é decidido **somente pelo código de saída do `git push`**. Falha em
  `git add` é ignorada. `git commit` sem nada para commitar sai com código 1 e
  também é ignorado — o que é conveniente (permite enviar commits pendentes),
  mas é acidental, não projetado.

### `GET /previa` e `GET /previa/<caminho>`
Servidor de arquivos estáticos sobre `_site/` (a saída do Quarto). Diretório
resolve para `index.html`. O caminho passa por
`[System.Uri]::UnescapeDataString`. MIME por extensão, com fallback
`application/octet-stream`.

Proteção contra travessia: resolve o caminho com `Resolve-Path` e compara com
`Resolve-Path` de `_site` via `StartsWith`; fora disso responde `403`. Antes de
`_site` existir, responde `404 ainda nao renderizado`.

Serve conteúdo **binário corretamente** (PNG, WOFF), o que é o ponto — a prévia
precisa das figuras geradas pelo R.

### `GET /api/sair`
Responde `{"ok":true}` e encerra o laço. Nenhum elemento da UI chama esta rota
atualmente; existe para integração.

---

## 7. Serialização JSON, e um bug que vale conhecer

`Json-Escape` escapa, **nesta ordem**: `\` → `\\`, depois `"`, `\r`, `\n`, `\t`.
A barra invertida vir primeiro é o que torna a ordem correta.

`Campo-Json` extrai um campo string por regex
(`"<nome>"\s*:\s*"((?:[^"\\]|\\.)*)"`) e desescapa.

**A desescapagem tem de ser em passe único.** A primeira versão fazia
substituições sequenciais (`\n` → nova linha, depois `\r`, depois `\\` → `\`).
Com isso, a sequência JSON `\\norm` — que é como `\norm` chega, escapado —
tinha seu `\n` interno trocado primeiro, e a macro LaTeX `\norm{f}` virava uma
barra invertida seguida de quebra de linha e `orm{f}`. **Toda macro começando
por `n`, `r`, `t`, `b` ou `f` seria silenciosamente corrompida ao salvar.**

A versão atual usa `[regex]::Replace` com um `MatchEvaluator` sobre
`\\u([0-9a-fA-F]{4})|\\(.)`, decidindo cada escape uma única vez. Verificado com
`\norm`, `\R`, `\E`, `\int`, `\dd` e `C:\Users\jpmel`.

**Limitação remanescente:** `Json-Escape` não escapa caracteres de controle
abaixo de `0x20` que não sejam `\r`, `\n`, `\t`. Um `.qmd` contendo, por
exemplo, um form feed produziria JSON inválido e o cliente quebraria no
`r.json()`. Não observado na prática, mas é o ponto frágil se alguém colar
conteúdo de origem estranha.

---

## 8. Validação de nomes de pasta

```powershell
function Pasta-Valida($p) {
  if ([string]::IsNullOrEmpty($p)) { return $false }
  if ($p -notmatch '^[A-Za-z0-9_\-\.]+$') { return $false }
  if ($p -match '^\.+$') { return $false }
  return $true
}
```

A segunda checagem não é redundante: o conjunto de caracteres inclui o ponto,
então `..` passaria pelo regex. Sem ela, `{"pasta":".."}` em `/api/salvar`
gravaria em `posts/../index.qmd`, isto é, **sobrescreveria a capa do blog**.
Aplicada em `/api/ler` e `/api/salvar`.

Note que a validação impede travessia, mas nomes com acento, espaço ou barra
também são rejeitados. O cliente já gera nomes conformes (§12).

---

## 9. Descoberta de `git` e `quarto`

`Acha-Programa` tenta `Get-Command <nome>` e, falhando, testa uma lista de
caminhos absolutos:

- git: `%ProgramFiles%\Git\cmd\git.exe`, `%ProgramFiles(x86)%\...`,
  `%LOCALAPPDATA%\Programs\Git\cmd\git.exe`
- quarto: `%LOCALAPPDATA%\Programs\Quarto\bin\quarto.cmd`,
  `%ProgramFiles%\Quarto\bin\quarto.cmd`

O helper `Caminho` devolve `$null` quando a variável de ambiente não existe, em
vez de deixar `Join-Path` lançar exceção — necessário para o script carregar
fora do Windows, onde essas variáveis não existem (útil para teste).

**Deliberadamente não se usa `where.exe`**: ele mora em `System32`, exatamente o
que pode faltar no `PATH` da máquina-alvo, produzindo o diagnóstico errado
"git não instalado" quando o git está instalado.

Se `git` não for encontrado, `Roda` devolve `{ok=false; log="programa nao
encontrado"}` — o servidor sobe e as rotas de leitura/escrita funcionam; só a
publicação falha.

---

## 10. Execução de processos

```powershell
function Roda($exe, $argumentos) {
  if (-not $exe) { return @{ ok = $false; log = "programa nao encontrado" } }
  $saida = & $exe @argumentos 2>&1 | Out-String
  return @{ ok = ($LASTEXITCODE -eq 0); log = $saida }
}
```

O parâmetro se chama `$argumentos` e não `$args` de propósito: `$args` é
variável automática do PowerShell e usá-la como nome de parâmetro causa
comportamento imprevisível.

**A saída é capturada inteira e só devolvida no fim.** Não há streaming. Um
`quarto render` de blog grande, com chunks pesados, pode levar minutos, durante
os quais:

- a página fica com o botão desabilitado e a mensagem "publicando…";
- **o servidor não atende mais nada**, por ser sequencial;
- não há como cancelar;
- se o navegador ou algum proxy tiver timeout de resposta, o cliente desiste
  enquanto o servidor continua trabalhando — e o commit acontece sem o usuário
  ver o resultado.

Este é o ponto que mais precisa mudar numa integração séria (§16).

---

## 11. Contratos com o projeto Quarto

O editor assume, e um integrador deve preservar:

- posts vivem em `posts/<nome>/index.qmd`, um diretório por post;
- `posts/_modelo/index.qmd` é o gabarito de post novo. O prefixo `_` faz o
  Quarto ignorá-lo, então ele não vira página nem entra na listagem;
- prefixo `_` no nome da pasta = post fora do ar, preservado no repositório;
- a saída do Quarto é `_site/` (configurada em `_quarto.yml` como `output-dir`);
- `_freeze/` é versionado e é o que permite ao CI montar o site sem R nem
  Python. Qualquer alteração no arquivo `.qmd` — **inclusive só no `title:` ou
  no `author:`** — invalida o freeze daquele post, porque o hash cobre o arquivo
  inteiro e não apenas os blocos de código.

---

## 12. Cliente (`editor.html`)

Documento único: CSS no `<style>`, JS no `<script>`, sem dependências. Tema
claro/escuro por `prefers-color-scheme`.

### Estado

Uma única variável de estado real: `pastaManual` (booleano). Governa se o nome
da pasta acompanha o título ou está congelado.

- `false` → `derivaPasta()` reescreve o campo a cada tecla no textarea;
- `true` → o campo é deixado em paz; o rótulo "gerada do título" aparece
  riscado.

Transições:

| evento | `pastaManual` |
|---|---|
| carga da página | `false` |
| usuário digita no campo da pasta | `true` |
| "Novo post" | `false`, e `derivaPasta()` roda em seguida |
| abrir post existente | `true` (não renomeia post já publicado) |

### Derivação do nome

```js
slug(t) = t.toLowerCase()
           .normalize("NFD").replace(/[\u0300-\u036f]/g, "")   // tira acentos
           .replace(/[^a-z0-9]+/g, "-")
           .replace(/^-|-$/g, "")
           .slice(0, 45)
```
O nome final é `<date>-<slug>`, com `date` lido de `^date:\s*"?(\d{4}-\d{2}-\d{2})"?`
no textarea, ou a data de hoje se ausente. A normalização NFD seguida de remoção
do bloco de diacríticos combinantes é o que converte "frações contínuas" em
`fracoes-continuas`.

### Fluxo dos botões

- **Salvar** (e `Ctrl+S`): `POST /api/salvar`. Recusa se o campo da pasta estiver
  vazio, sem chamar o servidor. Em sucesso, recarrega a lista e seleciona a
  pasta corrente.
- **Renderizar**: salva; se falhou, para. Depois `POST /api/renderizar` e mostra
  o log. Em sucesso, insere um link `abrir prévia ↗` para
  `/previa/posts/<pasta>/`, removendo o link anterior.
- **Postar**: salva; se falhou, para. Depois `POST /api/postar` com a mensagem
  de commit, e mostra o log.

"Novo post" usa `prompt()` para pedir o título, lê `_modelo` via `/api/ler` e
substitui as linhas `title:` e `date:` por regex com flag `m`. Aspas duplas no
título são trocadas por simples, para não quebrar o YAML.

### Falhas de UI conhecidas

- `prompt()` é bloqueante e feio; um sistema maior deve substituí-lo.
- O `catch` de `Postar` mostra "erro de comunicação" para qualquer exceção,
  incluindo JSON malformado vindo do servidor — mensagem enganosa nesse caso.
- `Renderizar` não tem `catch`; uma falha de rede deixa a promessa rejeitada sem
  aviso ao usuário (o `finally` reabilita o botão, então não trava, mas nada é
  dito).
- Não há indicador de "há alterações não salvas", nem aviso ao sair da página.

---

## 13. Segurança

O servidor escuta **apenas em `127.0.0.1`** (`IPAddress::Loopback`), então não é
alcançável pela rede.

Dito isso, o modelo de ameaça precisa ser explícito para uma integração:

- **Não há autenticação.** Qualquer processo local, e qualquer página aberta no
  navegador do usuário, pode fazer requisições para `127.0.0.1:8787`.
- **Não há proteção contra CSRF.** As rotas aceitam qualquer método e não
  checam `Origin`. Um site malicioso aberto noutra aba pode disparar
  `POST /api/postar` via formulário. O impacto é real: executa `git push` no
  repositório do usuário.
- **`/api/postar` executa git e quarto com os privilégios do usuário.** Na
  prática, uma execução de comando arbitrário limitada, exposta em loopback sem
  autenticação.
- A validação de pasta (§8) bloqueia travessia em `/api/ler` e `/api/salvar`, e
  `/previa` valida contenção em `_site`.

Para uso pessoal, numa máquina de um usuário só, isso é aceitável. **Para
qualquer coisa multiusuário ou exposta, não é.** Mínimo a acrescentar: token de
sessão gerado no início e exigido em toda rota de API, verificação de `Origin`,
e restrição de método.

---

## 14. Limitações conhecidas

1. **Sem detecção de conflito.** `/api/salvar` sobrescreve o arquivo sem
   comparar com o que estava em disco. Duas abas abertas, ou edição simultânea
   em outro editor, perdem trabalho silenciosamente.
2. **Sem concorrência.** Servidor sequencial; uma renderização longa bloqueia
   tudo.
3. **Sem streaming de log.** Ver §10.
4. **Sem cancelamento.**
5. **Porta fixa 8787.** Se ocupada, `TcpListener.Start()` lança e o script morre
   com exceção não tratada, sem mensagem amigável.
6. **Sem upload de imagens ou anexos.**
7. **Sem prévia de matemática antes de renderizar.** Para feedback contínuo, o
   caminho é `quarto preview` em paralelo.
8. **Sem histórico, desfazer, ou rascunhos automáticos.**
9. **Sem tratamento de `git pull`.** Se o remoto divergir, `git push` falha e o
   log instrui manualmente; o editor não resolve.
10. **Sem validação do YAML** antes de gravar. Cabeçalho malformado só aparece
    como erro na renderização.
11. **Caracteres de controle no JSON** (§7).

---

## 15. Como testar sem Windows

O `editor.ps1` roda em PowerShell 7 no Linux, o que foi usado para desenvolvê-lo.
O que difere:

- `Start-Process` da URL é pulado (guardado por `$env:OS -eq "Windows_NT"`);
- as variáveis `%ProgramFiles%` etc. não existem, e `Caminho` devolve `$null`
  em vez de lançar exceção;
- `git` e `quarto` precisam estar no `PATH`.

Roteiro que exercita o sistema inteiro: clonar o projeto do blog, criar um
remoto local com `git init --bare`, apontar `origin` para ele, subir o servidor,
e dirigir a página com um navegador automatizado (Playwright). Verificar, no
mínimo: macros LaTeX sobrevivendo ao ciclo salvar/ler, o nome de pasta derivado
e seu congelamento, a prévia servindo imagens com `naturalWidth > 0`, e o commit
chegando ao remoto.

---

## 16. Pontos de extensão para um sistema maior

Em ordem de retorno sobre esforço:

1. **Trocar o transporte por algo com concorrência e streaming.** Um processo
   por requisição longa, com o log transmitido por SSE ou WebSocket, resolve as
   limitações 2, 3 e 4 de uma vez. Se o sistema maior já tiver um servidor
   (Node, Python, Go), a lógica deste `.ps1` cabe em umas 150 linhas na
   linguagem dele, e as rotas da §6 podem ser preservadas tal como estão.
2. **Trocar o JSON caseiro pelo serializador da plataforma.** Elimina §7 inteira.
3. **Acrescentar token de sessão e checagem de `Origin`.** Ver §13.
4. **Detecção de conflito**: guardar o `mtime`/hash no `/api/ler` e exigi-lo no
   `/api/salvar`, recusando gravação se mudou.
5. **Separar as três operações do `/api/postar`** em rotas próprias
   (`/api/render`, `/api/commit`, `/api/push`), deixando a orquestração no
   cliente. Torna a semântica de erro (§6) explícita em vez de irregular.
6. **Generalizar a raiz do projeto**: hoje é implícita (pasta do script). Um
   sistema maior quererá passá-la como parâmetro, e provavelmente gerenciar
   vários blogs.
7. **Abstrair `posts/<pasta>/index.qmd`**: a estrutura está embutida em quatro
   pontos do servidor e dois do cliente.

O que vale preservar: a decisão de **não decompor o front matter** — o editor
trata o `.qmd` como texto opaco, e isso elimina toda uma família de bugs de
ida-e-volta em YAML. E a de renderizar antes de commitar, que é o que protege o
CI, dado o mecanismo de `_freeze`.
