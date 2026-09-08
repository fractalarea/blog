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
embutido e o botão **Render** funciona direto.

## 2. Trabalhar localmente

```bash
quarto preview     # abre o navegador e recarrega a cada gravação
quarto render      # gera o site inteiro em _site/
```

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

```
posts/AAAA-MM-DD-slug/index.qmd
```

Cabeçalho mínimo:

```yaml
---
title: "Título"
description: "Uma ou duas linhas; aparece na listagem da capa."
author: "João Paulo"
date: "2026-09-08"
categories: [teoria ergódica, R]
bibliography: ../../references.bib
---
```

Imagens e dados do post ficam na mesma pasta dele. A capa (`index.qmd`) lista
tudo de `posts/` automaticamente, em ordem de data.

## 5. Matemática

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

## 6. Estrutura

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
