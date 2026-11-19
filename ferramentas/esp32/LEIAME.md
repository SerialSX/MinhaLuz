# Controle do Minha Luz com ESP32

O ESP32 vira um **controle Bluetooth** (gamepad). O Windows reconhece como um controle de jogo, e o Minha Luz já aceita controle:

| No controle | No jogo |
|---|---|
| Joystick (ou direcional) | Andar e escolher opções nos menus |
| B ou clique do joystick (Procurar) | Procurar a próxima frase boa |
| Start (Pausar) | Pausar |
| A (Confirmar) | Confirmar |
| Select (Voltar) | Voltar (fecha os painéis do menu) |

Um controle de Xbox também funciona com os mesmos botões, e serve de reserva na apresentação.

## Peças

- 1 ESP32 com Bluetooth (DevKit v1 / WROOM-32; S3 e C3 também servem).
- 1 módulo joystick analógico (KY-023 ou parecido).
- 4 botões de apertar (push button).
- Jumpers e protoboard.

## Ligações (ESP32 DOIT DevKit v1, 30 pinos) — controle montado do grupo

| Peça | Pino da peça | ESP32 |
|---|---|---|
| Joystick | VRx | GPIO 34 (vira o cima/baixo do jogo: o joystick está deitado) |
| Joystick | VRy | GPIO 35 (vira o esquerda/direita do jogo) |
| Joystick | +5V | **GPIO 14**, que o código deixa em HIGH (3,3 V). Não use 5 V: o ADC do ESP32 vai só até 3,3 V |
| Joystick | GND | GND (trilho − da protoboard) |
| Joystick | SW (clique) | GPIO 32 (também procura) |
| Botão A (Confirmar) | um lado / outro lado | GPIO 33 / GND |
| Botão B (Procurar) | um lado / outro lado | GPIO 25 / GND |
| Botão Start (Pausar) | um lado / outro lado | GPIO 26 / GND |
| Botão Select (Voltar) | um lado / outro lado | GPIO 27 / GND |

Na protoboard, a ESP32 fica com o lado do VIN livre: GPIO 14 = j5, 27 = j6, 26 = j7, 25 = j8, 33 = j9, 32 = j10, 35 = j11, 34 = j12, GND = j2 (ligado no trilho −).

Os botões não precisam de resistor: o código liga o pull-up interno. Para usar outros pinos, troque as constantes no começo do `.ino`. O joystick tem que ficar em pinos do ADC1 (32 a 39), porque o ADC2 não funciona com o Bluetooth ligado.

## Gravar o firmware

1. Na Arduino IDE, instale a placa **esp32** (Espressif) pelo Gerenciador de Placas.
2. No Gerenciador de Bibliotecas, instale **ESP32-BLE-Gamepad** (lemmingDev). Ela instala a NimBLE-Arduino junto.
3. Abra `controle_minha_luz/controle_minha_luz.ino`, escolha a placa (por exemplo, "ESP32 Dev Module") e a porta, e clique em Carregar.
4. **Ao ligar, não mexa no joystick por 1 segundo:** é quando o ESP32 mede o centro.

## Conectar no PC

1. No Windows: Configurações > Bluetooth e dispositivos > Adicionar dispositivo > Bluetooth > **Minha Luz Controle**.
2. Para conferir: aperte Win + R, digite `joy.cpl` e abra as propriedades do "Minha Luz Controle". O joystick mexe a cruz, e os botões acendem 1 (A), 2 (Select), 3 (B ou clique do joystick) e 7 (Start).
3. Abra o jogo. No controle do grupo, `INVERTER_X` está em `true` (o esquerda/direita saía invertido) e `INVERTER_Y` em `false`. Se num controle montado de outro jeito cima/baixo ou esquerda/direita saírem trocados, mude o `INVERTER_` daquele eixo e grave de novo.
