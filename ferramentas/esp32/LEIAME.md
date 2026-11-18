# Controle do Minha Luz com ESP32

O ESP32 vira um **controle Bluetooth** (gamepad). O Windows reconhece como um controle de jogo, e o Minha Luz já aceita controle:

| No controle | No jogo |
|---|---|
| Joystick (ou direcional) | Andar e escolher opções nos menus |
| X (botão Procurar) | Procurar a próxima frase boa |
| Start (botão Pausar) | Pausar |
| A (botão Confirmar) | Confirmar |
| B (botão Voltar) | Voltar (fecha os painéis do menu) |

Um controle de Xbox também funciona com os mesmos botões, e serve de reserva na apresentação.

## Peças

- 1 ESP32 com Bluetooth (DevKit v1 / WROOM-32; S3 e C3 também servem).
- 1 módulo joystick analógico (KY-023 ou parecido).
- 4 botões de apertar (push button).
- Jumpers e protoboard.

## Ligações (ESP32 DevKit v1)

| Peça | Pino da peça | ESP32 |
|---|---|---|
| Joystick | VRx | GPIO 34 |
| Joystick | VRy | GPIO 35 |
| Joystick | +5V | **3V3** (não use 5 V: o ADC do ESP32 vai só até 3,3 V) |
| Joystick | GND | GND |
| Joystick | SW (clique, opcional) | GPIO 25, junto com o botão Procurar |
| Botão Procurar | um lado / outro lado | GPIO 25 / GND |
| Botão Confirmar | um lado / outro lado | GPIO 26 / GND |
| Botão Voltar | um lado / outro lado | GPIO 27 / GND |
| Botão Pausar | um lado / outro lado | GPIO 14 / GND |

Os botões não precisam de resistor: o código liga o pull-up interno. Para usar outros pinos, troque as constantes no começo do `.ino`. O joystick tem que ficar em pinos do ADC1 (32 a 39), porque o ADC2 não funciona com o Bluetooth ligado.

## Gravar o firmware

1. Na Arduino IDE, instale a placa **esp32** (Espressif) pelo Gerenciador de Placas.
2. No Gerenciador de Bibliotecas, instale **ESP32-BLE-Gamepad** (lemmingDev). Ela instala a NimBLE-Arduino junto.
3. Abra `controle_minha_luz/controle_minha_luz.ino`, escolha a placa (por exemplo, "ESP32 Dev Module") e a porta, e clique em Carregar.
4. **Ao ligar, não mexa no joystick por 1 segundo:** é quando o ESP32 mede o centro.

## Conectar no PC

1. No Windows: Configurações > Bluetooth e dispositivos > Adicionar dispositivo > Bluetooth > **Minha Luz Controle**.
2. Para conferir: aperte Win + R, digite `joy.cpl` e abra as propriedades do "Minha Luz Controle". O joystick mexe a cruz, e os botões acendem 1 (Confirmar), 2 (Voltar), 3 (Procurar) e 7 (Pausar).
3. Abra o jogo. Se cima/baixo ou esquerda/direita estiverem trocados, mude `INVERTER_Y` ou `INVERTER_X` para `true` e grave de novo.
