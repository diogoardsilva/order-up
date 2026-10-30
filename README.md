# Order Up!

Jogo cooperativo de cozinha e serviço de mesa em pixel art, para Windows, de 1 a 4 jogadores (local e online).
Feito em **Godot 4.7** (GDScript, renderizador Compatibility para correr em PCs fracos).

## Como testar

**Sem instalar nada:** em cada push, o GitHub gera o `.exe` para Windows.
Abre o separador **Actions**, escolhe a execução mais recente de "Build Windows" e descarrega `OrderUp-windows` no fundo da página.
Descompacta e abre `OrderUp.exe`.

**No Godot:** abre o Godot 4.7, carrega em *Import* e escolhe o `project.godot` desta pasta. Depois F5 para jogar.
Usem a 4.7 (não a 4.3): o projeto foi feito para a 4.7.

## Controlos (protótipo M0)

| Ação | Teclado 1 | Teclado 2 | DualShock 4 |
| --- | --- | --- | --- |
| Mover | WASD | Setas | Analógico esquerdo / D-pad |
| Entrar no lobby / pegar | Espaço | Enter | Cruz |
| Usar estação | E | . | Quadrado |
| Dash / sair do lobby | Shift | - | Círculo |
| Emote | Q | , | Triângulo |
| Começar / pausa | Esc | Backspace | Options |

O DualShock 4 funciona por USB ou Bluetooth sem DS4Windows. Se tiverem o DS4Windows aberto, fechem-no para o comando não aparecer duas vezes.

## Estrutura

```
scenes/            menu, lobby, sala de teste
scripts/autoload/  DeviceManager (comandos/teclado), PlayerRegistry (jogadores 1-4)
scripts/input/     InputSource e as variantes de teclado e comando
scripts/           lógica das cenas e do chef
```

O chef só lê de um `InputSource`, nunca diretamente do teclado ou do comando. Assim, no marco do online, os jogadores remotos entram como mais uma fonte de input.
