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

## Como se joga (protótipo M3)

Na primeira vez que carregam em Jogar, o jogo começa por um tutorial guiado. Depois de o terminarem, não volta a aparecer.

O restaurante tem a **cozinha** (esquerda) e o **salão** (direita). Têm 3 minutos para servir o máximo de clientes.

- Os clientes entram pela porta, sentam-se e mostram num balão o que querem. A barra por baixo é a paciência: se acabar, saem zangados (-10 pontos).
- **Salada**: alface cortada + tomate cortado num prato.
- **Sopa de tomate**: 2 tomates cortados no fogão, esperar que coza, e recolher com um prato. Se ficar muito tempo, queima: esvaziem a panela com as mãos vazias.
- Cortar: pousem o ingrediente na tábua e mantenham "usar".
- Levem o prato à **mesa do cliente** e carreguem em pegar virados para a mesa. Quanto mais cedo, maior a gorjeta.
- Há poucos pratos (4). Quando o cliente acaba de comer, deixa o prato sujo na mesa: levem-no ao **lava-loiça**, larguem-no e mantenham "usar" para lavar. Depois peguem no prato limpo.
- O caixote do lixo deita fora ingredientes e esvazia pratos.

A arte ainda é provisória (formas simples desenhadas por código).

## Estrutura

```
scenes/            menu, lobby, nível
scripts/autoload/  DeviceManager (comandos/teclado), PlayerRegistry (jogadores 1-4)
scripts/input/     InputSource e as variantes de teclado e comando
scripts/kitchen/   cozinha, estações, itens, receitas e pedidos
scripts/           lógica das cenas e do chef
```

O chef só lê de um `InputSource`, nunca diretamente do teclado ou do comando. Assim, no marco do online, os jogadores remotos entram como mais uma fonte de input.
