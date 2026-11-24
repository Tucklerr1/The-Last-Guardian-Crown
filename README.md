# The Last Guardian Crown

Jogo 2D de plataforma e ação em **pixel art**, feito em **Godot 4.3+** (renderizador Compatibility).
Derrote os 5 chefes, junte 1.000 moedas e pegue a coroa no trono.

## Como abrir e jogar
1. Abra a Godot 4.3 (ou mais nova) e importe a pasta (`project.godot`).
2. Na primeira abertura a Godot importa as imagens/áudios (leva alguns instantes).
3. Aperte **F5**. A cena principal é o menu.

## Controles
| Tecla | Ação |
|---|---|
| A / D | andar (segure para correr) |
| Espaço | pular (solte cedo para um pulo mais baixo) |
| Clique esquerdo | golpe de espada (clique de novo em sequência: combo de 2 golpes) |
| Tab | ataque especial (barra cheia; ela enche ao acertar inimigos) |
| E | entrar em portas / tentar pegar a coroa |
| Esc | pausar · R reviver (tela de derrota) |

## Estrutura de jogo (preservada)
Saguão com **5 portas** (um mundo cada) + sala do trono. Cada mundo termina na arena de um chefe. A coroa só se solta com
**5 chefes derrotados e 1.000 moedas**. Saída de cada mundo: porta da esquerda ("Voltar").
Mantidos: corações, vida, moedas, ataques/especial, pausa, menu, créditos, vitória e derrota.

## O que há de novo nesta versão
**Protagonista** — novo design (elmo com pluma, armadura azul-aço com ouro, capa, espada rúnica) com 11 animações:
parado, andar, correr, pulo, queda, 2 golpes, especial, dano, morte, vitória. Coyote time, buffer de pulo, poeira, tremor de câmera, pausa de impacto.

**10 minions com desenho, animação e comportamento próprios** (nada de recolorir):
| Mundo | Inimigo | Comportamento |
|---|---|---|
| Floresta | Cogumelo Saltitante | agacha e salta em arco sobre você |
| Floresta | Vespa-Esporo (voa) | paira e solta bombas de esporos |
| Montanha | Lobo da Neve | uiva (aviso) e investe em velocidade |
| Montanha | Boneco de Neve | arremessa bolas de neve em parábola mirada |
| Deserto | Escaravelho Blindado | escudo frontal: ataque por trás ou depois que ele abre |
| Deserto | Cobra das Dunas | emboscada: sai da areia, dá o bote e se enterra |
| Castelo | Esqueleto Arqueiro | mantém distância, mira (linha de aviso) e atira |
| Castelo | Fantasma Lanterna (voa) | fica etéreo (imune) e reaparece lançando alma teleguiada |
| Vulcão | Salamandra de Magma | cospe fogo em arco |
| Vulcão | Morcego Ígneo (voa) | marca o alvo e mergulha em rasante |

**5 chefes** (3 fases cada, ataques telegrafados, janelas de vulnerabilidade, entrada dramática com faixa de nome e portão que tranca a arena):
- **Rei Cogumelo** — salto esmagador com ondas no chão, chuva de esporos, rolada (tonto na parede), raízes sob você, invoca cogumelos. Os cogumelos-mola da arena levam às plataformas seguras.
- **Golem de Gelo** — leque e anéis de gelo que *congelam* (lentidão), soco glacial com espinhos em linha, estalactites marcadas; após o anel o núcleo se expõe (dano x3).
- **Escorpião Rei** — investida, golpe de cauda com veneno, pinçadas, enterra-e-emerge sob você, defesa frontal (ataque por trás).
- **Cavaleiro Fantasma** — teleporte atrás de você, ilusões (só uma é real), invocação de fantasmas, almas teleguiadas, lâminas altas e baixas.
- **Dragão de Lava** — voa disparando fogo, mergulho com erupções (cai vulnerável), sopro de fogo varrendo, cauda, chuva de meteoros.

**5 mundos com arquitetura própria**: Floresta (copas, molas de cogumelo, pontes sobre espinheiros), Montanha (gelo escorregadio, caverna de estalactites, pontes de gelo, plataformas móveis),
Deserto (dunas, plataformas que desmoronam, templo com corredor e telhado), Castelo (salões, galeria, ponte levadiça, plataformas móveis, lustres e vitrais com luz), Vulcão (lava, gêiseres, degraus de basalto, ponte de pedra).
Cada um tem **salas secretas** (a parede some ao entrar), fossos (cair = perde 1 coração e volta ao chão firme), moedas no cenário, arena exclusiva com fundo próprio, iluminação e partículas de ambiente (vaga-lumes, neve, areia ao vento, poeira fantasmagórica, brasas).

**Interface** — fonte pixel art própria (com acentos), HUD nova (corações animados, moedas, ícones dos chefes, barra do especial que pulsa, barra do chefe com rastro de dano e indicador de fase), menu com logotipo e brilhos, pausa, vitória (confete) e derrota redesenhadas, botões com efeitos.

**Áudio** — 13 músicas (menu, saguão, trono, 1 por mundo, 1 por chefe), 6 ambientes em loop e 31 novos efeitos (menus, impactos, habilidades, avisos de chefe...). Os sons originais continuam em uso.

## Pastas
```
arte/        sprites (personagens, props, tiles, objetos, efeitos, fundos, fontes, ui) e SpriteFrames (.tres)
audio/       sons originais + sfx/ musica/ ambiente/ novos
cenas/       cenas (.tscn)
scripts/     GDScript (autoload/ jogo.gd e sons.gd · ambiente/ objetos de cenário · chefes/ · ui/)
ferramentas/ geradores da arte e do áudio (Python) + verificar_projeto.py
```
Para regenerar/alterar a arte e o áudio: `cd ferramentas && python3 gerar_tudo.py` (requer numpy, pillow, scipy).

## Observações honestas
- O projeto foi construído e verificado **sem uma Godot disponível no ambiente de criação**: os scripts passaram por verificação estática
  (`ferramentas/verificar_projeto.py`: caminhos de recursos, nomes de animações, métodos referenciados, indentação, nós das cenas),
  mas **não foram executados na engine**. Ao abrir pela primeira vez, olhe o painel "Saída/Depurador": se aparecer algum erro, ele indicará arquivo e linha.
- O equilíbrio (vida e dano dos chefes, velocidade dos ataques) foi estimado no papel e provavelmente pede ajustes depois de jogar:
  os números ficam em `DADOS` (`scripts/chefe.gd`, `scripts/inimigo.gd`) e nas funções `_a1_...` a `_a5_...`.
- Pastas `.godot/` e arquivos `.import` não vão no zip: a Godot recria na primeira abertura.
