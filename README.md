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
| Emote | Q | , | Triângulo |
| Começar / pausa | Esc | Backspace | Options |

Os menus também se usam com o comando (D-pad ou analógico, Cruz para confirmar, Círculo para voltar). O DualShock 4 funciona por USB ou Bluetooth sem DS4Windows. Se tiverem o DS4Windows aberto, fechem-no para o comando não aparecer duas vezes.

## Como se joga

Na primeira vez que carregam em Jogar, o jogo começa por um tutorial guiado. Depois de o terminarem, não volta a aparecer.

Depois do lobby escolhem o **restaurante** (esquerda/direita, pegar para começar). Cada um tem a decoração e os pratos do seu país:

| Restaurante | País | Pratos |
|---|---|---|
| O Primeiro Dia | bairro | Salada, Sopa |
| Tasca do Zé | Portugal | Bitoque, Bacalhau à Brás, Caldo Verde |
| Sakura Sushi | Japão | Sashimi, Nigiri, Maki |
| Rocket Diner | Estados Unidos | Hambúrguer, Cheeseburger, Batatas Fritas |
| Trattoria Nonna | Itália | Pizza, Esparguete, Caprese |

O restaurante tem a **cozinha** (esquerda) e o **salão** (direita). Têm 3 minutos para servir o máximo de clientes.

- Os clientes chegam em **grupos de 1 a 4** e sentam-se em mesas de 2 ou de 4. Quando aparece o balão "!", vão à mesa e carreguem em pegar para **anotar o pedido** (um prato por pessoa). Os pratos aparecem nos talões à esquerda, com a receita explicada.
- Cada fase tem a sua paciência: um tempo para lhes anotarem o pedido e outro, maior, para a comida chegar. Se acabar, saem zangados (-10 pontos).
- Cortar: pousem o ingrediente na tábua e mantenham "usar".
- Fogão: juntem os ingredientes da receita (ex. bacalhau e batata cortados + ovo para o Bacalhau à Brás). Quando estão todos, coze; tirem com um prato antes de queimar. Com as mãos vazias tiram o último ingrediente (para emendar enganos) ou esvaziam o que queimou.
- Levem cada prato à mesa e carreguem em pegar virados para ela. Quando a mesa tem tudo, comem.
- Depois de comer, um do grupo vai **pagar à caixa registadora** e os outros saem. Fiquem virados para a caixa e mantenham "usar" para cobrar. Quanto mais depressa os serviram, maior a gorjeta.
- Os pratos sujos ficam na mesa. Podem **levar dois pratos de uma vez** (sujos ou limpos e vazios). No lava-loiça larguem-nos e mantenham "usar" para lavar.
- O caixote do lixo deita fora ingredientes e esvazia pratos.
- As melhores estrelas de cada restaurante ficam guardadas.

A pixel art é gerada por código: `python3 tools/make_sprites.py` desenha os sprites em `assets/sprites/`. Os sons e a música também: `python3 tools/make_sounds.py` escreve-os em `assets/audio/`. A fonte é a Jersey 15 (licença OFL, em `assets/fonts/`).

No lobby, cada jogador escolhe o seu chef com esquerda/direita (6 personagens).

## Jogar online

Até 4 jogadores no total, espalhados por vários PCs (cada PC pode ter vários jogadores locais).

1. Quem cria a sala carrega em **Criar sala online**. O lobby mostra o IP para partilhar. Na primeira vez, o Windows pergunta pela firewall: carrega em **Permitir**.
2. Os outros carregam em **Entrar numa sala online**, escrevem esse IP e carregam em **Ligar**.
3. Cada um entra no lobby com o seu teclado ou comando. Só o anfitrião pode começar.

**Pela internet (PCs em casas diferentes):** o mais simples é instalarem o [Tailscale](https://tailscale.com/download) (grátis) em todos os PCs e entrarem na mesma conta ou rede. Depois usem o IP do anfitrião que começa por `100.` (aparece na app do Tailscale). Assim não é preciso abrir portas no router. Em alternativa, o anfitrião pode reencaminhar a porta UDP 7777 no router e partilhar o IP público.

Como funciona: o PC do anfitrião manda na cozinha, nos clientes, nas mesas e no tempo. O tutorial só aparece a jogar sozinho no mesmo PC. Cada PC mexe os seus próprios chefs (sem atraso) e pede ao anfitrião para pegar/largar/cortar. Ainda não dá para entrar a meio de uma ronda.

## Estrutura

```
scenes/            menu, lobby, escolha do restaurante, nível
scripts/autoload/  DeviceManager (comandos/teclado), PlayerRegistry (jogadores 1-4), Net (online), GameState
scripts/input/     InputSource e as variantes de teclado e comando
scripts/kitchen/   cozinha, estações, itens, receitas, restaurantes (levels.gd), clientes e pedidos
scripts/           lógica das cenas e do chef
```

O chef só lê de um `InputSource`, nunca diretamente do teclado ou do comando. Assim, no marco do online, os jogadores remotos entram como mais uma fonte de input.
