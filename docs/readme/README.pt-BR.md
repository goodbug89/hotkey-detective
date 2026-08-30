<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>Descubra qual app ficou com o seu atalho de teclado.</strong><br>
  O macOS não oferece como perguntar. Esta ferramenta oferece.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <a href="https://goodbug89.github.io/hotkey-detective/"><strong>Site →</strong></a>
</p>

<p align="center">
  <strong>Idioma:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.it.md">Italiano</a> ·
  <strong>Português</strong> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.ar.md">العربية</a> ·
  <a href="README.th.md">ไทย</a> ·
  <a href="README.tr.md">Türkçe</a> ·
  <a href="README.vi.md">Tiếng Việt</a>
</p>

---

Você aperta ⇧⌘4 e nada acontece. Algum app pegou o atalho — mas qual? O macOS não tem API que responda isso, e os Ajustes do Sistema também não mostram.

O HotkeyDetective reúne evidências, dá um veredicto e mostra o raciocínio:

<p align="center">
  <img src="../images/verdict.png" alt="HotkeyDetective" width="420">
</p>

## Como funciona

Não existe uma fonte única sobre «quem é o dono deste atalho», então o app coleta sinais independentes e os pondera:

| Fonte | O que comprova | Força |
| --- | --- | --- |
| **Atalhos do sistema** | A própria tabela do macOS vincula esta combinação | Certa |
| **Configuração do app** | O arquivo de ajustes de um app conhecido vincula esta combinação | Alta (baixa se o app não estiver aberto) |
| **Varredura de configuração** | Os ajustes de um app batem com um formato de armazenamento conhecido | Média |
| **Reação** | Um app abriu uma janela ou veio para a frente logo após a tecla | Alta |
| **Sonda de atalho** | Algum processo mantém um registro de atalho Carbon | Apenas observação |

O veredicto é `confirmado`, `provável`, `disputado`, `ocupado mas não identificado` ou `livre`. Toda afirmação mostra as evidências em que se apoia, então você julga em vez de confiar numa caixa-preta.

Uma distinção importa: uma **reação** comprova que o app *recebeu* a tecla, não que a *registrou*. Uma reação pode corroborar um dono, mas nunca contestá-lo. Sem essa regra, ⌘Space apareceria como «o sistema e o Spotlight estão brigando» sem que haja problema algum.

## Instalação

Requer macOS 14 ou posterior.

**Homebrew** (recomendado — `brew upgrade` mantém atualizado):

```bash
brew install --cask goodbug89/tap/hotkey-detective
```

**Download direto:** baixe o `.dmg` notarizado da [versão mais recente](https://github.com/goodbug89/hotkey-detective/releases/latest), abra e arraste o app para Aplicativos.

**A partir do código-fonte:**

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

A compilação assina com um certificado Developer ID se o keychain tiver um; caso contrário, usa assinatura ad hoc. Builds ad hoc perdem as permissões a cada recompilação — veja [BUILDING.md](../../BUILDING.md).

## Permissões

A sonda precisa de **Acessibilidade** e **Monitoramento de Entrada**. O macOS exige as duas para um event tap de teclado somente-escuta.

As teclas são observadas, nunca interceptadas, registradas ou armazenadas. O tap é criado com `.listenOnly`, então o verdadeiro dono continua recebendo a tecla — é exatamente nisso que a detecção de reação se baseia. Depois de uma sonda, resta apenas a combinação que você consultou. Não há código de rede neste repositório.

Sem permissões o app funciona em **modo limitado**: escolha uma combinação manualmente e a resposta vem só dos arquivos de ajustes.

## Limites conhecidos

- **A sonda de atalhos Carbon não enxerga outros processos.** O `RegisterEventHotKey` só relata conflito dentro do próprio processo, então o veredicto «ocupado mas não identificado» é praticamente inalcançável. Um app que registra um atalho, não mostra janela e guarda a configuração em formato desconhecido permanece invisível.
- **Nomes de funções do sistema ficam em inglês fora do coreano.** O macOS guarda as próprias traduções num lugar que não conseguimos ler, e inventar as nossas divergiria do que você vê nos Ajustes do Sistema.
- **A varredura de configuração reconhece dois formatos** (a biblioteca `KeyboardShortcuts` e dicionários no estilo `MASShortcut`). Apps com formato próprio precisam de um analisador dedicado — [contribuições são bem-vindas](../../CONTRIBUTING.md).

## Quem desenvolve

O HotkeyDetective é feito pela equipe por trás do **[Unifyl](https://unifyl.app)**, um gerenciador de arquivos de painel duplo para macOS.

## Licença

MIT — [LICENSE](../../LICENSE)

