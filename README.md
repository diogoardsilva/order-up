# Order Up!

Jogo cooperativo de cozinha e serviço de mesa em pixel art, para Windows, de 1 a 4 jogadores (local e online).
Feito em **Godot 4.7** (GDScript, renderizador Compatibility para correr em PCs fracos).

## Como testar

**Sem instalar nada:** em cada push, o GitHub gera o `.exe` para Windows.
Abre o separador **Actions**, escolhe a execução mais recente de "Build Windows" e descarrega `OrderUp-windows` no fundo da página.
Descompacta e abre `OrderUp.exe`.

**No Godot:** abre o Godot 4.7, carrega em *Import* e escolhe o `project.godot` desta pasta. Depois F5 para jogar.
Usem a 4.7 (não a 4.3): o projeto foi feito para a 4.7.

## Controlos

| Ação | Teclado 1 | Teclado 2 | DualShock 4 |
| --- | --- | --- | --- |
| Mover | WASD | Setas | Analógico esquerdo / D-pad |
| Entrar no lobby / pegar | Espaço | Enter | Cruz |
| Usar estação (manter, ex. cortar) | E | . | Quadrado |
| Dash / sair do lobby | Shift | - | Círculo |
| Atirar ingrediente | Q | , | Triângulo |
| Emote | R | M | L1 |
| Começar / pausa | Esc | Backspace | Options |

Os menus também se usam com o comando (D-pad ou analógico, Cruz para confirmar, Círculo para voltar). O DualShock 4 funciona por USB ou Bluetooth sem DS4Windows. Se tiverem o DS4Windows aberto, fechem-no para o comando não aparecer duas vezes.

## Como se joga

Na primeira vez que carregam em Jogar, o jogo começa por um tutorial guiado. Para o repetir, usem o botão **Tutorial** no menu (quantas vezes quiserem).

Depois do lobby escolhem o **restaurante** e os **ajudantes** (cima/baixo escolhe a linha, esquerda/direita muda, pegar começa). Cada um tem a decoração e os pratos do seu país:

| Restaurante | País | Pratos |
|---|---|---|
| O Primeiro Dia | bairro | Salada, Sopa |
| Tasca do Zé | Portugal | Bitoque, Bacalhau à Brás, Caldo Verde |
| Sakura Sushi | Japão | Sashimi, Nigiri, Maki |
| Rocket Diner | Estados Unidos | Hambúrguer, Cheeseburger, Batatas Fritas |
| Trattoria Nonna | Itália | Pizza, Esparguete, Caprese |

O restaurante tem a **cozinha** (esquerda) e o **salão** (direita). Têm 3 minutos para servir o máximo de clientes.

- Os clientes chegam em **grupos de 1 a 4** e sentam-se em mesas de 2 ou de 4. Quando aparece o balão "!", vão à mesa e carreguem em pegar para **anotar o pedido** (um prato por pessoa).
- À esquerda, **Para cozinhar** mostra um cartão por prato com quantos faltam (x3), os ingredientes desenhados e com o nome, e a receita. Por baixo, **Mesas** mostra cada mesa (a mais impaciente em cima) com o que falta e a paciência.
- Cada caixa de ingredientes tem o nome escrito, o que cada chef leva aparece escrito por cima dele e, virados para uma bancada, tábua ou fogão, vê-se o que lá está.
- Cada fase tem a sua paciência: um tempo para lhes anotarem o pedido e outro, maior, para a comida chegar. Se acabar, saem zangados (-10 pontos).
- Cortar: pousem o ingrediente na tábua e mantenham "usar".
- Fogão: juntem os ingredientes da receita (ex. bacalhau e batata cortados + ovo para o Bacalhau à Brás). Quando estão todos, coze; tirem com um prato antes de queimar. Com as mãos vazias tiram o último ingrediente (para emendar enganos) ou esvaziam o que queimou.
- Levem cada prato à mesa e carreguem em pegar virados para ela. Quando a mesa tem tudo, comem.
- Depois de comer, um do grupo vai **pagar à caixa registadora** e os outros saem. Fiquem virados para a caixa e mantenham "usar" para cobrar. Quanto mais depressa os serviram, maior a gorjeta.
- Podem levar **dois pratos com comida** de uma vez (peguem num e depois no outro) e **até quatro pratos vazios ou sujos**. Os pratos sujos ficam na mesa; no lava-loiça larguem-nos e mantenham "usar" para lavar.
- A cozinha tem duas zonas iguais, em cima e em baixo, com os ingredientes ao meio, para dois cozinheiros trabalharem ao mesmo tempo.
- As panelas e frigideiras tiram-se do fogão (mãos vazias) para servir noutro lado ou deitar fora o que queimou; só cozem em cima do fogão. Com uma panela ou um prato na mão, as caixas de ingredientes metem o ingrediente direto lá dentro.
- **Atirar**: com um ingrediente na mão, Triângulo atira-o em frente. Cai numa bancada, numa tábua, numa panela ou no lixo; outro chef de mãos vazias apanha-o no ar; se cair no chão, apanha-se com pegar.
- **Passe**: os balcões de inox com campainha entre a cozinha e o salão. Deixem lá um prato pronto: toca a campainha, aparece o número da mesa que o pediu e quem está no salão (ou um ajudante) leva-o.
- **Ajudantes** (até 2, controlados pelo jogo): no ecrã do restaurante, escolham o papel de cada um:
  - *Empregado de mesa*: anota pedidos, leva os pratos às mesas, cobra e lava a loiça.
  - *Host*: recebe os clientes (anota os pedidos) e cobra na caixa.
  - *Corredor*: leva os pratos do passe às mesas e os sujos ao lava-loiça.
  - *Cozinheiro* (zona de cima, zona de baixo ou cozinha toda): prepara os pedidos e deixa os pratos no passe.
  Dois ajudantes não vão buscar a mesma coisa; dois cozinheiros em zonas diferentes trabalham em paralelo.
