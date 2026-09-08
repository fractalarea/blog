# Blog em Quarto

Site estático gerado por [Quarto](https://quarto.org): você escreve `.qmd`
(Markdown + LaTeX + chunks de R/Python que são executados de verdade), e o
GitHub publica o HTML.

## 1. Instalar na sua máquina (uma vez)

| O quê | Onde | Necessário para |
|---|---|---|
| **Quarto CLI** | <https://quarto.org/docs/get-started/> | tudo |
| **R** + pacote `knitr` | você já tem R; `install.packages("knitr")` | chunks ```` ```{r} ```` |
| **Python** + `jupyter matplotlib numpy` | `pip install jupyter matplotlib numpy` | chunks ```` ```{python} ```` |

No VS Code, instale a extensão *Quarto*; no RStudio (≥ 2022.07) o suporte já vem
embutido e o botão **Render** funciona direto. Atenção: o RStudio traz uma cópia
própria do Quarto, que **não** serve para a linha de comando --- o `postar.bat`
precisa da instalação avulsa.

Depois de instalar, **feche e reabra** o terminal (o instalador mexe no `PATH`, e
processo já aberto mantém o antigo) e rode:

```bash
quarto check
```

Ele verifica a instalação e diz se encontrou o R, o `knitr`, o Python e o
Jupyter. É o diagnóstico oficial; use-o antes de suspeitar do resto.

## 2. Abrir localmente

**Sem instalar nada (agora):** duplo clique em `ABRIR-PREVIA.html`, na raiz da
pasta. É uma cópia do site já renderizado --- um retrato congelado, só para ver
o resultado. Ela **não** se atualiza quando você edita os `.qmd`.

Não abra `_macros.html`: no Quarto, arquivos com `_` na frente são fragmentos,
não páginas. Esse em particular só contém a caixa invisível das macros LaTeX,
então o navegador mostra uma página em branco.

**Do jeito de trabalhar de verdade** (depois de instalar o Quarto), no terminal
dentro da pasta do blog:

```bash
quarto preview     # abre o navegador e recarrega a cada gravação
quarto render      # gera o site inteiro em _site/
```

No RStudio, basta abrir a pasta e clicar em **Render**; no VS Code, o botão
aparece com a extensão *Quarto* instalada.

## 3. Publicar (uma vez)

1. Crie um repositório vazio no GitHub, por exemplo `blog`.
2. Em `_quarto.yml`, troque `site-url` por `https://SEU-USUARIO.github.io/blog`.
3. No repositório: **Settings → Pages → Source = GitHub Actions**.
4. Envie:

```bash
git remote add origin https://github.com/SEU-USUARIO/blog.git
git branch -M main
git push -u origin main
```

A partir daí, **todo `git push` para `main` republica o site**. O workflow está
em `.github/workflows/publicar.yml`.

### Por que o CI não precisa de R nem de Python

`execute: freeze: auto` guarda o resultado de cada chunk em `_freeze/`, que é
versionado. O GitHub Actions só monta o HTML a partir dali. **Consequência
prática:** renderize localmente (`quarto render`) *antes* de dar `git push`
sempre que mudar código de um post — senão o CI tenta executar o chunk e falha.

## 4. Escrever um post novo

Copie `posts/_modelo/` para `posts/AAAA-MM-DD-slug/` e edite o `index.qmd`. A
pasta `_modelo` começa com `_`, então o Quarto a ignora: ela não vira página nem
aparece na capa. Imagens e dados do post ficam na mesma pasta dele; a capa lista
tudo de `posts/` sozinha, em ordem de data.

Para escrever sem publicar, ponha `draft: true` no cabeçalho.

### Post sem código: nada para instalar

Se o post é só texto, LaTeX, teoremas e citações --- sem nenhum chunk ```` ```{r} ````
ou ```` ```{python} ```` --- o Quarto nem carrega o motor do knitr, e o GitHub monta
o site sozinho. Basta:

```bash
git add .
git commit -m "Post novo: <título>"
git push
```

Dá até para criar o arquivo pelo site do GitHub, sem tocar na sua máquina:
*Add file → Create new file*, com o caminho `posts/AAAA-MM-DD-slug/index.qmd`.
Ao commitar, o build dispara.

### Post com código: renderize antes

Chunks de R ou Python precisam ser executados, e o CI **não** tem R nem Python
--- ele lê os resultados de `_freeze/`. Então:

```bash
quarto preview                    # escreva vendo o resultado
quarto render                     # grava os resultados em _freeze/
git add .                         # inclui o _freeze atualizado
git commit -m "Post novo: <título>"
git push
```

Se esquecer o `quarto render`, o build no GitHub falha. E cuidado: **qualquer**
mudança no arquivo invalida o `_freeze`, inclusive editar só o `title:` ou o
`author:` --- o hash é sobre o arquivo inteiro, não só sobre o código.

### O atalho: postar.bat

Com o Quarto e o Git instalados, o fluxo inteiro cabe num duplo clique em
`postar.bat`, na raiz da pasta. Ele:

1. renderiza o site (executando os chunks e atualizando o `_freeze`);
2. mostra o que mudou;
3. pede a mensagem do commit e registra;
4. envia para o GitHub e imprime o endereço do site e o do build.

Se a renderização falhar, ele **para antes de commitar** --- nada quebrado vai
para o ar. Se não houver arquivo novo, ele ainda assim tenta o `git push`, porque
pode haver commit antigo esperando.

Também aceita a mensagem como argumento, se você chamar pelo terminal:

```
postar.bat "Post novo: teorema de Poincaré"
```

Rotina completa de um post com código, então: copie `posts/_modelo/` para
`posts/AAAA-MM-DD-slug/`, escreva o `index.qmd`, confira com `quarto preview`, e
dê um duplo clique em `postar.bat`.

## 5. Tema claro e escuro

`_quarto.yml` declara dois temas (`cosmo` e `darkly`); o botão de alternância
aparece sozinho na barra superior. Para trocar a dupla, escolha entre os temas
do Bootswatch: <https://quarto.org/docs/output-formats/html-themes.html>.

Figuras geradas por R e Python saem com fundo branco, então `styles.css` põe uma
moldura clara em volta delas no modo escuro. Se preferir gráficos que acompanhem
o tema, é preciso gerar duas versões da figura --- diga que eu configuro.

## 6. Matemática

**Macros globais** ficam em `_macros.html` e valem em todas as páginas. Já estão
definidas `\R \N \Z \Q \C \E \P \ind \norm \abs \set \inner \dd \Var \Cov \dist
\supp \Leb \eps \restr`. Acrescente as suas na mesma caixa.

**Equação numerada e referenciável:**

```markdown
$$
A_n f(x) = \frac{1}{n} \sum_{k=0}^{n-1} f(T^k x)
$$ {#eq-media}

... como em @eq-media ...
```

**Ambientes de teorema** (rótulos já traduzidos em `_quarto.yml`):

```markdown
::: {#thm-birkhoff}
## Convergência pontual das médias
Enunciado.
:::

::: {.proof}
Demonstração.
:::
```

Prefixos disponíveis: `thm` (Teorema), `lem`, `cor`, `prp`, `cnj`, `def`, `exm`,
`exr`; e as classes `.proof`, `.remark`, `.solution`. Referencie com
`@thm-birkhoff`.

**Citações:** entradas em `references.bib`, uso `@walters1982` ou `[@cover2006]`.

## 7. Estrutura

```
_quarto.yml     configuração do site (título, menu, idioma, rótulos)
_macros.html    macros LaTeX globais
styles.css      ajustes visuais sobre o tema cosmo
index.qmd       capa: listagem dos posts
sobre.qmd       página sobre
references.bib  bibliografia
posts/          um diretório por post
_freeze/        resultados dos chunks (VERSIONAR — o CI depende disto)
_site/          saída gerada (não versionar)
```

## Extras que ficaram de fora

- **Comentários** nos posts: `giscus` (usa GitHub Discussions) — configura em
  `_quarto.yml`, sob `website: comments:`.
- **Domínio próprio**: registre o domínio, crie o arquivo `CNAME` na raiz e
  aponte em Settings → Pages.
- **Newsletter**: o feed RSS já é gerado em `index.xml`; serviços como
  Mailchimp ou Buttondown enviam a partir dele.