- O caixote do lixo deita fora ingredientes e esvazia pratos.
- As melhores estrelas de cada restaurante ficam guardadas.

A pixel art é gerada por código: `python3 tools/make_sprites.py` desenha os sprites em `assets/sprites/`. Os sons e a música também: `python3 tools/make_sounds.py` escreve-os em `assets/audio/`. A fonte é a Jersey 15 (licença OFL, em `assets/fonts/`).

No lobby, cada jogador escolhe o seu chef com esquerda/direita (6 personagens).

## Gráficos

Em **Opções > Gráficos** escolhe-se a qualidade (**Baixo, Médio, Alto, Ultra**) ou cada opção à parte: sombras, iluminação, texturas, pós-processamento, partículas e calor dos fogões, mais VSync, limite de FPS e mostrar FPS. O restaurante por trás do menu mostra logo o resultado. Na primeira vez o jogo sugere Médio em gráficas integradas (Intel, etc.) e Alto nas outras.

O **Ultra** tem sombras que mudam com cada candeeiro, a luz a passar de fim de tarde a noite durante a ronda, chão polido com o reflexo das luzes, bloom, tapetes, pó nos raios de sol, faúlhas e o ar a tremer por cima dos fogões. Se o FPS cair, baixem primeiro as sombras ou o pós-processamento.

## Jogar online

Até 4 jogadores no total, espalhados por vários PCs (cada PC pode ter vários jogadores locais).

1. O host carrega em **Ser host (criar sala online)**. O lobby mostra o IP para partilhar. Na primeira vez, o Windows pergunta pela firewall: carrega em **Permitir**.
2. Os outros carregam em **Entrar na sala de um amigo**, escrevem esse IP e carregam em **Ligar**.
3. Cada um entra no lobby com o seu teclado ou comando. Só o host pode começar.

**Pela internet (PCs em casas diferentes):** o mais simples é instalarem o [Tailscale](https://tailscale.com/download) (grátis) em todos os PCs e entrarem na mesma conta ou rede. Depois usem o IP do host que começa por `100.` (aparece na app do Tailscale). Assim não é preciso abrir portas no router. Em alternativa, o host pode reencaminhar a porta UDP 7777 no router e partilhar o IP público.

Como funciona: o PC do host manda na cozinha, nos clientes, nas mesas e no tempo. O tutorial só aparece a jogar sozinho no mesmo PC. Cada PC mexe os seus próprios chefs (sem atraso) e pede ao host para pegar/largar/cortar. Ainda não dá para entrar a meio de uma ronda.

## Estrutura

```
scenes/            menu, lobby, escolha do restaurante, nível
scripts/autoload/  DeviceManager (comandos/teclado), PlayerRegistry (jogadores 1-4), Net (online), GameState, Gfx (definições de gráficos)
scripts/input/     InputSource e as variantes de teclado e comando
scripts/kitchen/   cozinha, estações, itens, receitas, restaurantes (levels.gd), clientes e pedidos
scripts/           lógica das cenas e do chef
```

O chef só lê de um `InputSource`, nunca diretamente do teclado ou do comando. Assim, no marco do online, os jogadores remotos entram como mais uma fonte de input.
